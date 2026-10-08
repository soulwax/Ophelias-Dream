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

const state = { lines: [], summary: {}, actions: [], filter: { chapter: "", group: "", status: "", speaker: "", owed: "", q: "" },
	selected: null, takes: {}, playing: null, voicesLoaded: false };
const player = $("#player");

async function api(path, body) {
	const response = await fetch(path, body ? { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) } : {});
	return response.json();
}

async function load() {
	const data = await api("/api/state");
	Object.assign(state, { lines: data.lines, summary: data.summary, actions: data.actions, orphans: data.orphans });
	state.review = await api("/api/review");
	const moods = $("#lab-mood");
	if (!moods.children.length) for (const mood of data.moods) moods.append(el("option", { value: mood, textContent: mood }));
	refreshUndo();
	renderSummary();
	renderNav();
	renderRows();
	renderActions();
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
	$("#lab-voice").value = line.speaker === "mathilda" ? "af_bella" : "af_sarah";
	const speed = line.speaker === "mathilda" ? 0.94 : 0.92;
	$("#lab-speed").value = speed;
	$("#lab-speed-out").textContent = speed.toFixed(2);
	renderTakes();
	renderRows();
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
		list.append(el("li", {}, playButton(take.path, `take · ${take.text}`), el("span", { textContent: `${take.voice} · ${take.speed.toFixed(2)} — “${take.text.slice(0, 60)}”` })));
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
	const result = await api("/api/try", { text, voice, speed });
	$("#lab-try").disabled = false;
	if (!result.ok) {
		$("#lab-status").textContent = result.error || "Kokoro failed";
		return;
	}
	$("#lab-status").textContent = result.cached ? "Played from the scratch cache." : `Rendered ${result.seconds}s.`;
	(state.takes[line.uid] ||= []).unshift({ path: result.path, voice, speed, text });
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
	return { uid: state.selected.uid, text: $("#lab-text").value.trim(), mood: $("#lab-mood").value };
}

async function preview() {
	const line = state.selected;
	if (!line) return;
	const edit = draft();
	const panel = $("#lab-edit");
	if (edit.text === line.text && edit.mood === line.mood) {
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
	for (const view of ["lines", "review", "bake"]) $(`#${view}-view`).hidden = view !== name;
	if (name === "review") renderReview();
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
		renderJobs(jobs);
		busy = jobs.some((j) => j.state === "running" || j.state === "queued");
		if (!busy) break;
		await new Promise((r) => setTimeout(r, 900));
	}
	polling = false;
	if (state.selected) await reloadKeeping(state.selected.uid);
	else await load();
}

function renderJobs(jobs) {
	const box = $("#jobs");
	const open = new Set([...box.querySelectorAll("details[open]")].map((d) => d.dataset.id));
	box.replaceChildren();
	for (const job of jobs) {
		const pre = el("pre", { textContent: job.log.join("\n") });
		const details = el("details", { className: "job", open: job.state === "running" || open.has(String(job.id)) },
			el("summary", {}, el("span", { className: `state ${job.state}`, textContent: job.state }), el("b", { textContent: job.label }),
				el("span", { className: "muted", textContent: job.code === null ? "" : `exit ${job.code}` })), pre);
		details.dataset.id = job.id;
		box.append(details);
		pre.scrollTop = pre.scrollHeight;
	}
	if (!jobs.length) box.append(el("p", { className: "muted", textContent: "Nothing has run yet." }));
}

// ---------------------------------------------------------------- wiring

$("#search").addEventListener("input", (e) => { state.filter.q = e.target.value; renderRows(); });
for (const [group, key] of [["#status-filter", "status"], ["#speaker-filter", "speaker"]]) {
	$(group).addEventListener("click", (e) => {
		const button = e.target.closest("button");
		if (!button) return;
		for (const b of $(group).children) b.classList.toggle("on", b === button);
		state.filter[key] = button.dataset[key];
		renderRows();
	});
}
$("#lab-close").onclick = () => { $("#lab").hidden = true; state.selected = null; renderRows(); };
$("#lab-try").onclick = tryReading;
$("#lab-speed").oninput = (e) => { $("#lab-speed-out").textContent = parseFloat(e.target.value).toFixed(2); };
$("#check-all").onclick = () => runAction("validate");
$("#lab-text").addEventListener("input", schedulePreview);
$("#lab-mood").addEventListener("change", schedulePreview);
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
