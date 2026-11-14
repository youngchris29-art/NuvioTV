// Plain-node tests for the pure block of fetch-dms.mjs.  Run: node --test scripts/reddit/fetch-dms.test.mjs
// The block between "// BEGIN pure" and "// END pure" is read straight out of fetch-dms.mjs
// (the file ego-browser consumes flattened), so the tested code cannot drift from the shipped code.
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const src = readFileSync(fileURLToPath(new URL("./fetch-dms.mjs", import.meta.url)), "utf8");
const m = src.match(/^\/\/ BEGIN pure\n([\s\S]*?)^\/\/ END pure$/m);
assert.ok(m, "pure block markers missing in fetch-dms.mjs");
const { classifyRoom, formatBody, processRoom, readInvites, renderSummary, chatComplete } = new Function(m[1] + "; return { classifyRoom, formatBody, processRoom, readInvites, renderSummary, chatComplete };")();

const ME = "@me:reddit.com", THEM = "@them:reddit.com";
const msg = (sender, iso, body, extra) => ({ type: "m.room.message", sender, origin_server_ts: Date.parse(iso), content: Object.assign({ msgtype: "m.text", body }, extra || {}) });
const edit = (sender, iso, body) => msg(sender, iso, "* " + body, { "m.relates_to": { rel_type: "m.replace", event_id: "$orig" } });

// Fake Matrix getter. pages: array of chunks (newest-first), each linked by an `end` token.
// opts: membersStatus, messagesStatus (for page index >= failFrom), members (array of ids).
const fakeGet = (pages, opts) => {
  const o = opts || {};
  const calls = [];
  const get = async (p) => {
    calls.push(p);
    if (p.includes("/members")) {
      if (o.membersStatus && o.membersStatus !== 200) return { status: o.membersStatus, json: null, text: "" };
      if (o.membersNoChunk) return { status: 200, json: null, text: "<html>" };
      const ids = o.members || [ME, THEM];
      return { status: 200, json: { chunk: ids.map((id) => ({ state_key: id, content: { membership: "join", displayname: id.slice(1, 5) } })) }, text: "" };
    }
    const fm = p.match(/[?&]from=([^&]+)/);
    const idx = fm ? Number(decodeURIComponent(fm[1]).replace("t", "")) : 0;
    if (o.messagesStatus && idx >= (o.failFrom || 0)) return { status: o.messagesStatus, json: null, text: "" };
    if (o.messagesNoChunk) return { status: 200, json: { note: "no chunk here" }, text: "" };
    const chunk = pages[idx] || [];
    return { status: 200, json: { chunk, end: idx + 1 < pages.length ? "t" + (idx + 1) : undefined }, text: "" };
  };
  get.calls = calls;
  return get;
};
const newOut = (me) => ({ fetchedAt: "2026-11-13T00:00:00.000Z", since: null, me, chat: [], unanswered: [], pending: [], pendingChecked: true, unreadable: [], roomListFailed: false, complete: false, chatComplete: false, inbox: [], errors: [], inboxErrors: [] });
const nameOf = async (uid, hint) => hint || uid.slice(1, 5);
const run = async (pages, since, o) => {
  const out = newOut((o && "me" in o) ? o.me : ME);
  const get = fakeGet(pages, o);
  const room = await processRoom(get, "!room:reddit.com", { limit: (o && o.limit) || 200, sinceMs: since ? Date.parse(since) : 0, nameOf, nowMs: Date.parse("2026-11-13T12:00:00Z") }, out);
  return { out, room, get };
};

test("12 Nov case via the loop: only message from the other party, older than since -> awaiting, not in new", async () => {
  const { out, room } = await run([[msg(THEM, "2026-11-12T13:23:22Z", "hi, quick question")]], "2026-11-12T13:42:00Z");
  assert.equal(out.unanswered.length, 1);
  assert.equal(out.unanswered[0].body, "hi, quick question");
  assert.equal(room.messages.length, 0);
  assert.equal(out.errors.length, 0);
});

test("paging stops at --since on the second page and does not read a third", async () => {
  const p0 = [msg(THEM, "2026-11-12T15:00:00Z", "c"), msg(ME, "2026-11-12T14:00:00Z", "b")];
  const p1 = [msg(THEM, "2026-11-12T13:00:00Z", "a"), msg(ME, "2026-11-12T09:00:00Z", "older")];
  const p2 = [msg(THEM, "2026-11-01T09:00:00Z", "ancient")];
  const { room, get } = await run([p0, p1, p2], "2026-11-12T12:00:00Z");
  assert.deepEqual(room.messages.map((x) => x.body), ["a", "b", "c"]);
  assert.equal(get.calls.filter((c) => c.includes("/messages")).length, 2);
});

test("--limit cuts the read: second page is never requested", async () => {
  const p0 = [msg(THEM, "2026-11-12T15:00:00Z", "c"), msg(ME, "2026-11-12T14:00:00Z", "b")];
  const p1 = [msg(THEM, "2026-11-12T13:00:00Z", "a")];
  const { room, get } = await run([p0, p1], null, { limit: 2 });
  assert.equal(get.calls.filter((c) => c.includes("/messages")).length, 1);
  assert.deepEqual(room.messages.map((x) => x.body), ["b", "c"]);
});

test("owner edits an old reply after the other party's question: still awaiting", async () => {
  const evs = [edit(ME, "2026-11-12T12:00:00Z", "fixed typo"), msg(THEM, "2026-11-12T11:00:00Z", "question?"), msg(ME, "2026-11-12T10:00:00Z", "old reply")];
  const { out, room } = await run([evs], null);
  assert.equal(out.unanswered.length, 1);
  assert.equal(out.unanswered[0].body, "question?");
  assert.equal(room.messages.length, 3, "edits still appear in the new listing, as before");
});

test("other party edits an old message after the owner's reply: not awaiting", async () => {
  const evs = [edit(THEM, "2026-11-12T12:00:00Z", "typo"), msg(ME, "2026-11-12T11:00:00Z", "my reply"), msg(THEM, "2026-11-12T10:00:00Z", "question")];
  const { out } = await run([evs], null);
  assert.equal(out.unanswered.length, 0);
});

test("429 on /messages: error recorded with room id and status, room unreadable, section marked incomplete", async () => {
  const { out, room } = await run([[msg(THEM, "2026-11-12T10:00:00Z", "q")]], null, { messagesStatus: 429 });
  assert.equal(out.unanswered.length, 0);
  assert.deepEqual(out.unreadable, ["!room:reddit.com"]);
  assert.match(out.errors[0], /!room:reddit\.com.*messages HTTP 429/);
  assert.equal(room.newest, null);
  const text = renderSummary(out, { since: null, meName: "me" });
  assert.match(text, /## Awaiting reply .*0 of 1 rooms — INCOMPLETE: 1 of 1 rooms could not be read/);
  assert.match(text, /Errors: .*HTTP 429/);
});

test("/messages answering 200 without a chunk is an error and the room is unreadable, not a clean read", async () => {
  const { out } = await run([[msg(THEM, "2026-11-12T10:00:00Z", "q")]], null, { messagesNoChunk: true });
  assert.deepEqual(out.unreadable, ["!room:reddit.com"]);
  assert.match(out.errors.join("|"), /messages reply had no chunk/);
  assert.equal(chatComplete(out), false);
});

test("/members answering 200 with a non-JSON body is an error and the room is unreadable", async () => {
  const { out } = await run([[msg(THEM, "2026-11-12T10:00:00Z", "q")]], null, { membersNoChunk: true });
  assert.deepEqual(out.unreadable, ["!room:reddit.com"]);
  assert.match(out.errors.join("|"), /members reply had no chunk/);
});

test("edit at the since-boundary on a first page of reactions does not end paging before an original is seen", async () => {
  const reaction = { type: "m.reaction", sender: THEM, origin_server_ts: Date.parse("2026-11-12T11:59:30Z"), content: {} };
  const p0 = [reaction, reaction, edit(ME, "2026-11-12T11:59:00Z", "typo fix")];
  const p1 = [msg(THEM, "2026-11-12T11:00:00Z", "the question")];
  const { out, get } = await run([p0, p1], "2026-11-12T12:00:00Z");
  assert.equal(get.calls.filter((c) => c.includes("/messages")).length, 2);
  assert.equal(out.unanswered.length, 1);
  assert.equal(out.unanswered[0].body, "the question");
});

test("paging still stops at the boundary once an original has been collected", async () => {
  const p0 = [msg(THEM, "2026-11-12T11:00:00Z", "old question"), edit(ME, "2026-11-12T10:00:00Z", "x")];
  const p1 = [msg(ME, "2026-11-01T11:00:00Z", "ancient")];
  const { get } = await run([p0, p1], "2026-11-12T12:00:00Z");
  assert.equal(get.calls.filter((c) => c.includes("/messages")).length, 1);
});

test("failure on page 2 keeps page-1 decision but marks the room unreadable", async () => {
  const p0 = [msg(THEM, "2026-11-12T15:00:00Z", "q")];
  const p1 = [msg(ME, "2026-11-12T14:00:00Z", "x")];
  const { out } = await run([p0, p1], null, { messagesStatus: 500, failFrom: 1 });
  assert.equal(out.unanswered.length, 1);
  assert.equal(out.unreadable.length, 1);
});

test("members call failing (403) is recorded and the room counted unreadable", async () => {
  const { out } = await run([[msg(THEM, "2026-11-12T10:00:00Z", "q")]], null, { membersStatus: 403 });
  assert.match(out.errors[0], /members HTTP 403/);
  assert.equal(out.unreadable.length, 1);
});

test("unknown signed-in user: nothing flagged, summary says not decided", async () => {
  const { out } = await run([[msg(THEM, "2026-11-12T10:00:00Z", "q")]], null, { me: null });
  assert.equal(out.unanswered.length, 0);
  const text = renderSummary(out, { since: null, meName: null });
  assert.match(text, /NOT DECIDED: signed-in user unknown/);
});

test("same-millisecond messages: new listing keeps the old order (chunk order reversed) and newest is the chunk-first one", async () => {
  const t = "2026-11-12T10:00:00Z";
  const evs = [msg(THEM, t, "first-in-chunk"), msg(ME, t, "second-in-chunk"), msg(THEM, t, "third-in-chunk")];
  const { room } = await run([evs], null);
  assert.deepEqual(room.messages.map((x) => x.body), ["third-in-chunk", "second-in-chunk", "first-in-chunk"]);
  assert.equal(classifyRoom(evs, ME, 0).newest.content.body, "first-in-chunk");
});

test("group room is flagged", async () => {
  const { out } = await run([[msg(THEM, "2026-11-12T10:00:00Z", "q")]], null, { members: [ME, THEM, "@third:reddit.com"] });
  assert.equal(out.unanswered[0].group, true);
});

test("summary text carries the Awaiting section and the JSON carries unanswered", async () => {
  const { out } = await run([[msg(THEM, "2026-11-12T13:23:22Z", "hi, quick question")]], "2026-11-12T13:42:00Z");
  const text = renderSummary(out, { since: "2026-11-12T13:42:00Z", meName: "me" });
  assert.match(text, /## Awaiting reply .*: 1 of 1 rooms\n- them {2}\[!room:reddit\.com\] {2}newest 2026-11-12T13:23:22\.000Z \(22\.6 h ago\): hi, quick question/);
  assert.match(text, /## Pending chat requests \(invites, not joined or accepted\): 0/);
  const json = JSON.parse(JSON.stringify(out));
  assert.ok(Array.isArray(json.unanswered) && json.unanswered.length === 1);
  assert.ok(Array.isArray(json.pending));
});

test("readInvites lists invites with inviter, time and body, without joining; a failed sync is reported", async () => {
  const sync = { rooms: { invite: { "!inv:reddit.com": { invite_state: { events: [
    { type: "m.room.create", sender: THEM, state_key: "", content: {} },
    { type: "m.room.member", sender: THEM, state_key: THEM, content: { membership: "join", displayname: "Tester" } },
    { type: "m.room.member", sender: THEM, state_key: ME, content: { membership: "invite" }, origin_server_ts: Date.parse("2026-11-13T10:00:00Z") },
  ] } } } } };
  const paths = [];
  const ok = await readInvites(async (p) => { paths.push(p); return { status: 200, json: sync, text: "" }; }, ME, Date.parse("2026-11-13T12:00:00Z"));
  assert.equal(ok.ok, true);
  assert.deepEqual(ok.items.map((i) => [i.roomId, i.inviter, i.ts, i.ageHours, i.body]), [["!inv:reddit.com", "Tester", "2026-11-13T10:00:00.000Z", 2, ""]]);
  assert.ok(paths.every((p) => p.startsWith("/sync?timeout=0&set_presence=offline&filter=")), "only the read-only, presence-free sync is called");
  const bad = await readInvites(async () => ({ status: 429, json: null, text: "" }), ME, 0);
  assert.equal(bad.ok, false);
  assert.equal(bad.status, 429);
});

test("an invite without a timestamp is listed with null time and age and renders without a time", async () => {
  const sync = { rooms: { invite: { "!old:reddit.com": { invite_state: { events: [
    { type: "m.room.member", sender: THEM, state_key: THEM, content: { membership: "join", displayname: "Tester" } },
    { type: "m.room.member", sender: THEM, state_key: ME, content: { membership: "invite" } },
  ] } } } } };
  const r = await readInvites(async () => ({ status: 200, json: sync, text: "" }), ME, Date.parse("2026-11-13T12:00:00Z"));
  assert.deepEqual(r.items.map((i) => [i.roomId, i.inviter, i.ts, i.ageHours]), [["!old:reddit.com", "Tester", null, null]]);
  const out = newOut(ME);
  out.pending = r.items;
  assert.match(renderSummary(out, { since: null, meName: "me" }), /- Tester {2}\[!old:reddit\.com\] {2}invited n\/a\n/);
});

test("pending section renders NOT CHECKED when the invite read failed; room-list failure renders its header", () => {
  const out = newOut(ME);
  out.pendingChecked = false;
  out.roomListFailed = true;
  const text = renderSummary(out, { since: null, meName: "me" });
  assert.match(text, /## Pending chat requests: NOT CHECKED/);
  assert.match(text, /## Awaiting reply .*— INCOMPLETE: room list could not be read/);
  assert.equal(chatComplete(out), false);
});

test("an inbox error is not a chat error: chatComplete stays true and the summary uses a separate Inbox problem line", () => {
  const out = newOut(ME);
  out.errors.push("inbox: inbox.json HTTP 500");
  out.inboxErrors.push("inbox: inbox.json HTTP 500");
  assert.equal(chatComplete(out), true);
  const text = renderSummary(out, { since: null, meName: "me" });
  assert.match(text, /Inbox problem: inbox: inbox\.json HTTP 500/);
  assert.doesNotMatch(text, /^Errors:/m);
});

test("formatBody labels media", () => {
  assert.equal(formatBody({ msgtype: "m.image", url: "mxc://x", body: "a.png" }).body, "[image mxc://x a.png]");
  assert.equal(formatBody({ msgtype: "m.text", body: "hey" }).kind, "text");
});

test("classifyRoom basics: ending on my message, ordering independence, non-message events", () => {
  assert.equal(classifyRoom([msg(THEM, "2026-11-12T10:00:00Z", "q"), msg(ME, "2026-11-12T11:00:00Z", "a")], ME, 0).awaiting, false);
  const ev = [msg(ME, "2026-11-12T10:00:00Z", "a"), msg(THEM, "2026-11-12T11:00:00Z", "thanks")];
  assert.equal(classifyRoom(ev, ME, 0).awaiting, true);
  assert.equal(classifyRoom(ev.slice().reverse(), ME, 0).awaiting, true);
  assert.equal(classifyRoom([{ type: "m.room.member", sender: THEM, origin_server_ts: 5 }], ME, 0).awaiting, false);
  assert.equal(classifyRoom(undefined, ME, 0).newest, null);
});

// Runs the flattened shipped file (like fetch-dms.sh: whole-line // comments dropped, lines joined by spaces) against a fake runtime.
const SECRET = "tok-SECRET-9f3a1c";
const runFlat = async (o) => {
  const flat = src.split("\n").filter((l) => !/^[ \t]*\/\//.test(l)).join(" ");
  assert.ok(!flat.includes("\n"));
  const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
  const fn = new AsyncFunction("CFG", "taskSpace", "process", "fetch", "console", "AbortSignal", flat);
  const stdout = [], stderr = [], requests = [];
  const reply = (status, body) => ({ status, text: async () => JSON.stringify(body) });
  const fakeFetch = async (url, opts) => {
    const u = String(url);
    requests.push({ url: u, method: (opts && opts.method) || "GET", auth: opts && opts.headers && opts.headers.Authorization });
    const h = o.handlers && o.handlers(u);
    if (h) return typeof h === "function" ? h() : h;
    if (u.includes("whoami")) return reply(200, { user_id: ME });
    if (u.includes("/joined_rooms")) return reply(200, { joined_rooms: ["!r:reddit.com"] });
    if (u.includes("/members")) return reply(200, { chunk: [{ state_key: ME, content: { membership: "join" } }, { state_key: THEM, content: { membership: "join", displayname: "Them" } }] });
    if (u.includes("/messages")) return reply(200, { chunk: [msg(THEM, "2026-11-12T13:23:22Z", "hello")], end: undefined });
    if (u.includes("/sync")) return reply(200, { rooms: { invite: {} } });
    return reply(404, {});
  };
  const page = {
    goto: async () => {},
    evaluate: async (code) => (String(code).includes("localStorage") ? JSON.stringify({ token: SECRET }) : (o.inboxHangs && String(code).includes("inbox.json") ? new Promise(() => {}) : (o.inbox || "200\n{\"data\":{\"children\":[]}}"))),
  };
  let newPageCalls = 0;
  const stalePage = { goto: async () => { throw new Error("target closed"); }, evaluate: async () => { throw new Error("target closed"); } };
  const taskSpace = async () => ({
    pages: async () => { if (o.pagesThrows) throw new Error("pages() failed"); return o.stalePage ? [stalePage] : (o.existingPages ? o.existingPages.map(() => page) : []); },
    newPage: async () => { newPageCalls++; return o.newPageIsStale ? stalePage : page; },
  });
  const realSetTimeout = globalThis.setTimeout;
  globalThis.setTimeout = (f) => realSetTimeout(f, 0);
  let exitCode = null;
  let logCalls = 0;
  const con = { log: (x) => { logCalls++; if (o.logThrows && logCalls === 1) throw new Error("boom in log"); stdout.push(String(x)); }, error: (x) => stderr.push(String(x)) };
  try {
    await fn({ space: 1, since: o.since === undefined ? "2026-11-12T13:42:00Z" : o.since, limit: 200, summary: o.summary !== false, log: null }, taskSpace, { exit: (c) => { exitCode = c; throw new Error("exit " + c); } }, fakeFetch, con, AbortSignal);
  } catch (e) {
    if (!/^exit \d$/.test(e.message)) throw e;
  } finally {
    globalThis.setTimeout = realSetTimeout;
  }
  return { stdout: stdout.join("\n"), stderr: stderr.join("\n"), requests, exitCode, reply, newPageCalls: () => newPageCalls };
};

test("shipped file stays flatten-safe: the flattened code runs read-only, sends only GETs, and never writes, joins or leaves", async () => {
  const r = await runFlat({});
  assert.equal(r.exitCode, 0);
  assert.match(r.stdout, /## Awaiting reply .*: 1 of 1 rooms/);
  assert.match(r.stdout, /## Pending chat requests .*: 0/);
  assert.match(r.stdout, /^Newest event overall: /m);
  assert.doesNotMatch(r.stdout, /next watermark/);
  assert.ok(r.requests.length >= 4);
  assert.ok(r.requests.every((q) => q.method === "GET"), "every request is a GET");
  for (const bad of ["/join", "/invite", "/receipt", "/read_markers", "/leave"]) {
    const seg = new RegExp(bad + "(?![A-Za-z_])");
    assert.ok(r.requests.every((q) => !seg.test(q.url)), "no URL has a " + bad + " path segment (/joined_rooms and /joined_members are reads)");
  }
  assert.ok(r.requests.every((q) => q.url.startsWith("https://matrix.redditspace.com/")), "only the chat backend is called");
  assert.ok(r.requests.some((q) => q.url.includes("/sync") && q.url.includes("set_presence=offline")), "sync writes no presence");
});

test("the chat token is sent as a Bearer header but appears nowhere in stdout, stderr or the JSON", async () => {
  for (const summary of [true, false]) {
    const r = await runFlat({ summary });
    assert.ok(r.requests.every((q) => q.auth === "Bearer " + SECRET), "token is really used for the calls");
    assert.ok(!r.stdout.includes(SECRET), "not in stdout (summary=" + summary + ")");
    assert.ok(!r.stderr.includes(SECRET), "not in stderr");
    if (!summary) assert.ok(!JSON.stringify(JSON.parse(r.stdout)).includes(SECRET), "not in the JSON");
  }
  const failing = await runFlat({ handlers: (u) => (u.includes("/messages") ? { status: 429, text: async () => "denied" } : null) });
  assert.ok(!failing.stdout.includes(SECRET) && !failing.stderr.includes(SECRET));
});

test("whoami throwing (timeout or network) is a recorded failure: summary prints, user unknown, awaiting NOT DECIDED, exit untouched", async () => {
  const r = await runFlat({ handlers: (u) => (u.includes("whoami") ? () => { throw new Error("The operation was aborted due to timeout"); } : null) });
  assert.equal(r.exitCode, 0);
  assert.match(r.stdout, /## Awaiting reply .*NOT DECIDED: signed-in user unknown/);
  assert.match(r.stdout, /Errors: whoami: signed-in user unknown \(request failed: The operation was aborted due to timeout\)/);
  assert.match(r.stdout, /## Pending chat requests/);
});

test("/joined_rooms throwing is a recorded failure: roomListFailed, INCOMPLETE header, summary still printed", async () => {
  const r = await runFlat({ handlers: (u) => (u.includes("/joined_rooms") ? () => { throw new Error("fetch failed"); } : null) });
  assert.equal(r.exitCode, 0);
  assert.match(r.stdout, /## Awaiting reply .*0 of 0 rooms — INCOMPLETE: room list could not be read/);
  assert.match(r.stdout, /Errors: joined_rooms: request failed: fetch failed/);
  const j = await runFlat({ summary: false, handlers: (u) => (u.includes("/joined_rooms") ? () => { throw new Error("fetch failed"); } : null) });
  const out = JSON.parse(j.stdout);
  assert.equal(out.roomListFailed, true);
  assert.equal(out.chatComplete, false);
  assert.equal(out.complete, false);
});

test("/joined_rooms answering 200 with a non-JSON body marks the room list failed", async () => {
  const r = await runFlat({ handlers: (u) => (u.includes("/joined_rooms") ? { status: 200, text: async () => "<html>maintenance</html>" } : null) });
  assert.match(r.stdout, /INCOMPLETE: room list could not be read/);
  assert.match(r.stdout, /Errors: joined_rooms: reply had no joined_rooms list/);
});

test("JSON mode carries complete and chatComplete; an inbox error leaves chatComplete true and complete false", async () => {
  const ok = JSON.parse((await runFlat({ summary: false })).stdout);
  assert.equal(ok.complete, true);
  assert.equal(ok.chatComplete, true);
  const bad = await runFlat({ summary: false, inbox: "500\n{}" });
  const out = JSON.parse(bad.stdout);
  assert.equal(out.complete, false);
  assert.equal(out.chatComplete, true);
  assert.equal(out.inboxErrors.length, 1);
  assert.match(out.errors.join("|"), /inbox: inbox\.json HTTP 500/);
  const s = await runFlat({ inbox: "500\n{}" });
  assert.match(s.stdout, /Inbox problem: inbox: inbox\.json HTTP 500/);
  assert.doesNotMatch(s.stdout, /^Errors:/m);
  assert.match(s.stdout, /## Awaiting reply .*: 1 of 1 rooms\n/);
});

test("any other unexpected throw prints one line on stderr and exits 4; the expired-token case still exits 3", async () => {
  const r = await runFlat({ logThrows: true });
  assert.equal(r.exitCode, 4);
  assert.match(r.stderr, /^fetch-dms unexpected failure: boom in log$/);
  const expired = await runFlat({ handlers: (u) => (u.includes("whoami") ? { status: 401, text: async () => "{}" } : null) });
  assert.equal(expired.exitCode, 3);
  assert.match(expired.stderr, /chat token rejected \(HTTP 401\)/);
});

test("page reuse: an existing page in the space is used and newPage is never called; with none, newPage is called once", async () => {
  const reuse = await runFlat({ existingPages: ["p1", "p2"] });
  assert.equal(reuse.exitCode, 0);
  assert.equal(reuse.newPageCalls(), 0);
  assert.match(reuse.stdout, /## Awaiting reply/);
  const fresh = await runFlat({});
  assert.equal(fresh.newPageCalls(), 1);
});

test("--limit reached before any original message: the room is an error, unreadable, and the run is incomplete", async () => {
  const reactions = Array.from({ length: 3 }, (_, i) => ({ type: "m.room.message", sender: THEM, origin_server_ts: Date.parse("2026-11-12T10:0" + i + ":00Z"), content: { msgtype: "m.text", body: "* e", "m.relates_to": { rel_type: "m.replace", event_id: "$o" } } }));
  const { out } = await run([reactions, [msg(THEM, "2026-11-12T09:00:00Z", "the question")]], null, { limit: 3 });
  assert.deepEqual(out.unreadable, ["!room:reddit.com"]);
  assert.match(out.errors.join("|"), /limit reached before an original message/);
  assert.equal(chatComplete(out), false);
  assert.match(renderSummary(out, { since: null, meName: "me" }), /INCOMPLETE: 1 of 1 rooms could not be read/);
  const ok = await run([[msg(THEM, "2026-11-12T10:00:00Z", "q"), msg(ME, "2026-11-12T09:00:00Z", "a")]], null, { limit: 2 });
  assert.equal(ok.out.unreadable.length, 0, "a limit that still reached an original is not an error");
});

test("an unparseable --since is rejected before anything is opened (exit 4 guard; the wrapper exits 2 first)", async () => {
  const r = await runFlat({ since: "not-a-date" });
  assert.equal(r.exitCode, 4);
  assert.match(r.stderr, /--since is not a parseable timestamp: not-a-date/);
  assert.equal(r.requests.length, 0);
  assert.equal(r.newPageCalls(), 0);
});

test("a failed inbox read marks the Inbox header NOT READ and keeps the Inbox problem line; a clean read has no marker", async () => {
  const bad = await runFlat({ inbox: "500\n{}" });
  assert.match(bad.stdout, /^Inbox \(PMs, comment replies, mentions\): 0 new, newest n\/a — NOT READ$/m);
  assert.match(bad.stdout, /Inbox problem: inbox: inbox\.json HTTP 500/);
  const good = await runFlat({});
  assert.doesNotMatch(good.stdout, /NOT READ/);
});

test("a hung inbox read times out into an inbox error; the chat read that finished stays complete", async () => {
  const r = await runFlat({ summary: false, inboxHangs: true });
  assert.equal(r.exitCode, 0);
  const out = JSON.parse(r.stdout);
  assert.equal(out.chatComplete, true);
  assert.equal(out.complete, false);
  assert.equal(out.inboxErrors.length, 1);
  assert.match(out.inboxErrors[0], /inbox read timed out/);
  assert.equal(out.chat.length, 1, "the chat result is still printed");
  const sm = await runFlat({ inboxHangs: true });
  assert.equal(sm.exitCode, 0, "explicit exit 0 so the pending inbox read cannot hold the process");
  assert.match(sm.stdout, /## Awaiting reply/);
  assert.match(sm.stdout, /Inbox problem: inbox: inbox read timed out/);
  assert.match(sm.stdout, /^Newest event overall: /m);
});

test("limit reached before the watermark with more history: room unreadable, run incomplete; the three non-cases are not flagged", async () => {
  const p0 = [msg(THEM, "2026-11-12T15:00:00Z", "c"), msg(ME, "2026-11-12T14:00:00Z", "b")];
  const p1 = [msg(THEM, "2026-11-12T13:00:00Z", "a")];
  const cut = await run([p0, p1], "2026-11-12T12:00:00Z", { limit: 2 });
  assert.deepEqual(cut.out.unreadable, ["!room:reddit.com"]);
  assert.match(cut.out.errors.join("|"), /limit reached before the watermark; 2 messages listed, older new messages not read/);
  assert.equal(chatComplete(cut.out), false);
  const few = await run([[msg(THEM, "2026-11-12T15:00:00Z", "c")]], "2026-11-12T12:00:00Z", { limit: 5 });
  assert.equal(few.out.unreadable.length, 0, "fewer events than the limit");
  const start = await run([p0.concat([msg(ME, "2026-11-12T13:30:00Z", "x")])], "2026-11-12T12:00:00Z", { limit: 3 });
  assert.equal(start.out.unreadable.length, 0, "room read to its start");
  const atBoundary = await run([[msg(THEM, "2026-11-12T15:00:00Z", "c"), msg(ME, "2026-11-12T11:00:00Z", "old")], [msg(ME, "2026-11-01T11:00:00Z", "ancient")]], "2026-11-12T12:00:00Z", { limit: 2 });
  assert.equal(atBoundary.out.unreadable.length, 0, "boundary reached");
  const noSince = await run([p0, p1], null, { limit: 2 });
  assert.equal(noSince.out.unreadable.length, 0, "no --since");
});

test("a stale reused page falls back to one new page; a second failure exits 4; pages() throwing exits 4", async () => {
  const r = await runFlat({ stalePage: true });
  assert.equal(r.exitCode, 0);
  assert.equal(r.newPageCalls(), 1);
  assert.match(r.stdout, /## Awaiting reply/);
  const twice = await runFlat({ stalePage: true, newPageIsStale: true });
  assert.equal(twice.exitCode, 4);
  assert.equal(twice.newPageCalls(), 1, "retried once only");
  assert.match(twice.stderr, /^ego-browser failure: target closed$/);
  const th = await runFlat({ pagesThrows: true });
  assert.equal(th.exitCode, 4);
  assert.match(th.stderr, /pages\(\) failed/);
});

// The wrapper's validation line, taken from the .sh itself (one source of truth).
const sh = readFileSync(fileURLToPath(new URL("./fetch-dms.sh", import.meta.url)), "utf8");
const valLine = sh.split("\n").find((l) => l.includes("--since is not a parseable timestamp"));
const validate = (since, env) => spawnSync("/bin/bash", ["-c", 'SINCE="$1"; ' + valLine + "; echo PASSED", "bash", since], { encoding: "utf8", env: Object.assign({}, process.env, env || {}) });

test("wrapper --since validation: garbage exits 2, empty and ISO pass, a value starting with -- is data, no node on PATH skips the check", () => {
  assert.ok(valLine, "validation line found in fetch-dms.sh");
  const bad = validate("not-a-date");
  assert.equal(bad.status, 2);
  assert.match(bad.stderr, /not a parseable timestamp/);
  assert.equal(validate("").status, 0);
  assert.match(validate("").stdout, /PASSED/);
  assert.match(validate("2026-11-13T09:00:00Z").stdout, /PASSED/);
  const opt = validate("--eval=process.exit(0)");
  assert.equal(opt.status, 2, "rejected as a bad timestamp, never run as a node option");
  const opt2 = validate("--version");
  assert.equal(opt2.status, 2);
  const nonode = validate("not-a-date", { PATH: "/nonexistent" });
  assert.equal(nonode.status, 0, "no node: the check is skipped");
  assert.match(nonode.stdout, /PASSED/);
});
