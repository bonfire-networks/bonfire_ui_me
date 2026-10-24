// The profile hover card hook's decisions, as pure functions: the desktop state table (plans/profile-hover-card.md, section 3, team-docs). Run with: node --test extensions/bonfire_ui_me/test/js/
import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";
import vm from "node:vm";

const hookUrl = new URL(
	"../../lib/components/profile/profile_hover_card/profile_hover_card_live.hooks.js",
	import.meta.url
);

// as the other hook tests do: run the source in a vm, without its npm imports (floating-ui is only used for positioning, which these tests don't cover)
function loadHook() {
	const source = fs
		.readFileSync(hookUrl, "utf8")
		.replace(/^import .*$/gm, "")
		.replace(/export default \{/, "globalThis.__hook = {");

	const context = {};
	context.globalThis = context;
	vm.runInNewContext(source, context, { filename: hookUrl.pathname });
	return context;
}

const hook = loadHook();

// objects made inside the vm have that realm's prototypes, which deepStrictEqual tells apart from ours, so compare them as plain data
const plain = (value) => JSON.parse(JSON.stringify(value));
const next = (state, event) => plain(hook.next(state, event));

// a link is keyed by its element (here a string), so two links to the same person are two links; the id is the user, used for the request and its reply
const idle = { mode: "idle", id: null, key: null };
const at = (mode, id, key = `${id}1`) => ({ mode, id, key });
const over = (id, key = `${id}1`) => ({ type: "over_link", id, key });

// desktop

test("1. resting on a link starts the 400ms wait", () => {
	assert.deepEqual(next(idle, over("A")), {
		state: at("waiting", "A"),
		effects: [["start_timer", 400]]
	});
});

test("2. leaving before the wait ends cancels it, with no request", () => {
	assert.deepEqual(next(at("waiting", "A"), { type: "leave_link" }), {
		state: idle,
		effects: [["clear_timer"]]
	});
});

test("3. the wait ending opens the card and asks the server for it", () => {
	assert.deepEqual(next(at("waiting", "A"), { type: "timer" }), {
		state: at("open", "A"),
		effects: [["show", "A1"], ["push_load", "A"]]
	});
});

test("4. leaving the link or the card starts the 300ms grace", () => {
	for (const type of ["leave_link", "leave_card"]) {
		assert.deepEqual(next(at("open", "A"), { type }), {
			state: at("closing", "A"),
			effects: [["start_timer", 300]]
		});
	}
});

test("5. coming back during the grace keeps the card, without loading it again", () => {
	for (const event of [{ type: "over_card" }, over("A")]) {
		assert.deepEqual(next(at("closing", "A"), event), {
			state: at("open", "A"),
			effects: [["clear_timer"]]
		});
	}
});

test("6. the grace ending closes the card", () => {
	assert.deepEqual(next(at("closing", "A"), { type: "timer" }), {
		state: idle,
		effects: [["hide"]]
	});
});

test("7. Escape closes the card", () => {
	assert.deepEqual(next(at("open", "A"), { type: "escape" }), {
		state: idle,
		effects: [["hide"]]
	});
});

test("8. a not-found reply closes the card", () => {
	assert.deepEqual(next(at("open", "A"), { type: "reply", id: "A", found: false }), {
		state: idle,
		effects: [["hide"]]
	});
});

test("9. resting on another link closes this card and starts that link's wait", () => {
	assert.deepEqual(next(at("open", "A"), over("B")), {
		state: at("waiting", "B"),
		effects: [["hide"], ["start_timer", 400]]
	});
});

test("10. a reply for another link is ignored", () => {
	assert.deepEqual(next(at("open", "A"), { type: "reply", id: "B", found: false }), {
		state: at("open", "A"),
		effects: []
	});
});

test("11. a found reply drops the skeleton; LiveView fills the card", () => {
	assert.deepEqual(next(at("open", "A"), { type: "reply", id: "A", found: true }), {
		state: at("open", "A"),
		effects: [["unmark_loading"]]
	});
});

test("12. another link to the same person starts its own wait, so the card opens next to that link", () => {
	assert.deepEqual(next(at("open", "A"), over("A", "A2")), {
		state: at("waiting", "A", "A2"),
		effects: [["hide"], ["start_timer", 400]]
	});
});

test("13. Escape during the wait cancels it, so the card doesn't open after", () => {
	assert.deepEqual(next(at("waiting", "A"), { type: "escape" }), {
		state: idle,
		effects: [["clear_timer"]]
	});
});
