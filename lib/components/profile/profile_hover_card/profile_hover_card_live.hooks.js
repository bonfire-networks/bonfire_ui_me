// Profile hover card: opens the page's one card next to a hovered author link and asks the server to fill it. Behaviour and states: plans/profile-hover-card.md, sections 1 and 3 (team-docs).
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
					effects: [["show", state.key], ["push_load", state.id]]
				};
			}
			return state.mode === "closing" ? close : stay;

		case "escape":
			if (state.mode === "waiting") return { state: idle, effects: [["clear_timer"]] };
			return shown ? close : stay;

		case "reply":
			// a reply for a link the pointer has moved away from says nothing about this card
			if (event.id !== state.id || !shown) return stay;
			return event.found ? { state, effects: [["unmark_loading"]] } : close;

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

		// returns whether the event changed anything, so Escape only stops propagation when it closed the card
		this.dispatch = (event) => {
			const { state, effects } = next(this.state, event);
			this.state = state;
			effects.forEach((effect) => this.run(effect));
			return effects.length > 0;
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
			if (e.key === "Escape" && this.dispatch({ type: "escape" })) e.stopPropagation();
		};

		document.addEventListener("pointerover", this.onPointerOver);
		document.addEventListener("pointerout", this.onPointerOut);
		window.addEventListener("keydown", this.onKeyDown, true);
	},

	destroyed() {
		clearTimeout(this.timer);
		this.stopAutoUpdate?.();
		document.removeEventListener("pointerover", this.onPointerOver);
		document.removeEventListener("pointerout", this.onPointerOut);
		window.removeEventListener("keydown", this.onKeyDown, true);
	},

	run([effect, arg]) {
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

			case "unmark_loading":
				delete this.panel.dataset.loading;
				break;

			case "push_load":
				this.pushEventTo(this.el, "load", { id: arg }, ({ id, found }) =>
					this.dispatch({ type: "reply", id, found })
				);
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
