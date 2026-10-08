"use strict";
// Story Studio front end: lines, the voice lab, and the bake queue.
const $ = (sel) => document.querySelector(sel);
const el = (tag, props = {}, ...kids) => {
	const node = Object.assign(document.createElement(tag), props);
	for (const kid of kids) node.append(kid);
	return node;
};
const CHAPTER_NAMES = { ophelia: "Ophelia's afternoon", mathilda: "Mathilda's camp", lake: "On the ice", doorway: "At the door" };
const MOOD_HUE = { steady: 200, warm: 30, hushed: 260, shaken: 50, breaking: 0, resolve: 140, calling: 190,
	numb: 220, bitter: 15, pleading: 300, wry: 90, remembering: 330, panicked: 60, spent: 170 };
const MOOD_DIRECTIONS = {
	steady: "Speak plainly and evenly, with quiet attention and natural breath.",
	warm: "Let a little warmth and tenderness through, as if comforting someone you trust.",
	hushed: "Speak close and barely above a whisper, careful not to be overheard.",
	shaken: "Try to stay composed, but let a small tremor and uneven breath betray the shock.",
	breaking: "Let the words catch and fracture; grief is overtaking the effort to stay composed.",
	resolve: "Speak with low, deliberate conviction; fear remains, but the decision is made.",
	calling: "Call urgently into the distance, carrying over wind without becoming theatrical.",
	numb: "Keep the voice distant and drained, as if feeling has gone quiet for the moment.",
	bitter: "Give the words a restrained edge of hurt and resentment, held under control.",
	pleading: "Ask with vulnerable urgency; let the voice soften on the words that matter most.",
	wry: "Allow one dry, fleeting trace of humor, then return to guarded seriousness.",
	remembering: "Speak gently and inwardly, as if handling a memory that could easily break.",
	panicked: "Let breath shorten and pace quicken with fear, keeping every word intelligible.",
	spent: "Speak with the last of your strength, slow and breath-thin, without melodrama.",
};

const state = { lines: [], summary: {}, actions: [], filter: { chapter: "", group: "", status: "", speaker: "", owed: "", q: "" },
	selected: null, takes: {}, playing: null, voicesLoaded: false, conversationTurns: [], conversationResults: [] };
const player = $("#player");

async function api(path, body) {
	const response = await fetch(path, body ? { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) } : {});
	return response.json();
}

async function load() {
	const data = await api("/api/state");
	Object.assign(state, { lines: data.lines, summary: data.summary, actions: data.actions, orphans: data.orphans });
	state.review = await api("/api/review");
	state.models = await api("/api/models");
	const moods = $("#lab-mood");
	if (!moods.children.length) for (const mood of data.moods) moods.append(el("option", { value: mood, textContent: mood }));
	refreshUndo();
	renderSummary();
	renderNav();
	renderRows();
	renderActions();
	renderModels();
}

function renderSummary() {
	const box = $("#summary");
	box.replaceChildren();
	for (const [chapter, row] of Object.entries(state.summary)) {
		const bar = el("div", { className: "bar" });
		for (const kind of ["final", "draft", "missing"]) {
			bar.append(el("span", { style: `width:${(100 * row[kind]) / row.lines}%;background:var(--${kind})`, title: `${row[kind]} ${kind}` }));
		}
		box.append(el("div", { className: "chip" }, el("b", { textContent: CHAPTER_NAMES[chapter] || chapter }), bar,
			el("small", { textContent: `${row.final}/${row.lines} final · ${row.draft} draft · ${row.missing} missing` })));
	}
}

function navLink(label, count, warn, active, onclick) {
	const link = el("a", { className: active ? "on" : "", onclick }, el("span", { textContent: label }),
		el("span", { className: warn ? "n warn" : "n", textContent: count }));
	if (active) link.setAttribute("aria-current", "page");
	return link;
}

function renderNav() {
	const nav = $("#nav");
	nav.replaceChildren();
	const f = state.filter;
	const lines = state.lines;
	const linesView = !$("#lines-view").hidden;
	nav.append(el("h4", { textContent: "Views" }));
	nav.append(navLink("All lines", lines.length, false, linesView && !f.chapter && !f.owed, () => show({ chapter: "", group: "", owed: "" })));
	const owed = {};
	for (const line of lines) if (line.owed_to) owed[line.owed_to] = (owed[line.owed_to] || 0) + 1;
	for (const [engine, n] of Object.entries(owed)) {
		nav.append(navLink(`Owed to ${engine}`, n, true, linesView && f.owed === engine, () => show({ chapter: "", group: "", owed: engine })));
	}
	const open = (state.review || []).filter((i) => !i.decision).length;
	nav.append(navLink("Review new clips", open || "", open > 0, !$("#review-view").hidden, () => showView("review")));
	nav.append(navLink("Bake & check", "", false, !$("#bake-view").hidden, () => showView("bake")));
	nav.append(navLink("Voice models", (state.models?.models || []).length, false, !$("#models-view").hidden, () => showView("models")));
	for (const chapter of Object.keys(CHAPTER_NAMES)) {
		const inChapter = lines.filter((l) => l.chapter === chapter);
		if (!inChapter.length) continue;
		nav.append(el("h4", { textContent: CHAPTER_NAMES[chapter] }));
		const groups = {};
		for (const line of inChapter) {
			const g = (groups[line.group] ||= { n: 0, open: 0 });
			g.n++;
			if (line.clip !== "final") g.open++;
		}
		for (const [group, g] of Object.entries(groups)) {
			const label = group === chapter ? "all" : group.replace("/", " · ");
			nav.append(navLink(label, g.open ? `${g.open}/${g.n}` : g.n, g.open > 0,
				linesView && f.chapter === chapter && f.group === group, () => show({ chapter, group, owed: "" })));
		}
	}
}

function show(patch) {
	Object.assign(state.filter, patch);
	showView("lines");
	renderRows();
}

function visible() {
	const f = state.filter;
	const q = f.q.toLowerCase();
	return state.lines.filter((l) =>
		(!f.chapter || l.chapter === f.chapter) && (!f.group || l.group === f.group) &&
		(!f.status || l.clip === f.status) && (!f.speaker || l.speaker === f.speaker) &&
		(!f.owed || l.owed_to === f.owed) &&
		(!q || `${l.uid} ${l.text} ${l.mood}`.toLowerCase().includes(q)));
}

function moodChip(mood) {
	return el("span", { className: "mood", textContent: mood, style: `border-color:hsl(${MOOD_HUE[mood] ?? 0} 45% 45%);color:hsl(${MOOD_HUE[mood] ?? 0} 60% 75%)` });
}

// One player for everything. Every button for the clip that's loaded shows
// play or pause; the small player in the top bar shows it and Space toggles it.
function playButton(path, label = "") {
	const button = el("button", { className: "play", textContent: "▶", title: "Play / pause" });
	button.dataset.path = path;
	button.onclick = (event) => { event.stopPropagation(); toggle(path, label); };
	paintButton(button);
	return button;
}

function toggle(path, label = "") {
	if (state.playing && state.playing.path === path) {
		if (player.paused) player.play();
		else player.pause();
		return;
	}
	player.src = `/audio?path=${encodeURIComponent(path)}`;
	state.playing = { path, label: label || path.split("/").pop() };
	player.play();
	$("#mini").hidden = false;
	$("#mini-label").textContent = state.playing.label;
	$("#mini-label").title = state.playing.label;
}

function labelOf(line) {
	return `${line.uid.split("/").slice(1).join("/")} · ${line.text}`;
}

function paintButton(button) {
	const on = state.playing && button.dataset.path === state.playing.path && !player.paused;
	button.textContent = on ? "❚❚" : "▶";
	button.classList.toggle("on", Boolean(on));
}

function paintPlayback() {
	for (const button of document.querySelectorAll("button.play[data-path]")) paintButton(button);
	$("#mini-toggle").textContent = player.paused ? "▶" : "❚❚";
	$("#mini-toggle").classList.toggle("on", !player.paused);
}
for (const kind of ["play", "pause", "ended"]) player.addEventListener(kind, paintPlayback);
$("#mini-toggle").onclick = () => { if (state.playing) toggle(state.playing.path); };

function renderRows() {
	const rows = $("#rows");
	rows.replaceChildren();
	const list = visible();
	$("#count").textContent = `${list.length} line${list.length === 1 ? "" : "s"}`;
	for (const line of list) {
		const tr = el("tr", { className: state.selected?.uid === line.uid ? "sel" : "" });
		tr.onclick = () => select(line);
		const who = el("div", { className: `who ${line.speaker}`, textContent: line.speaker });
		const status = el("td", {}, el("span", { className: `dot ${line.clip}`, title: line.clip + (line.owed_to ? ` · owed to ${line.owed_to}` : "") }));
		const last = el("td");
		if (line.clip_path) last.append(playButton(line.clip_path, labelOf(line)));
		else last.append(el("span", { className: "owed", textContent: line.owed_to ? `owed: ${line.owed_to}` : "" }));
		tr.append(status, el("td", {}, el("div", { className: "uid", textContent: line.uid.split("/").slice(1).join("/") }), who),
			el("td", {}, moodChip(line.mood)), el("td", { className: "text", textContent: line.text }),
			el("td", { className: "src", textContent: line.source.replace("docs/", "") }), last);
		rows.append(tr);
	}
}

// ---------------------------------------------------------------- voice lab

async function select(line) {
	state.selected = line;
	$("#lab").hidden = false;
	$("#lab-uid").textContent = line.uid;
	$("#lab-meta").textContent = `${line.speaker} · ${line.mood} · ${line.clip}${line.owed_to ? ` · owed to ${line.owed_to}` : ""}`;
	$("#lab-text").value = line.text;
	$("#lab-mood").value = line.mood;
	state.autoDirective = MOOD_DIRECTIONS[line.mood] || MOOD_DIRECTIONS.steady;
	$("#qwen-instruction").value = state.autoDirective;
	fillDialogue(line);
	$("#lab-edit").hidden = true;
	const [bakeable, why] = bakePlan(line);
	$("#lab-bake").disabled = !bakeable;
	$("#lab-why").textContent = why;
	const current = $("#lab-current");
	current.replaceChildren();
	if (line.clip_path) current.append(playButton(line.clip_path, labelOf(line)), el("span", { textContent: ` In the game now (${line.clip})` }));
	else current.append(el("span", { className: "muted", textContent: "No clip yet: the game shows this line as a subtitle." }));
	if (line.meta && line.meta.reaction) current.append(el("div", { className: "muted", textContent: `Action / reaction: ${line.meta.reaction}` }));
	if (!state.voicesLoaded) await loadVoices();
	if (state.models) configureModelControls();
	$("#lab-voice").value = line.speaker === "mathilda" ? "af_bella" : "af_sarah";
	const speed = line.speaker === "mathilda" ? 0.94 : 0.92;
	$("#lab-speed").value = speed;
	$("#lab-speed-out").textContent = speed.toFixed(2);
	renderTakes();
	renderRows();
}

function fillDialogue(line) {
	const box = $("#lab-dialogue");
	box.hidden = line.chapter !== "doorway";
	if (box.hidden) return;
	const meta = line.meta || {};
	$("#dialogue-speaker").value = line.speaker;
	$("#dialogue-reaction").value = meta.reaction || "";
	$("#dialogue-quote").value = meta.quote || "";
	$("#dialogue-intensity").value = meta.intensity ?? 0;
	$("#dialogue-pause").value = meta.pause ?? 0;
	$("#dialogue-overlap").value = meta.overlap ?? 0;
	$("#dialogue-break").checked = Boolean(meta.break);
	const answers = $("#dialogue-answers");
	answers.replaceChildren(el("option", { value: "none", textContent: "No answer" }), el("option", { value: "any", textContent: "Anything" }));
	for (const other of state.lines.filter((item) => item.chapter === "doorway" && item.uid !== line.uid)) {
		answers.append(el("option", { value: other.uid.split("/").at(-1), textContent: `${other.uid.split("/").at(-1)} · ${other.text.slice(0, 42)}` }));
	}
	answers.value = meta.answers || "none";
}

async function loadVoices() {
	const select = $("#lab-voice");
	$("#lab-status").textContent = "Waking Kokoro…";
	const data = await api("/api/voices");
	select.replaceChildren();
	for (const voice of data.voices || ["af_bella", "af_sarah"]) select.append(el("option", { value: voice, textContent: voice }));
	state.voicesLoaded = Boolean(data.voices);
	$("#lab-status").textContent = data.error ? data.error : "";
}

function renderTakes() {
	const list = $("#lab-takes");
	list.replaceChildren();
	for (const take of state.takes[state.selected.uid] || []) {
		const variation = take.seed == null ? "" : ` · seed ${take.seed} · temp ${take.temperature.toFixed(2)}`;
		const row = el("li", {}, playButton(take.path, `take · ${take.text}`), el("span", { textContent: `${take.voice}${take.speed == null ? "" : ` · ${take.speed.toFixed(2)}`}${variation} — “${take.text.slice(0, 60)}”` }));
		if (take.model_id && !take.converted) {
			const convert = el("button", { className: "ghost", textContent: "Match Ophelia", disabled: !state.models?.can_unify,
				title: state.models?.can_unify ? "Convert this take to Ophelia's approved steady voice" : "Needs the Chatterbox CUDA runtime, NVIDIA GPU, and steady reference" });
			convert.onclick = async () => {
				convert.disabled = true;
				$("#lab-status").textContent = "Converting to Ophelia's voice with Chatterbox…";
				const result = await api("/api/model_unify", { path: take.path });
				if (!result.ok) {
					$("#lab-status").textContent = result.error || "Identity conversion failed";
					convert.disabled = !state.models?.can_unify;
					return;
				}
				(state.takes[state.selected.uid] ||= []).unshift({ path: result.path, voice: "Ophelia identity · Chatterbox VC", text: take.text, converted: true });
				$("#lab-status").textContent = result.cached ? "Played from the scratch cache." : "Converted take is in scratch; it has not changed any game clips.";
				renderTakes();
				toggle(result.path, `Ophelia voice · ${take.text}`);
			};
			row.append(convert);
		}
		list.append(row);
	}
	if (!list.children.length) list.append(el("li", { className: "muted", textContent: "None yet. Kokoro renders on this machine in a few seconds; the first one also wakes the model." }));
}

async function tryReading() {
	const line = state.selected;
	if (!line) return;
	const text = $("#lab-text").value.trim();
	const voice = $("#lab-voice").value;
	const speed = parseFloat($("#lab-speed").value);
	$("#lab-status").textContent = "Rendering…";
	$("#lab-try").disabled = true;
	const engine = $("#lab-engine").value;
	const qwen = engine !== "kokoro";
	const result = await api(qwen ? "/api/model_try" : "/api/try", qwen
		? { id: engine, text, instruction: engine === "qwen-custom-voice-small" ? "" : $("#qwen-instruction").value.trim(),
			speaker: $("#qwen-speaker").value, seed: parseInt($("#qwen-seed").value, 10) || 1,
			temperature: parseFloat($("#qwen-temperature").value) }
		: { text, voice, speed });
	$("#lab-try").disabled = false;
	if (!result.ok) {
		$("#lab-status").textContent = result.error || "Preview failed";
		return;
	}
	$("#lab-status").textContent = result.cached ? "Played from the scratch cache." : `Rendered ${result.seconds}s.`;
	(state.takes[line.uid] ||= []).unshift({ path: result.path, voice: qwen ? result.model : voice, speed: qwen ? null : speed,
		seed: qwen ? result.seed : null, temperature: qwen ? result.temperature : null, text, model_id: qwen ? engine : "" });
	renderTakes();
	toggle(result.path, `take · ${text}`);
}

// ---------------------------------------------------------------- editing

let previewTimer = 0;
function schedulePreview() {
	clearTimeout(previewTimer);
	previewTimer = setTimeout(preview, 350);
}

function draft() {
	const draft = { uid: state.selected.uid, text: $("#lab-text").value.trim(), mood: $("#lab-mood").value };
	if (state.selected.chapter === "doorway") {
		draft.dialogue = {
			speaker: $("#dialogue-speaker").value,
			reaction: $("#dialogue-reaction").value,
			answers: $("#dialogue-answers").value,
			quote: $("#dialogue-quote").value,
			intensity: parseFloat($("#dialogue-intensity").value),
			pause: parseFloat($("#dialogue-pause").value),
			overlap: parseFloat($("#dialogue-overlap").value),
			break: $("#dialogue-break").checked,
		};
	}
	return draft;
}

async function preview() {
	const line = state.selected;
	if (!line) return;
	const edit = draft();
	const panel = $("#lab-edit");
	const originalDialogue = line.chapter === "doorway" ? {
		speaker: line.speaker, reaction: line.meta?.reaction || "", answers: line.meta?.answers || "none",
		quote: line.meta?.quote || "", intensity: line.meta?.intensity ?? 0, pause: line.meta?.pause ?? 0,
		overlap: line.meta?.overlap ?? 0, break: Boolean(line.meta?.break),
	} : null;
	if (edit.text === line.text && edit.mood === line.mood &&
		(!edit.dialogue || JSON.stringify(edit.dialogue) === JSON.stringify(originalDialogue))) {
		panel.hidden = true;
		return;
	}
	const result = await api("/api/edit", { ...edit, dry_run: true });
	panel.hidden = false;
	const warnings = $("#lab-warnings");
	warnings.replaceChildren();
	$("#lab-save").disabled = Boolean(result.error);
	if (result.error) {
		warnings.append(el("p", { className: "bad", textContent: result.error }));
		$("#lab-diff").replaceChildren();
		return;
	}
	for (const warning of result.warnings) warnings.append(el("p", { className: "warn", textContent: "⚠ " + warning }));
	const diff = $("#lab-diff");
	diff.replaceChildren();
	for (const row of result.diff.split("\n")) {
		if (!row || row.startsWith("---") || row.startsWith("+++")) continue;
		const kind = row.startsWith("+") ? "add" : row.startsWith("-") ? "del" : row.startsWith("@@") ? "at" : "";
		diff.append(el("div", { className: kind, textContent: row }));
	}
}

function toast(message, ok = true) {
	const note = el("div", { className: `toast ${ok ? "ok" : "err"}`, textContent: message });
	document.body.append(note);
	setTimeout(() => note.remove(), ok ? 3500 : 8000);
}

async function save() {
	const uid = state.selected.uid;
	$("#lab-save").disabled = true;
	const result = await api("/api/edit", { ...draft(), dry_run: false });
	$("#lab-save").disabled = false;
	if (result.error) return toast(result.error, false);
	if (!result.unchanged) {
		toast(result.check_ok ? "Saved to the script; the table is rewritten and its check passes."
			: `Saved, but the check fails:\n${result.log.split("\n").slice(-3).join("\n")}`, result.check_ok);
	}
	await reloadKeeping(uid);
}

async function undo() {
	const result = await api("/api/undo", {});
	if (result.error) return toast(result.error, false);
	toast(`Undone: ${result.undone}`, result.check_ok);
	await reloadKeeping(result.uid);
}

async function reloadKeeping(uid) {
	await load();
	const line = state.lines.find((l) => l.uid === uid);
	if (line) select(line);
}

// The same choice the server makes (bake_for): what this machine can render for a line.
function bakePlan(line) {
	if (line.clip === "final") return [false, "It has its final clip."];
	if (line.chapter === "mathilda") return [true, "Bake: Kokoro, final for her chapter, then import."];
	if (line.chapter === "lake" && line.speaker === "mathilda") return [true, "Bake: Kokoro, final for her lake lines, then import."];
	if (line.chapter === "doorway" && line.clip === "missing") return [true, "Bake: a Kokoro draft (the final still waits for the desktop), then import."];
	if (line.chapter === "doorway") return [false, "It has a draft; its final needs Chatterbox on the desktop."];
	return [false, "Ophelia's voice needs Chatterbox on the desktop."];
}

async function bakeLine() {
	const result = await api("/api/bake_line", { uid: state.selected.uid });
	if (result.error) return toast(result.error, false);
	toast(`Baking ${state.selected.uid}… (${result.why}). It shows up here when the job is done.`);
	pollJobs();
}

async function hearInGame() {
	const result = await api("/api/play", { uid: state.selected.uid });
	if (result.error) return toast(result.error, false);
	toast(`Launching the game: ${result.where}  (${result.hooks})`);
}

async function refreshUndo() {
	const history = await api("/api/history");
	const button = $("#undo");
	button.hidden = !history.length;
	button.textContent = history.length ? `Undo edit (${history.length})` : "Undo edit";
	button.title = history.length ? `Put back: ${history[0].label}` : "";
}

// ---------------------------------------------------------------- views

function showView(name) {
	for (const view of ["lines", "review", "bake", "models"]) $(`#${view}-view`).hidden = view !== name;
	if (name === "review") renderReview();
	if (name === "models") renderModels();
	renderNav();
}

// ---------------------------------------------------------------- review

let reviewFocus = 0;

function reviewList() {
	const all = state.review || [];
	return $("#review-all").checked ? all : all.filter((i) => i.decision !== "accepted");
}

function renderReview() {
	const box = $("#review");
	box.replaceChildren();
	const list = reviewList();
	reviewFocus = Math.min(reviewFocus, Math.max(list.length - 1, 0));
	if (!list.length) {
		box.append(el("p", { className: "muted", textContent: (state.review || []).length
			? "Everything new has been accepted." : "Nothing new since the last commit. Bake something and it appears here." }));
		return;
	}
	list.forEach((item, index) => {
		const line = item.lines[0];
		const head = el("div", {});
		if (line) {
			head.append(el("div", { className: "uid", textContent: `${line.uid}${item.draft ? "  (draft)" : ""}` }),
				el("div", {}, moodChip(line.mood), " ", el("span", { textContent: line.text })));
		} else {
			head.append(el("div", { className: "uid", textContent: item.path }), el("div", { className: "muted", textContent: "No line plays this clip any more." }));
		}
		if (item.previous && (item.previous.text !== line?.text || item.previous.mood !== line?.mood)) {
			head.append(el("div", { className: "was" }, "was: ", el("s", { textContent: item.previous.text }), ` (${item.previous.mood})`));
		}
		const listen = el("div", { className: "listen" },
			el("span", {}, playButton(item.path, `new · ${line ? line.text : item.path}`), "new"));
		if (item.previous?.path) listen.append(el("span", {}, playButton(item.previous.path, `before · ${item.previous.text}`), "before"));
		if (item.impression) listen.append(el("span", {}, playButton(item.impression, `the ${line.mood} reference`), `${line.mood} reference`));
		head.append(listen);
		const accept = el("button", { className: "accept", textContent: item.decision === "accepted" ? "Accepted" : "Accept", disabled: item.decision === "accepted" });
		accept.onclick = () => decide(item, "accept");
		const reject = el("button", { className: "reject", textContent: "Reject" });
		reject.onclick = () => decide(item, "reject");
		const retake = el("button", { textContent: "Re-take", disabled: !item.retake, title: item.retake_why });
		retake.onclick = () => decide(item, "retake");
		const card = el("div", { className: `card${index === reviewFocus ? " focus" : ""}${item.decision === "accepted" ? " accepted" : ""}` },
			head, el("div", { className: "decide" }, accept, reject, retake));
		card.onclick = () => { reviewFocus = index; renderReview(); };
		box.append(card);
	});
	box.querySelector(".card.focus")?.scrollIntoView({ block: "nearest" });
}

async function decide(item, what) {
	const route = { accept: "/api/review/accept", reject: "/api/review/reject", retake: "/api/review/retake" }[what];
	const result = await api(route, { key: item.key, path: item.path });
	if (result.error || result.ok === false) return toast(result.error || "That did not work", false);
	if (what === "reject") toast(`Rejected; moved to ${result.archived_to}`);
	if (what === "retake") { toast("Rejected and queued a re-take."); pollJobs(); }
	await load();
	renderReview();
}

document.addEventListener("keydown", (e) => {
	if ($("#review-view").hidden || e.target.matches("input, textarea, select")) return;
	const list = reviewList();
	const item = list[reviewFocus];
	if (e.key === "ArrowDown" || e.key === "j") { reviewFocus = Math.min(reviewFocus + 1, list.length - 1); renderReview(); e.preventDefault(); }
	else if (e.key === "ArrowUp" || e.key === "k") { reviewFocus = Math.max(reviewFocus - 1, 0); renderReview(); e.preventDefault(); }
	else if (item && e.key === " ") { e.preventDefault(); e.stopImmediatePropagation(); toggle(item.path, `new · ${item.lines[0]?.text || item.path}`); }
	else if (item && (e.key === "a" || e.key === "A")) decide(item, "accept");
	else if (item && (e.key === "r" || e.key === "R")) decide(item, "reject");
}, true);

// ---------------------------------------------------------------- bake

function renderActions() {
	const box = $("#actions");
	box.replaceChildren();
	for (const action of state.actions) {
		const run = el("button", { className: action.kind === "bake" ? "primary" : "", textContent: "Run", disabled: !action.runnable,
			title: action.runnable ? "" : "This machine cannot run it (missing venv or Godot)" });
		run.onclick = () => runAction(action.id);
		box.append(el("div", { className: "action" }, el("div", { className: "kind", textContent: action.kind }),
			el("b", { textContent: action.label }), el("code", { textContent: action.commands.join("\n") }), run));
	}
}

async function runAction(id) {
	await api("/api/run", { action: id });
	showView("bake");
	pollJobs();
}

let polling = false;
async function pollJobs() {
	if (polling) return;
	polling = true;
	let busy = true;
	while (busy) {
		const jobs = await api("/api/jobs");
		jobsBusy = jobs.some((j) => j.state === "running" || j.state === "queued");
		renderJobs(jobs);
		state.models = await api("/api/models");
		renderModels();
		busy = jobsBusy;
		if (!busy) break;
		await new Promise((r) => setTimeout(r, 900));
	}
	polling = false;
	jobsBusy = false;
	if (state.selected) await reloadKeeping(state.selected.uid);
	else await load();
}

function renderJobs(jobs) {
	for (const box of [$("#jobs"), $("#model-jobs")]) {
		if (!box) continue;
		const open = new Set([...box.querySelectorAll("details[open]")].map((d) => d.dataset.id));
		box.replaceChildren();
		for (const job of jobs) {
			const pre = el("pre", { textContent: job.log.join("\n") });
			const details = el("details", { className: "job", open: job.state === "running" || open.has(String(job.id)) },
				el("summary", {}, el("span", { className: `state ${job.state}`, textContent: job.state }), el("b", { textContent: job.label }),
					el("span", { className: "muted", textContent: job.code === null ? "" : `exit ${job.code}` })), pre);
			details.dataset.id = job.id;
			box.append(details);
		}
		if (!jobs.length) box.append(el("p", { className: "muted", textContent: "Nothing has run yet." }));
	}
}

function configureModelControls() {
	const select = $("#lab-engine");
	const selected = select.value || "kokoro";
	select.replaceChildren(el("option", { value: "kokoro", textContent: "Kokoro · quick baseline" }));
	for (const model of state.models.models || []) {
		select.append(el("option", { value: model.id, textContent: model.downloaded ? model.name : `${model.name} · download first` }));
	}
	select.value = [...select.options].some((option) => option.value === selected) ? selected : "kokoro";
	const engine = state.models.models.find((item) => item.id === select.value);
	const qwen = Boolean(engine);
	$("#qwen-instruction-wrap").hidden = !qwen || engine.id === "qwen-custom-voice-small";
	$("#qwen-speaker-wrap").hidden = !qwen || engine.id === "qwen-voice-design";
	$("#qwen-variation-row").hidden = !qwen;
	$("#lab-speed").closest("label").hidden = qwen;
	$("#engine-help").textContent = engine?.id === "qwen-custom-voice-small"
		? "0.6B CustomVoice compares built-in timbres; emotional instructions are unavailable in this model."
		: qwen ? "Qwen previews are scratch takes. VoiceDesign creates an instructed voice; CustomVoice keeps a built-in timbre while varying delivery."
			: "Kokoro is a local baseline. Qwen experimental takes are saved only in scratch and do not alter the game's voice locks.";
}

function renderModels() {
	if (!state.models) return;
	$("#model-runtime").textContent = state.models.runtime_ready
		? "Qwen inference is ready on this machine (CUDA runtime detected)."
		: `Downloads are available${state.models.downloader_ready ? "" : " once uv is installed"}; Qwen inference needs an NVIDIA GPU and build/voice/gpu-venv. ${state.models.chatterbox_ready ? "Chatterbox conversion runtime is installed." : "Chatterbox identity conversion runtime is not installed here."}`;
	const box = $("#model-cards");
	box.replaceChildren();
	for (const item of state.models.models || []) {
		const status = item.downloaded ? (state.models.runtime_ready ? "Ready to preview" : "Weights ready · GPU runtime needed") : `Download · ${item.size}`;
		const button = el("button", { className: item.downloaded ? "" : "primary", textContent: item.downloaded ? "Use in voice lab" : "Download model",
			disabled: item.downloaded ? !state.models.runtime_ready : !state.models.downloader_ready || jobsBusy });
		button.onclick = async () => {
			if (item.downloaded) {
				$("#lab-engine").value = item.id;
				configureModelControls();
				if (state.selected) showView("lines");
				else toast("Choose a story line, then open the voice lab to preview this model.");
				return;
			}
			const result = await api("/api/models/download", { id: item.id });
			if (result.error) return toast(result.error, false);
			toast(`Downloading ${item.name}. Progress and any Hugging Face access issue will appear in Jobs.`);
			pollJobs();
		};
		const use = el("button", { className: "ghost", textContent: "Select for lab" });
		use.onclick = () => {
			$("#lab-engine").value = item.id;
			configureModelControls();
			if (state.selected) showView("lines"); else toast("Choose a story line, then open the voice lab.");
		};
		box.append(el("article", { className: "model-card" },
			el("div", { className: "kind", textContent: `${item.license} · ${item.size}` }),
			el("h3", {}, el("a", { href: item.url, target: "_blank", rel: "noreferrer", textContent: item.name })),
			el("p", { textContent: item.role }),
			el("div", { className: `model-status ${item.downloaded ? "ready" : ""}`, textContent: status }),
			el("div", { className: "row" }, button, use)));
	}
	renderConversationControls();
}

const QWEN_SPEAKERS = ["Serena", "Vivian", "Sohee", "Ryan", "Aiden", "Dylan", "Eric", "Uncle_Fu", "Ono_Anna"];
const CHAIN_STORAGE_KEY = "story-studio:voice-chains:v1";
const CHARACTER_VOICE_BASES = {
	ophelia: "Low, intimate feminine voice with clear consonants and restrained breath.",
	mathilda: "Soft, steady feminine voice, warmer and more open than Ophelia; fatigue sits underneath her calm.",
};
const CHARACTER_ARCHETYPES = {
	guarded_witness: { label: "Guarded Witness", ophelia: "Observant and self-contained; let fear show only as a slight catch, never as a raised voice.", mathilda: "Watchful and composed; warmth is present but carefully rationed, with fatigue held beneath the words." },
	tender_survivor: { label: "Tender Survivor", ophelia: "Let hard-won tenderness surface in brief, unguarded moments; keep the underlying strain audible.", mathilda: "Offer quiet warmth shaped by exhaustion; allow care to soften phrase endings without sentimentality." },
	defiant_protector: { label: "Defiant Protector", ophelia: "Use grounded, deliberate resolve; protectiveness should sound controlled, with fear still underneath.", mathilda: "Sound steady and protective, with firm consonants and measured pace; avoid turning resolve into a threat." },
	quiet_confessor: { label: "Quiet Confessor", ophelia: "Speak as if choosing each admission carefully; let small hesitations carry more than volume.", mathilda: "Allow a private, vulnerable openness; keep the confession plainspoken, with no performed sobbing." },
	dry_deflector: { label: "Dry Deflector", ophelia: "Use understated, dry humor to deflect discomfort; let the joke pass quickly and leave the hurt intact.", mathilda: "Give wit a gentle, tired edge; make it sound like a familiar defense, not a punchline." },
	fraying_resolve: { label: "Fraying Resolve", ophelia: "Begin composed and let strain leak through breath and pacing; keep the final words intelligible.", mathilda: "Hold to calm while fatigue begins to fracture it; build subtly, without a sudden theatrical break." },
	uncanny_calm: { label: "Uncanny Calm", ophelia: "Stay unusually even and close, as if listening to something others cannot hear; avoid a supernatural caricature.", mathilda: "Keep a gentle, unnervingly settled calm; let stillness create unease without an overtly eerie affect." },
	steadfast_guide: { label: "Steadfast Guide", ophelia: "Give clear, reassuring direction at a low volume; urgency should sharpen focus rather than raise pitch.", mathilda: "Sound practical and quietly reassuring, with patient pacing; let her own uncertainty remain human." },
};

function profileForArchetype(speaker, archetype) {
	const entry = CHARACTER_ARCHETYPES[archetype];
	return entry ? `${CHARACTER_VOICE_BASES[speaker]} ${entry.label}: ${entry[speaker]}` : "";
}

function setupCharacterArchetypes() {
	for (const speaker of Object.keys(CHARACTER_VOICE_BASES)) {
		const select = $(`#conversation-${speaker}-archetype`);
		for (const [id, archetype] of Object.entries(CHARACTER_ARCHETYPES)) {
			select.insertBefore(el("option", { value: id, textContent: archetype.label }), select.querySelector('[value="custom"]'));
		}
		select.onchange = () => {
			const profile = profileForArchetype(speaker, select.value);
			if (profile) $(`#conversation-${speaker}`).value = profile;
			markConversationDirty();
		};
		$(`#conversation-${speaker}`).addEventListener("input", () => { select.value = "custom"; });
	}
}

function savedChains() {
	try {
		const value = JSON.parse(localStorage.getItem(CHAIN_STORAGE_KEY) || "{}");
		return value && typeof value === "object" && !Array.isArray(value) ? value : {};
	} catch (_) { return {}; }
}

function renderConversationControls() {
	const modelSelect = $("#conversation-model");
	const previous = modelSelect.value;
	modelSelect.replaceChildren();
	const capable = (state.models?.models || []).filter((item) => item.downloaded && item.contextual);
	if (!capable.length) modelSelect.append(el("option", { value: "", textContent: "Download Qwen VoiceDesign or CustomVoice 1.7B first" }));
	for (const item of capable) modelSelect.append(el("option", { value: item.id, textContent: item.name }));
	modelSelect.value = capable.some((item) => item.id === previous) ? previous : (capable[0]?.id || "");
	$("#conversation-run").disabled = !state.models?.runtime_ready || !modelSelect.value || state.conversationTurns.length < 2 || state.conversationTurns.length > 8;
	const selected = capable.find((item) => item.id === modelSelect.value);
	for (const label of document.querySelectorAll(".turn-voice-label")) label.hidden = selected?.id === "qwen-voice-design";
	renderConversationPresets();
	renderConversationSource();
	renderConversationTurns();
}

function renderConversationSource() {
	const select = $("#conversation-source");
	const query = $("#conversation-search").value.trim().toLowerCase();
	const lines = state.lines.filter((line) => !query || `${line.uid} ${line.speaker} ${line.mood} ${line.text}`.toLowerCase().includes(query));
	const previous = select.value;
	select.replaceChildren();
	for (const line of lines) {
		const shortText = line.text.length > 86 ? `${line.text.slice(0, 83)}…` : line.text;
		select.append(el("option", { value: line.uid, textContent: `${line.speaker} · ${line.chapter} · ${line.mood} — ${shortText}` }));
	}
	if (lines.some((line) => line.uid === previous)) select.value = previous;
}

function addConversationTurn(line = null) {
	if (state.conversationTurns.length >= 8) return toast("A contextual audition is limited to eight turns.", false);
	const speaker = line?.speaker === "mathilda" ? "mathilda" : (state.conversationTurns.at(-1)?.speaker === "ophelia" ? "mathilda" : "ophelia");
	const mood = line?.mood || "steady";
	state.conversationTurns.push({ uid: line?.uid || "draft-turn", speaker, mood, text: line?.text || "", voice: speaker === "mathilda" ? "Vivian" : "Serena",
		direction: MOOD_DIRECTIONS[mood] || MOOD_DIRECTIONS.steady });
	markConversationDirty();
	renderConversationTurns();
}

function markConversationDirty() {
	state.conversationDirty = true;
	if ($("#conversation-results").children.length) {
		$("#conversation-status").textContent = "Chain changed since these takes. Render again to compare the current settings.";
	}
}

function renderConversationTurns() {
	const list = $("#conversation-turns");
	if (!list) return;
	list.replaceChildren();
	const isDesign = $("#conversation-model")?.value === "qwen-voice-design";
	state.conversationTurns.forEach((turn, index) => {
		const speaker = el("select", { className: "turn-speaker" });
		for (const key of ["ophelia", "mathilda"]) speaker.append(el("option", { value: key, textContent: key === "ophelia" ? "Ophelia" : "Mathilda" }));
		speaker.value = turn.speaker;
		speaker.onchange = () => { turn.speaker = speaker.value; turn.voice = turn.speaker === "mathilda" ? "Vivian" : "Serena"; markConversationDirty(); renderConversationTurns(); };
		const voice = el("select", { className: "turn-voice" });
		for (const name of QWEN_SPEAKERS) voice.append(el("option", { value: name, textContent: name }));
		voice.value = turn.voice;
		voice.hidden = isDesign;
		voice.onchange = () => { turn.voice = voice.value; };
		const mood = el("select", { className: "turn-mood" });
		for (const name of Object.keys(MOOD_DIRECTIONS)) mood.append(el("option", { value: name, textContent: name }));
		mood.value = turn.mood;
		mood.onchange = () => {
			const old = MOOD_DIRECTIONS[turn.mood];
			turn.mood = mood.value;
			if (turn.direction === old) turn.direction = MOOD_DIRECTIONS[turn.mood];
			markConversationDirty();
			renderConversationTurns();
		};
		const direction = el("textarea", { value: turn.direction, rows: 2, maxLength: 320 });
		direction.oninput = () => { turn.direction = direction.value; };
		const text = el("textarea", { className: "turn-text", value: turn.text, rows: 2, maxLength: 600,
			placeholder: "Type an experimental reply; this does not change the script." });
		text.oninput = () => { turn.text = text.value; updateConversationRunButton(); };
		const move = (delta) => {
			const at = index + delta;
			if (at < 0 || at >= state.conversationTurns.length) return;
			[state.conversationTurns[index], state.conversationTurns[at]] = [state.conversationTurns[at], state.conversationTurns[index]];
			markConversationDirty();
			renderConversationTurns();
		};
		const remove = el("button", { className: "ghost", textContent: "Remove", title: "Remove turn" });
		remove.onclick = () => { state.conversationTurns.splice(index, 1); markConversationDirty(); renderConversationTurns(); };
		const up = el("button", { className: "ghost", textContent: "↑", title: "Move turn earlier", "aria-label": "Move turn earlier", disabled: index === 0, onclick: () => move(-1) });
		const down = el("button", { className: "ghost", textContent: "↓", title: "Move turn later", "aria-label": "Move turn later", disabled: index === state.conversationTurns.length - 1, onclick: () => move(1) });
		const copy = el("span", { className: "turn-copy", textContent: `${index + 1}. ${turn.uid === "draft-turn" ? "Experimental line" : turn.uid}` });
		const voiceLabel = el("label", { className: "turn-voice-label" }, "Timbre", voice);
		voiceLabel.hidden = isDesign;
		const metadata = el("div", { className: "turn-meta" }, el("label", {}, "Character", speaker), el("label", {}, "Mood", mood),
			voiceLabel, el("label", { className: "direction" }, "Acting direction", direction));
		list.append(el("li", { className: "conversation-turn" },
			el("div", { className: "conversation-turn-head" }, copy, up, down, remove), text, metadata));
	});
	updateConversationRunButton();
}

function updateConversationRunButton() {
	$("#conversation-run").disabled = !state.models?.runtime_ready || !$("#conversation-model").value ||
		state.conversationTurns.length < 2 || state.conversationTurns.length > 8 || state.conversationTurns.some((turn) => !turn.text.trim());
}

function renderConversationPresets(selected = $("#conversation-preset").value) {
	const select = $("#conversation-preset");
	if (!select) return;
	select.replaceChildren(el("option", { value: "", textContent: "New chain" }));
	for (const name of Object.keys(savedChains()).sort((a, b) => a.localeCompare(b))) select.append(el("option", { value: name, textContent: name }));
	select.value = [...select.options].some((option) => option.value === selected) ? selected : "";
	$("#conversation-delete").disabled = !select.value;
}

function saveConversationPreset() {
	const name = $("#conversation-name").value.trim();
	if (!name) return toast("Give this conversation chain a name first.", false);
	if (state.conversationTurns.length < 2) return toast("Add at least two turns before saving a chain.", false);
	const all = savedChains();
	all[name] = { model: $("#conversation-model").value, context: $("#conversation-context").value,
		profiles: { ophelia: $("#conversation-ophelia").value, mathilda: $("#conversation-mathilda").value },
		archetypes: { ophelia: $("#conversation-ophelia-archetype").value, mathilda: $("#conversation-mathilda-archetype").value },
		variants: $("#conversation-variants").value, temperature: $("#conversation-temperature").value,
		turns: state.conversationTurns };
	try { localStorage.setItem(CHAIN_STORAGE_KEY, JSON.stringify(all)); }
	catch (_) { return toast("This browser could not save the chain. Check its local storage settings.", false); }
	renderConversationPresets(name);
	toast(`Saved “${name}” in this browser. The story scripts are unchanged.`);
}

function loadConversationPreset(name) {
	if (!name) return;
	const chain = savedChains()[name];
	if (!chain) return;
	$("#conversation-model").value = chain.model || $("#conversation-model").value;
	$("#conversation-context").value = chain.context || "";
	$("#conversation-ophelia").value = chain.profiles?.ophelia || "";
	$("#conversation-mathilda").value = chain.profiles?.mathilda || "";
	for (const speaker of Object.keys(CHARACTER_VOICE_BASES)) {
		const saved = chain.archetypes?.[speaker];
		$(`#conversation-${speaker}-archetype`).value = saved === "custom" || CHARACTER_ARCHETYPES[saved] ? saved : "custom";
	}
	$("#conversation-variants").value = chain.variants || "2";
	$("#conversation-temperature").value = chain.temperature || "0.85";
	$("#conversation-temperature-out").textContent = parseFloat($("#conversation-temperature").value).toFixed(2);
	state.conversationTurns = Array.isArray(chain.turns) ? chain.turns.slice(0, 8) : [];
	markConversationDirty();
	renderConversationControls();
	renderConversationTurns();
	$("#conversation-name").value = name;
}

function deleteConversationPreset() {
	const name = $("#conversation-preset").value;
	if (!name) return;
	const all = savedChains();
	delete all[name];
	try { localStorage.setItem(CHAIN_STORAGE_KEY, JSON.stringify(all)); }
	catch (_) { return toast("This browser could not update saved chains.", false); }
	$("#conversation-name").value = "";
	renderConversationPresets("");
}

async function runConversation() {
	const body = { id: $("#conversation-model").value, context: $("#conversation-context").value,
		profiles: { ophelia: $("#conversation-ophelia").value, mathilda: $("#conversation-mathilda").value },
		variants: parseInt($("#conversation-variants").value, 10), seed: parseInt($("#conversation-seed").value, 10) || 1,
		temperature: parseFloat($("#conversation-temperature").value), turns: state.conversationTurns };
	const button = $("#conversation-run");
	button.disabled = true;
	button.classList.add("running");
	button.textContent = `Rendering ${body.variants * body.turns.length} clips…`;
	$(".conversation-workbench").setAttribute("aria-busy", "true");
	$("#conversation-results").replaceChildren();
	$("#conversation-status").textContent = `Rendering ${body.variants * body.turns.length} connected utterances. Each reply gets the scene and preceding turns as context…`;
	try {
		const result = await api("/api/model_conversation", body);
		if (!result.ok) {
			$("#conversation-status").textContent = result.error || "Conversation render failed.";
			return;
		}
		state.conversationResults = result.variants;
		state.conversationDirty = false;
		$("#conversation-status").textContent = `${result.model} · ${result.variants.length} variation${result.variants.length === 1 ? "" : "s"}. Scratch audio only; no story line was changed.`;
		renderConversationResults();
	} catch (error) {
		$("#conversation-status").textContent = `Could not reach the voice worker: ${error.message}`;
	} finally {
		button.classList.remove("running");
		button.textContent = "Render conversation variants";
		$(".conversation-workbench").setAttribute("aria-busy", "false");
		updateConversationRunButton();
	}
}

function renderConversationResults() {
	const box = $("#conversation-results");
	box.replaceChildren();
	for (const [index, variant] of state.conversationResults.entries()) {
		const rows = el("ol");
		for (const turn of variant.turns) rows.append(el("li", {}, playButton(turn.path, `${turn.speaker} · ${turn.text}`),
			el("span", { textContent: `${turn.speaker} · ${turn.mood} — “${turn.text}”` })));
		box.append(el("article", { className: "variant-result" }, el("h3", { textContent: `Take ${index + 1} · seed ${variant.seed} · temperature ${variant.temperature.toFixed(2)}${variant.cached ? " · cached" : ""}` }), rows));
	}
}

let jobsBusy = false;

// ---------------------------------------------------------------- wiring

$("#search").addEventListener("input", (e) => { state.filter.q = e.target.value; renderRows(); });
for (const [group, key] of [["#status-filter", "status"], ["#speaker-filter", "speaker"]]) {
	$(group).addEventListener("click", (e) => {
		const button = e.target.closest("button");
		if (!button) return;
		for (const b of $(group).children) b.classList.toggle("on", b === button);
		for (const b of $(group).children) b.setAttribute("aria-pressed", b === button ? "true" : "false");
		state.filter[key] = button.dataset[key];
		renderRows();
	});
}
$("#lab-close").onclick = () => { $("#lab").hidden = true; state.selected = null; renderRows(); };
$("#lab-try").onclick = tryReading;
$("#lab-engine").onchange = configureModelControls;
$("#conversation-search").oninput = renderConversationSource;
$("#conversation-add").onclick = () => addConversationTurn(state.lines.find((line) => line.uid === $("#conversation-source").value));
$("#conversation-add-free").onclick = () => addConversationTurn();
$("#conversation-model").onchange = renderConversationTurns;
$("#conversation-run").onclick = runConversation;
$("#conversation-new-seed").onclick = () => { $("#conversation-seed").value = Math.floor(Math.random() * 2_147_480_000) + 1; markConversationDirty(); };
$("#qwen-new-seed").onclick = () => { $("#qwen-seed").value = Math.floor(Math.random() * 2_147_480_000) + 1; };
$("#qwen-temperature").oninput = (event) => { $("#qwen-temperature-out").textContent = parseFloat(event.target.value).toFixed(2); };
$("#conversation-temperature").oninput = (event) => { $("#conversation-temperature-out").textContent = parseFloat(event.target.value).toFixed(2); };
$("#conversation-save").onclick = saveConversationPreset;
$("#conversation-delete").onclick = deleteConversationPreset;
$("#conversation-preset").onchange = (event) => loadConversationPreset(event.target.value);
setupCharacterArchetypes();
$(".conversation-workbench").addEventListener("input", (event) => {
	if (!["conversation-search", "conversation-name", "conversation-source"].includes(event.target.id)) markConversationDirty();
});
$(".conversation-workbench").addEventListener("change", (event) => {
	if (!["conversation-search", "conversation-name", "conversation-source", "conversation-preset"].includes(event.target.id)) markConversationDirty();
});
$("#lab-speed").oninput = (e) => { $("#lab-speed-out").textContent = parseFloat(e.target.value).toFixed(2); };
$("#check-all").onclick = () => runAction("validate");
$("#lab-text").addEventListener("input", schedulePreview);
$("#lab-mood").addEventListener("change", () => {
	if (!state.autoDirective || $("#qwen-instruction").value === state.autoDirective) {
		state.autoDirective = MOOD_DIRECTIONS[$("#lab-mood").value] || MOOD_DIRECTIONS.steady;
		$("#qwen-instruction").value = state.autoDirective;
	}
	schedulePreview();
});
for (const id of ["dialogue-speaker", "dialogue-answers", "dialogue-reaction", "dialogue-quote", "dialogue-intensity", "dialogue-pause", "dialogue-overlap", "dialogue-break"]) {
	$("#" + id).addEventListener("input", schedulePreview);
	$("#" + id).addEventListener("change", schedulePreview);
}
$("#dialogue-speaker").addEventListener("change", (event) => {
	const mathilda = event.target.value === "mathilda";
	$("#lab-voice").value = mathilda ? "af_bella" : "af_sarah";
	$("#lab-speed").value = mathilda ? "0.94" : "0.92";
	$("#lab-speed-out").textContent = parseFloat($("#lab-speed").value).toFixed(2);
});
$("#lab-save").onclick = save;
$("#lab-reset").onclick = () => { if (state.selected) select(state.selected); };
$("#undo").onclick = undo;
$("#lab-bake").onclick = bakeLine;
$("#lab-game").onclick = hearInGame;
document.addEventListener("keydown", (e) => {
	if ((e.ctrlKey || e.metaKey) && e.key === "s" && !$("#lab-edit").hidden && !$("#lab-save").disabled) {
		e.preventDefault();
		save();
	}
});
document.addEventListener("keydown", (e) => {
	if (e.target.matches("input, textarea, select")) return;
	if (e.key === "Escape") $("#lab-close").click();
	if (e.key === "t" && state.selected) tryReading();
	if (e.key === " ") {
		if (state.playing) { e.preventDefault(); toggle(state.playing.path); }
		else if (state.selected?.clip_path) { e.preventDefault(); toggle(state.selected.clip_path, labelOf(state.selected)); }
	}
});

// #line=<uid> opens a line in the lab, so other tools can link straight to it.
function openFromHash() {
	if (location.hash === "#review" || location.hash === "#bake") return showView(location.hash.slice(1));
	const uid = decodeURIComponent(location.hash.replace(/^#line=/, ""));
	const line = state.lines.find((l) => l.uid === uid);
	if (line) {
		show({ chapter: line.chapter, group: line.group, owed: "" });
		select(line);
	}
}
window.addEventListener("hashchange", openFromHash);

load().then(() => { openFromHash(); pollJobs(); });
$("#review-all").addEventListener("change", renderReview);
