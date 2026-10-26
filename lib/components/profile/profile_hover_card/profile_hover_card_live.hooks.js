// Profile hover card: next to a hovered author link (mouse), or a bottom sheet on tap (touch, pen); the server fills either. See plans/profile-hover-card.md in team-docs.
import { autoUpdate, computePosition, flip, offset, shift } from "@floating-ui/dom";

const OPEN_DELAY = 400;
const CLOSE_GRACE = 300;

// The decisions are pure (and `function` declarations, so the vm-based tests can reach them); the hook below only runs the effects they return.
function next(state, event) {
	const stay = { state, effects: [] };
	const shown = state.mode === "open" || state.mode === "closing";

	// `key` is the hovered link itself, so two links to the same person are two links (each opens next to itself); `id` is the user, for the request and its reply
	const idle = { mode: "idle", id: null, key: null };
	const close = { state: idle, effects: [["hide"]] };
	const toClosing = { state: { ...state, mode: "closing" }, effects: [["start_timer", CLOSE_GRACE]] };
	const reopen = { state: { ...state, mode: "open" }, effects: [["clear_timer"]] };
	const wait = ({ id, key }) => ({
		state: { mode: "waiting", id, key },
		effects: [...(shown ? [["hide"]] : []), ["start_timer", OPEN_DELAY]]
	});

	switch (event.type) {
		case "over_link":
			if (event.key !== state.key || state.mode === "idle") return wait(event);
			return state.mode === "closing" ? reopen : stay;

		case "over_card":
			return state.mode === "closing" ? reopen : stay;

		case "leave_link":
		case "leave_card":
			if (state.mode === "open") return toClosing;
			if (state.mode === "waiting" && event.type === "leave_link") {
				return { state: idle, effects: [["clear_timer"]] };
			}
			return stay;

		case "timer":
			if (state.mode === "waiting") {
				return {
					state: { ...state, mode: "open" },
					effects: [["show", state.key], ["push_load", state.key, state.id, false]]
				};
			}
			return state.mode === "closing" ? close : stay;

		case "escape":
			if (state.mode === "waiting") return { state: idle, effects: [["clear_timer"]] };
			return shown ? close : stay;

		case "reply":
			// a reply for a link left behind (or a closed sheet) is stale
			if (event.id !== state.id) return stay;
			if (state.mode === "sheet") {
				return {
					state: idle,
					effects: event.found ? [["loaded", "sheet"]] : [["close_sheet"], ["navigate", state.key]]
				};
			}
			if (!shown) return stay;
			return event.found ? { state, effects: [["loaded", "panel"]] } : close;

		// open the sheet at once with the skeleton and ask for its content; no second-tap case, since showModal() makes the page inert
		case "tap": {
			// disconnected: the click goes through and the link navigates
			if (!event.connected) return stay;
			const desktop = shown ? [["hide"]] : state.mode === "waiting" ? [["clear_timer"]] : [];
			return {
				state: { mode: "sheet", id: event.id, key: event.key },
				effects: [...desktop, ["open_sheet"], ["push_load", event.key, event.id, true]]
			};
		}

		case "sheet_closed":
			return state.mode === "sheet" ? { state: idle, effects: [] } : stay;

		default:
			return stay;
	}
}

export default {
	mounted() {
		this.state = { mode: "idle", id: null, key: null };
		this.link = null;
		this.timer = null;
		this.stopAutoUpdate = null;
		this.panel = this.el.querySelector("[data-role=profile_hover_card_panel]");
		this.sheet = this.el.querySelector("[data-role=profile_hover_card_sheet]");

		// returns the effects, so callers know whether to stop the event
		this.dispatch = (event) => {
			const { state, effects } = next(this.state, event);
			this.state = state;
			effects.forEach((effect) => this.run(effect));
			return effects;
		};

		this.onPointerOver = (e) => {
			if (e.pointerType !== "mouse") return;
			if (this.panel.contains(e.target)) return this.dispatch({ type: "over_card" });

			const link = e.target.closest?.("[data-hovercard-id]");
			if (link) this.dispatch({ type: "over_link", key: link, id: link.dataset.hovercardId });
		};

		this.onPointerOut = (e) => {
			if (e.pointerType !== "mouse") return;
			const to = e.relatedTarget;

			if (this.panel.contains(e.target) && !this.panel.contains(to)) {
				return this.dispatch({ type: "leave_card" });
			}

			const link = e.target.closest?.("[data-hovercard-id]");
			// moving between a link's own children isn't leaving it
			if (link && !link.contains(to)) this.dispatch({ type: "leave_link" });
		};

		// capture phase on window, so this runs before keyboard_shortcuts.js's global Escape blurs the focused element
		this.onKeyDown = (e) => {
			if (e.key === "Escape" && this.dispatch({ type: "escape" }).length) e.stopPropagation();
		};

		// the card's push_event (see ProfileHoverCardLive.update/2)
		this.handleEvent("profile_hover_card:loaded", ({ id, found }) =>
			this.dispatch({ type: "reply", id, found })
		);

		// a click doesn't say what caused it, so remember the pointerdown; pointercancel (a scroll) forgets it, so a later Enter isn't a tap
		this.onPointerDown = (e) => {
			this.pointerType = e.pointerType;
		};
		this.onPointerCancel = () => {
			this.pointerType = null;
		};

		// capture on document: LiveView's link handler (bubble, on window) ignores defaultPrevented, so a tap also stops propagation
		this.onClick = (e) => {
			// not a mouse (touch, pen) is a tap; no pointerType (keyboard, synthetic click) navigates
			const tap = this.pointerType && this.pointerType !== "mouse";
			this.pointerType = null;
			if (!tap) return;

			const link = e.target.closest?.("[data-hovercard-id]");
			if (!link) return;

			const effects = this.dispatch({
				type: "tap",
				key: link,
				id: link.dataset.hovercardId,
				connected: this.liveSocket.isConnected()
			});

			if (effects.some(([effect]) => effect === "push_load")) {
				e.preventDefault();
				e.stopPropagation();
			}
		};

		// Escape, the close button and the backdrop all close the dialog natively
		this.onSheetClose = () => this.dispatch({ type: "sheet_closed" });
		this.sheet.addEventListener("close", this.onSheetClose);

		document.addEventListener("pointerover", this.onPointerOver);
		document.addEventListener("pointerdown", this.onPointerDown, true);
		document.addEventListener("pointercancel", this.onPointerCancel, true);
		document.addEventListener("click", this.onClick, true);
		document.addEventListener("pointerout", this.onPointerOut);
		window.addEventListener("keydown", this.onKeyDown, true);
	},

	destroyed() {
		clearTimeout(this.timer);
		this.stopAutoUpdate?.();
		document.removeEventListener("pointerover", this.onPointerOver);
		document.removeEventListener("pointerout", this.onPointerOut);
		this.sheet.removeEventListener("close", this.onSheetClose);
		document.removeEventListener("pointerdown", this.onPointerDown, true);
		document.removeEventListener("pointercancel", this.onPointerCancel, true);
		document.removeEventListener("click", this.onClick, true);
		window.removeEventListener("keydown", this.onKeyDown, true);
	},

	run([effect, arg, arg2, arg3]) {
		switch (effect) {
			case "start_timer":
				clearTimeout(this.timer);
				this.timer = setTimeout(() => this.dispatch({ type: "timer" }), arg);
				break;

			case "clear_timer":
				clearTimeout(this.timer);
				break;

			case "show":
				this.link = arg;
				// a skeleton until the reply, so the previous person's card never shows under this link; hidden until positioned, so it never paints where the last card was
				this.panel.dataset.loading = "true";
				this.panel.style.visibility = "hidden";
				this.panel.style.display = "block";
				this.stopAutoUpdate?.();
				this.stopAutoUpdate = autoUpdate(this.link, this.panel, () => this.position());
				break;

			case "hide":
				this.stopAutoUpdate?.();
				this.stopAutoUpdate = null;
				this.panel.style.display = "none";
				break;

			// the reply came: the skeleton goes
			case "loaded":
				delete this[arg].dataset.loading;
				// focus once filled, when the label names this person
				if (arg === "sheet") this.sheet.focus();
				break;

			case "open_sheet":
				this.sheet.dataset.loading = "true";
				if (!this.sheet.open) this.sheet.showModal();
				break;

			case "close_sheet":
				this.sheet.close();
				break;

			// a synthetic click has no pointerdown before it, so onClick lets it through to LiveView
			case "navigate":
				arg.click();
				break;

			// to the link, so the post it sits in can hand over its loaded user
			case "push_load":
				this.pushEventTo(arg, "Bonfire.UI.Me.ProfileHoverCardLive:load", { id: arg2, sheet: arg3 });
				break;
		}
	},

	position() {
		if (!this.link || !this.panel) return;

		// the same middleware as tooltip.js; fixed, since the panel sits at the top of the layout
		computePosition(this.link, this.panel, {
			strategy: "fixed",
			placement: "bottom-start",
			middleware: [offset(6), flip(), shift({ padding: 5 })]
		}).then(({ x, y }) => {
			Object.assign(this.panel.style, { left: `${x}px`, top: `${y}px`, visibility: "visible" });
		});
	}
};
