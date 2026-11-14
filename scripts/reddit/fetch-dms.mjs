// fetch-dms.mjs — read Christian's Reddit DMs for the beta-feedback sweep.
//
// Runs INSIDE the ego-browser node runtime (`ego-browser nodejs -e …`), driven by
// scripts/reddit/fetch-dms.sh. Do not run it with plain node: it needs the
// logged-in ego lite session for two things —
//   1. the Reddit *chat* access token (localStorage `chat:access-token` on
//      www.reddit.com/chat), which this script reads into memory and sends as a
//      Bearer header to the chat backend's Matrix API (matrix.redditspace.com);
//   2. the session cookies for the legacy inbox (`/message/inbox.json`:
//      private messages, comment replies, username mentions), fetched
//      same-origin from inside the page.
// The token never leaves the process and is never written anywhere.
//
// Why Matrix and not the chat page's DOM: the DOM walker only reads one known
// room and truncates nothing but is shadow-DOM dependent; `/joined_rooms` +
// `/rooms/{id}/messages` lists EVERY room (new testers included), with exact
// timestamps, in one pass. `/rooms/{id}/joined_members` 404s on Reddit's
// backend; `/rooms/{id}/members` works and carries `displayname`.
//
// The wrapper prepends `const CFG = {...};` with:
//   space   numeric ego-browser task-space id (by-name creation hangs
//           intermittently; numeric ids are reliable — see memory)
//   since   ISO timestamp; only events strictly newer are emitted
//   limit   max events fetched per room (pagination stops at `since`)
//   summary true → human-readable digest; false → JSON on stdout
//   log     absolute path of a progress log (ego only flushes stdout at exit)
//
// Unanswered rooms: independent of `since`, every joined room's newest ORIGINAL
// message (edits, rel_type m.replace, are ignored for this) is checked; if its
// sender is not the signed-in user the room is reported as "awaiting reply"
// (summary section + `unanswered` array in JSON). A failed Matrix call (non-200
// on /joined_rooms, /members or /messages) is recorded in `errors` and the
// section says it is incomplete; an unknown signed-in user skips the decision.
// `complete` in the JSON is true only when `errors` is empty (whole run, inbox
// included); `chatComplete` covers the chat side alone (identity, room list, every
// room, invites) and is what the dm_owed gate reads; inbox failures are also listed
// in `inboxErrors` and print as an "Inbox problem:" line, not under "Errors:".
// A 200 with a missing or non-JSON body counts as a failure, not a clean read.
// Pending chat requests: a read-only /sync with a timeline-limiting filter,
// reading only rooms.invite (first contacts that arrive as Matrix invites do
// not show in /joined_rooms). Nothing is ever joined or accepted. `pending`
// array in JSON, "Pending chat requests" section in the summary.
// The room scan, the invite read and the summary text live in the BEGIN/END pure
// block below, which scripts/reddit/fetch-dms.test.mjs loads straight from this
// file (one source of truth, HTTP getter passed in); inside it keep to the
// flattening rules: semicolons, no end-of-line comments, await only in async
// functions, no CFG.
//
// Page use: the task space starts with one page (p1); the script reuses the first
// existing page and opens a new one only when the space has none, so repeated runs
// never grow the space (the runtime caps it at 8 pages). Nothing is closed here:
// process.exit and the wrapper's alarm would skip a close anyway.
//
// Exit codes (the success path exits 0 explicitly after the output is written: a timed-out inbox read leaves a pending page operation that would otherwise hold the process until the wrapper's alarm): 0 ok · 3 no chat token / 401 (open reddit.com/chat in ego lite
// and sign in) · 4 ego-browser page/control-plane failure or any other unexpected
// throw (one line on stderr).

const fs = await import("node:fs/promises");
const L = async (m) => { if (CFG.log) { try { await fs.appendFile(CFG.log, new Date().toISOString() + " " + m + "\n"); } catch (e) {} } };
const sinceMs = CFG.since ? Date.parse(CFG.since) : 0;
if (Number.isNaN(sinceMs)) { console.error("fetch-dms: --since is not a parseable timestamp: " + CFG.since); process.exit(4); }
const out = { fetchedAt: new Date().toISOString(), since: CFG.since || null, me: null, chat: [], unanswered: [], pending: [], pendingChecked: false, unreadable: [], roomListFailed: false, complete: false, chatComplete: false, inbox: [], errors: [], inboxErrors: [] };

let task, page;
try {
  task = await taskSpace(CFG.space);
  await L("space " + CFG.space + " ok");
  const existing = await task.pages();
  page = existing && existing.length ? existing[0] : await task.newPage();
  const openChat = async () => { await page.goto("https://www.reddit.com/chat/"); await new Promise((r) => setTimeout(r, 8000)); await L("chat page loaded " + (await page.evaluate("location.href"))); };
  try { await openChat(); } catch (e1) { await L("reused page failed (" + (e1 && e1.message || e1) + "); opening a new page"); page = await task.newPage(); await openChat(); }
} catch (e) {
  console.error("ego-browser failure: " + (e && e.message || e));
  process.exit(4);
}

let exiting = false;
try {
const raw = await page.evaluate("localStorage.getItem(\"chat:access-token\") || \"\"");
if (!raw) {
  console.error("no chat access token in localStorage — open https://www.reddit.com/chat in ego lite and sign in, then rerun");
  await L("no token");
  exiting = true;
  process.exit(3);
}
let token;
try { token = JSON.parse(raw).token; } catch (e) { token = raw; }
const H = { Authorization: "Bearer " + token };
const base = "https://matrix.redditspace.com/_matrix/client/v3";
const get = async (p) => {
  const r = await fetch(base + p, { headers: H, signal: AbortSignal.timeout(30000) });
  const t = await r.text();
  let j = null; try { j = JSON.parse(t); } catch (e) {}
  return { status: r.status, json: j, text: t.slice(0, 200) };
};

let who;
let whoErr = null;
try { who = await get("/account/whoami"); } catch (e) { who = { status: 0, json: null, text: "" }; whoErr = e && e.message || String(e); }
if (who.status === 401 || who.status === 403) {
  console.error("chat token rejected (HTTP " + who.status + ") — sign in again at https://www.reddit.com/chat in ego lite");
  await L("token rejected " + who.status);
  exiting = true;
  process.exit(3);
}
out.me = who.json && who.json.user_id || null;
if (!out.me) out.errors.push("whoami: signed-in user unknown (" + (whoErr ? "request failed: " + whoErr : "HTTP " + who.status) + "); awaiting-reply decision skipped");
await L("whoami " + out.me);

// BEGIN pure
const formatBody = (c) => {
  const kind = c.msgtype === "m.image" ? "image" : c.msgtype === "m.video" ? "video" : c.msgtype === "m.file" ? "file" : "text";
  return { kind, body: kind === "text" ? String(c.body || "") : "[" + kind + (c.url ? " " + c.url : "") + (c.body ? " " + c.body : "") + "]" };
};
const isEdit = (ev) => !!(ev && ev.content && ev.content["m.relates_to"] && ev.content["m.relates_to"].rel_type === "m.replace");
const classifyRoom = (events, me, sinceMs) => {
  const msgs = (events || []).filter((ev) => ev && ev.type === "m.room.message").reverse().sort((a, b) => a.origin_server_ts - b.origin_server_ts);
  const originals = msgs.filter((ev) => !isEdit(ev));
  const newest = originals.length ? originals[originals.length - 1] : null;
  return { newest, fresh: msgs.filter((ev) => ev.origin_server_ts > sinceMs), awaiting: !!me && !!newest && newest.sender !== me };
};
const processRoom = async (get, roomId, ctx, out) => {
  const room = { roomId, with: [], group: false, newest: null, messages: [] };
  let bad = false;
  let cls = null;
  try {
    const enc = encodeURIComponent(roomId);
    const mem = await get("/rooms/" + enc + "/members");
    if (mem.status !== 200) { bad = true; out.errors.push("room " + roomId + ": members HTTP " + mem.status); }
    else if (!mem.json || !Array.isArray(mem.json.chunk)) { bad = true; out.errors.push("room " + roomId + ": members reply had no chunk (HTTP 200, unreadable body)"); }
    let others = 0;
    for (const ev of (mem.status === 200 && mem.json && Array.isArray(mem.json.chunk) && mem.json.chunk) || []) {
      if (ev.state_key && ev.state_key !== out.me) {
        const n = ev.content && ev.content.displayname;
        if (!ev.content || !ev.content.membership || ev.content.membership === "join") others++;
        room.with.push(await ctx.nameOf(ev.state_key, n));
      }
    }
    room.group = others > 1;
    const seen = [];
    let from = null, fetched = 0, stop = false, haveOriginal = false, more = false;
    while (!stop && fetched < ctx.limit) {
      const q = "/rooms/" + enc + "/messages?dir=b&limit=50" + (from ? "&from=" + encodeURIComponent(from) : "");
      const m = await get(q);
      if (m.status !== 200) { bad = true; out.errors.push("room " + roomId + ": messages HTTP " + m.status); break; }
      if (!m.json || !Array.isArray(m.json.chunk)) { bad = true; out.errors.push("room " + roomId + ": messages reply had no chunk (HTTP 200, unreadable body)"); break; }
      const chunk = m.json.chunk;
      if (!chunk.length) { more = false; break; }
      let atBoundary = false;
      for (const ev of chunk) {
        fetched++;
        if (ev.type !== "m.room.message") continue;
        seen.push(ev);
        if (!isEdit(ev)) haveOriginal = true;
        if (ev.origin_server_ts <= ctx.sinceMs) atBoundary = true;
      }
      if (atBoundary && haveOriginal) stop = true;
      from = m.json && m.json.end;
      more = !!from;
      if (!from) break;
    }
    if (!haveOriginal && fetched >= ctx.limit) { bad = true; out.errors.push("room " + roomId + ": limit reached before an original message (" + ctx.limit + " events read)"); }
    else if (ctx.sinceMs > 0 && !stop && more && fetched >= ctx.limit && !bad) { bad = true; out.errors.push("room " + roomId + ": limit reached before the watermark; " + seen.length + " messages listed, older new messages not read"); }
    cls = classifyRoom(seen, out.me, ctx.sinceMs);
    for (const ev of cls.fresh) {
      const f = formatBody(ev.content || {});
      room.messages.push({ ts: new Date(ev.origin_server_ts).toISOString(), sender: await ctx.nameOf(ev.sender), isMe: ev.sender === out.me, kind: f.kind, body: f.body });
    }
    if (cls.newest) {
      room.newest = { ts: new Date(cls.newest.origin_server_ts).toISOString(), sender: await ctx.nameOf(cls.newest.sender), isMe: cls.newest.sender === out.me };
      if (cls.awaiting) out.unanswered.push({ roomId, with: room.with, group: room.group, counterpart: room.newest.sender, ts: room.newest.ts, ageHours: Math.round(((ctx.nowMs || Date.now()) - cls.newest.origin_server_ts) / 360000) / 10, isMe: false, body: formatBody(cls.newest.content || {}).body });
    }
  } catch (e) {
    bad = true;
    out.errors.push("room " + roomId + ": " + (e && e.message || e));
  }
  if (bad) out.unreadable.push(roomId);
  out.chat.push(room);
  return room;
};
const readInvites = async (get, me, nowMs) => {
  const filter = { room: { timeline: { limit: 1 }, state: { types: [] }, ephemeral: { types: [] }, account_data: { types: [] } }, presence: { types: [] }, account_data: { types: [] } };
  const r = await get("/sync?timeout=0&set_presence=offline&filter=" + encodeURIComponent(JSON.stringify(filter)));
  if (r.status !== 200 || !r.json) return { ok: false, status: r.status, items: [] };
  const inv = (r.json.rooms && r.json.rooms.invite) || {};
  const items = [];
  for (const id of Object.keys(inv)) {
    const evs = (inv[id] && inv[id].invite_state && inv[id].invite_state.events) || [];
    const mine = evs.filter((e) => e && e.type === "m.room.member" && e.content && e.content.membership === "invite" && (!me || e.state_key === me));
    const stamped = mine.filter((e) => typeof e.origin_server_ts === "number");
    const ie = stamped.length ? stamped[stamped.length - 1] : (mine.length ? mine[mine.length - 1] : null);
    const sender = ie ? ie.sender : null;
    const sm = evs.find((e) => e && e.type === "m.room.member" && e.state_key === sender && e.content && e.content.displayname);
    const msgs = evs.filter((e) => e && e.type === "m.room.message");
    const t = ie && typeof ie.origin_server_ts === "number" ? ie.origin_server_ts : null;
    items.push({ roomId: id, inviter: sm ? sm.content.displayname : sender, ts: t === null ? null : new Date(t).toISOString(), ageHours: t === null ? null : Math.round(((nowMs || Date.now()) - t) / 360000) / 10, body: msgs.length ? formatBody(msgs[msgs.length - 1].content || {}).body : "" });
  }
  items.sort((a, b) => String(a.ts).localeCompare(String(b.ts)));
  return { ok: true, status: r.status, items };
};
const chatErrorsOf = (out) => out.errors.filter((e) => !(out.inboxErrors || []).includes(e));
const chatComplete = (out) => !!out.me && !out.roomListFailed && out.unreadable.length === 0 && out.pendingChecked && chatErrorsOf(out).length === 0;
const renderSummary = (out, ctx) => {
  const lines = [];
  const newestChat = out.chat.map((r) => r.newest && r.newest.ts).filter(Boolean).sort().pop() || null;
  const newestInbox = out.inbox.map((i) => i.ts).sort().pop() || null;
  lines.push("Reddit DM check — fetched " + out.fetchedAt + " as " + (ctx.meName || out.me || "unknown user") + (ctx.since ? " — events newer than " + ctx.since : " — full read"));
  const active = out.chat.filter((r) => r.messages.length);
  lines.push("Chat: " + out.chat.length + " rooms, " + active.length + " with new messages, newest event " + (newestChat || "n/a"));
  for (const r of active) {
    lines.push("");
    lines.push("## Chat with " + (r.with.join(", ") || "(unknown)") + (r.group ? " (group)" : "") + "  [" + r.roomId + "]");
    for (const m of r.messages) lines.push("- " + m.ts + "  " + m.sender + (m.isMe ? " (me)" : "") + ": " + m.body.replace(/\s+/g, " ").trim());
  }
  lines.push("");
  let hdr = "## Awaiting reply (newest message is from the other party, regardless of the watermark): " + out.unanswered.length + " of " + out.chat.length + " rooms";
  if (!out.me) hdr += " — NOT DECIDED: signed-in user unknown";
  else if (out.roomListFailed) hdr += " — INCOMPLETE: room list could not be read";
  else if (out.unreadable.length) hdr += " — INCOMPLETE: " + out.unreadable.length + " of " + out.chat.length + " rooms could not be read (" + out.unreadable.map((x) => x.slice(0, 8)).join(", ") + ")";
  lines.push(hdr);
  for (const u of out.unanswered) lines.push("- " + (u.with.join(", ") || u.counterpart) + (u.group ? " (group)" : "") + "  [" + u.roomId + "]  newest " + u.ts + " (" + u.ageHours + " h ago): " + u.body.replace(/\s+/g, " ").trim().slice(0, 200));
  lines.push("");
  if (!out.pendingChecked) lines.push("## Pending chat requests: NOT CHECKED (invite read failed; look at reddit.com/chat by eye)");
  else {
    lines.push("## Pending chat requests (invites, not joined or accepted): " + out.pending.length);
    for (const p of out.pending) lines.push("- " + (p.inviter || "unknown") + "  [" + p.roomId + "]  invited " + (p.ts || "n/a") + (p.ageHours === null ? "" : " (" + p.ageHours + " h ago)") + (p.body ? ": " + p.body.replace(/\s+/g, " ").trim().slice(0, 200) : ""));
  }
  lines.push("");
  lines.push("Inbox (PMs, comment replies, mentions): " + out.inbox.length + " new, newest " + (newestInbox || "n/a") + ((out.inboxErrors || []).length ? " — NOT READ" : ""));
  for (const i of out.inbox) lines.push("- " + i.ts + "  " + i.kind + " from u/" + i.author + (i.subreddit ? " in r/" + i.subreddit : "") + (i.subject ? " — " + i.subject : "") + (i.permalink ? " — " + i.permalink : "") + "\n  " + i.body.replace(/\s+/g, " ").trim().slice(0, 400));
  const chatErrs = chatErrorsOf(out);
  if (chatErrs.length) { lines.push(""); lines.push("Errors: " + chatErrs.join(" | ")); }
  if ((out.inboxErrors || []).length) { lines.push(""); lines.push("Inbox problem: " + out.inboxErrors.join(" | ")); }
  lines.push("");
  lines.push("Newest event overall: " + (out.newest || "n/a"));
  return lines.join("\n");
};
// END pure

const nameCache = {};
const displayName = async (uid, hint) => {
  if (hint) nameCache[uid] = hint;
  if (nameCache[uid]) return nameCache[uid];
  const p = await get("/profile/" + encodeURIComponent(uid) + "/displayname");
  nameCache[uid] = (p.json && p.json.displayname) || uid;
  return nameCache[uid];
};

let rooms;
try { rooms = await get("/joined_rooms"); } catch (e) { rooms = { status: 0, json: null, text: "", err: e && e.message || String(e) }; }
if (rooms.err) { out.roomListFailed = true; out.errors.push("joined_rooms: request failed: " + rooms.err); }
else if (rooms.status !== 200) { out.roomListFailed = true; out.errors.push("joined_rooms HTTP " + rooms.status); }
else if (!rooms.json || !Array.isArray(rooms.json.joined_rooms)) { out.roomListFailed = true; out.errors.push("joined_rooms: reply had no joined_rooms list (HTTP 200, unreadable body)"); }
const roomIds = (rooms.json && Array.isArray(rooms.json.joined_rooms) && rooms.json.joined_rooms) || [];
await L("rooms " + roomIds.length);

const rctx = { limit: CFG.limit, sinceMs, nameOf: displayName };
for (const roomId of roomIds) {
  const room = await processRoom(get, roomId, rctx, out);
  await L("room " + roomId.slice(0, 12) + " with=" + room.with.join(",") + " new=" + room.messages.length);
}

try {
  const inv = await readInvites(get, out.me, Date.now());
  if (inv.ok) { out.pendingChecked = true; out.pending = inv.items; }
  else out.errors.push("pending requests: /sync HTTP " + inv.status);
  await L("pending " + inv.items.length);
} catch (e) {
  out.errors.push("pending requests: " + (e && e.message || e));
}

// Legacy inbox: private messages (t4), comment replies and mentions (t1).
try {
  const inboxMs = CFG.inboxTimeoutMs || 30000;
  const inboxRead = page.evaluate("(async () => { const r = await fetch(\"/message/inbox.json?raw_json=1&limit=50\", {credentials: \"include\"}); return r.status + \"\\n\" + (await r.text()); })()");
  const txt = await new Promise((res, rej) => { const t = setTimeout(() => rej(new Error("inbox read timed out after " + inboxMs + " ms")), inboxMs); Promise.resolve(inboxRead).then((v) => { clearTimeout(t); res(v); }, (e) => { clearTimeout(t); rej(e); }); });
  const nl = txt.indexOf("\n");
  const status = txt.slice(0, nl);
  if (status !== "200") throw new Error("inbox.json HTTP " + status);
  const j = JSON.parse(txt.slice(nl + 1));
  for (const ch of (j.data && j.data.children) || []) {
    const d = ch.data || {};
    const ts = (d.created_utc || 0) * 1000;
    if (ts <= sinceMs) continue;
    out.inbox.push({
      ts: new Date(ts).toISOString(),
      kind: ch.kind === "t4" ? "pm" : (d.type === "username_mention" ? "mention" : "comment_reply"),
      author: d.author,
      subject: d.subject || d.link_title || null,
      subreddit: d.subreddit || null,
      permalink: d.context ? "https://www.reddit.com" + d.context : (d.id && ch.kind === "t4" ? "https://www.reddit.com/message/messages/" + d.id : null),
      unread: !!d.new,
      body: String(d.body || ""),
    });
  }
  out.inbox.sort((a, b) => a.ts.localeCompare(b.ts));
  await L("inbox new=" + out.inbox.length);
} catch (e) {
  const msg = "inbox: " + (e && e.message || e);
  out.errors.push(msg);
  out.inboxErrors.push(msg);
}

const newestChat = out.chat.map((r) => r.newest && r.newest.ts).filter(Boolean).sort().pop() || null;
const newestInbox = out.inbox.map((i) => i.ts).sort().pop() || null;
out.newest = [newestChat, newestInbox].filter(Boolean).sort().pop() || null;

out.chatComplete = chatComplete(out);
out.complete = out.errors.length === 0;
if (!CFG.summary) {
  console.log(JSON.stringify(out, null, 2));
} else {
  console.log(renderSummary(out, { since: CFG.since, meName: nameCache[out.me] || out.me }));
}
await L("done");
exiting = true;
process.exit(0);
} catch (e) {
  if (exiting) throw e;
  console.error("fetch-dms unexpected failure: " + (e && e.message || e));
  process.exit(4);
}
