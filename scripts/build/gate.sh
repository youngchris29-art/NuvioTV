#!/bin/bash
# NuvioTV gate runner: one command for the whole gate, one table for its result.
#
#   scripts/build/gate.sh --repo <clone or submodule> --sim <udid> --out <log dir> [options]
#
# Steps, in order (each one runs under scripts/build/with-lock.sh and logs to its own file in --out):
#   kotlin     ./gradlew :shared:jvmTest :shared:tvosSimulatorArm64Test :composeApp:iosSimulatorArm64Test
#              (counts come from the XML reports, not the console)
#   debug      Debug simulator build   (scheme NuvioTV, iosApp/build/DerivedData)
#   release    Release simulator build (same)
#   unit       xcodebuild test -scheme NuvioTVTests   (iosApp/build/DerivedDataUITests)
#   ui-build   xcodebuild build-for-testing -scheme NuvioTVUITests, ONCE
#   ui:<id>    xcodebuild test-without-building -only-testing:NuvioTVUITests/<id>, one per manifest entry
#
# What a leg needs (TEST_RUNNER_ variables, fixture files, timeouts) and what is known about it
# (expected skips, known-flaky, known-baseline-failure) lives in gate-manifest.json beside this
# script; its "_doc" block explains the format. The script owns no test knowledge.
#
# Options
#   --repo <path>        the NuvioMobile checkout to gate (a clone or the submodule)
#   --sim <udid>         simulator to run on: your own clone (scripts/device/sim.sh clone <project>).
#                        The FA87 fixture is refused unless --final is given.
#   --final              final gate on the FA87 fixture simulator. --sim defaults to FA87. The simulator
#                        steps (unit, UI legs) run while this script holds the simulator lock through
#                        scripts/build/with-sim-lock.sh (the simulator lock wraps the build lock, never
#                        the reverse); the Kotlin gate and the two builds do not hold it.
#   --out <dir>          logs, pid file, fixtures, result bundles, results.json and summary.md
#   --only <list>        comma list of UI entries: manifest ids, a class, or Class/test
#                        (default: every manifest entry). A Class/test of a manifest class inherits
#                        that class's environment and known cases.
#   --skip-kotlin        leave the Kotlin gate out
#   --skip-builds        leave the Debug and Release simulator builds out
#   --skip-unit          leave NuvioTVTests out
#   --skip-ui            leave the UI legs out
#   --from <step>        resume: kotlin | debug | release | unit | ui-build | ui | ui:<id> | <id>.
#                        Earlier steps keep their rows from <out>/results.json when it exists.
#                        "--from ui" and "--from ui:<id>" reuse the build-for-testing products
#                        already in iosApp/build/DerivedDataUITests.
#   --ui-mode <mode>     build-once (default: build-for-testing once, then test-without-building per
#                        entry) or per-class (xcodebuild test per entry, the pre-2026-11-17 way)
#   --fixtures <dir>     extra directory searched first for fixture media
#   --manifest <file>    another manifest (default: gate-manifest.json beside this script)
#   --min-free-gb <n>    stop before a step when free disk is below n GB (default 6)
#   --lock-wait <sec>    give up when one step waits longer than this for the build lock
#                        (default 0 = wait for ever, like with-lock.sh)
#   --keep-results       keep the .xcresult bundle of passing runs too (default: only failing runs)
#   --leave-booted       do not shut the simulator down at the end even though this run booted it
#   --dry-run            print the plan and the exact commands; start nothing, write nothing
#
# Results
#   <out>/summary.md     the table (step, result, run / failed / skipped, wall, note), then baseline
#                        failures, flaky reruns, UNEXPECTED skips and expected skips. Also printed.
#   result words         PASS; BASELINE (only known-baseline failures); FLAKY (a known-flaky test
#                        failed, then passed its rerun); FAIL; ERROR (no result: timeout, crash, build
#                        failure, no test ran); SKIPS (nothing failed but a test skipped that the
#                        manifest does not expect to skip).
#   exit code            0 every step that ran is PASS, BASELINE or FLAKY and no skip was unexpected
#                        1 a FAIL, ERROR or unexpected skip
#                        2 usage, a refused simulator, a missing fixture file
#                        3 stopped for low disk      4 build lock not free within --lock-wait
#                        130 interrupted
#
# Safety
#   Every process this script starts (xcodebuild and gradle under with-lock.sh, the fixture server,
#   the simulator-lock holder) is its own process group, listed in <out>/gate.pids while alive, and
#   those groups are the only things it ever signals, on exit, on a timeout and on Ctrl-C. It boots
#   the simulator only when it is shut down and shuts it down only when it booted it; it never
#   erases one and refuses the "NuvioTV template". It deletes nothing outside --out. TEST_RUNNER_
#   variables already in the caller's environment are dropped so a leg sees only its manifest env.
#
# Examples
#   scripts/build/gate.sh --repo ~/Claude/Projects/NuvioMobile-foo --sim "$(scripts/device/sim.sh udid foo)" \
#       --out ~/Claude/Projects/NuvioMobile-foo/iosApp/build/gate-logs/w2
#   scripts/build/gate.sh --repo NuvioMobile --sim <udid> --out <dir> --skip-kotlin --skip-builds \
#       --only PostPlayUITests,PlayerTransportUITests/testExactStageCancelledByNewPress
#   scripts/build/gate.sh --repo ~/Claude/Projects/NuvioMobile-foo --final --out <dir>      # FA87, sim lock
#   scripts/build/gate.sh --repo NuvioMobile --sim <udid> --out <dir> --from ui:SyncLineUITests
#   scripts/build/gate.sh --repo NuvioMobile --sim <udid> --out <dir> --dry-run
#
# Run it with the Bash sandbox OFF (xcodebuild test exits 70 inside it) and, for a long gate, in
# the background. The body below is Python, in the house style of with-lock.sh.
#
# Measured 2026-11-17 (submodule at 704143149, own simulator clone, PostPlayUITests and
# AetherRouteUITests): test-without-building gives the same results as per-class `xcodebuild test`
# and costs 10-13 s outside the tests per entry against 20-26 s (35 s median over the 21 legs of
# the per-class gate of that morning). The larger cost of that 3.15 h gate was 74 minutes waiting
# for the build lock between legs; the summary's "Time:" line now shows that split.
GATE_HERE="$(cd "$(dirname "$0")" && pwd)"
export GATE_HERE
exec python3 - "$@" <<'PY'
import argparse, datetime, glob, json, os, re, shlex, shutil, signal, socket, subprocess, sys, time
import urllib.request
import xml.etree.ElementTree as ET

HERE = os.environ["GATE_HERE"]
SELF = os.path.join(HERE, "gate.sh")
OUTER = os.path.dirname(os.path.dirname(HERE))
WITH_LOCK = os.path.join(HERE, "with-lock.sh")
WITH_SIM_LOCK = os.path.join(HERE, "with-sim-lock.sh")
LOCK_SH = os.path.join(OUTER, "scripts", "device", "lock.sh")
FIXTURE_SIM = os.environ.get("NUVIO_FIXTURE_SIM", "FA87E9B6-F28D-4DF9-84E4-A5A4C5DBFC4E")
TEMPLATE_NAME = "NuvioTV template"
PROJECT = "iosApp/iosApp.xcodeproj"
DD_APP = "iosApp/build/DerivedData"
DD_TESTS = "iosApp/build/DerivedDataUITests"
UI_TARGET = "NuvioTVUITests"
DEFAULT_UI_MODE = "build-once"
OK_WORDS = ("PASS", "BASELINE", "FLAKY")

EXIT_FAIL, EXIT_USAGE, EXIT_DISK, EXIT_LOCK, EXIT_INT = 1, 2, 3, 4, 130


class Stop(Exception):
    """Ends the run early with an exit code; the summary is still written."""
    def __init__(self, code, why):
        super().__init__(why)
        self.code, self.why = code, why


class Interrupted(Exception):
    pass


def usage_text():
    out = []
    with open(SELF, encoding="utf-8") as f:
        next(f)
        for line in f:
            if not line.startswith("#"):
                break
            out.append(line[2:].rstrip("\n") if line.startswith("# ") else line[1:].rstrip("\n"))
    return "\n".join(out)


def die(msg, code=EXIT_USAGE):
    print("gate.sh: " + msg, file=sys.stderr)
    sys.exit(code)


def hms(seconds):
    seconds = int(round(seconds))
    if seconds < 60:
        return "%ds" % seconds
    if seconds < 3600:
        return "%dm%02ds" % (seconds // 60, seconds % 60)
    return "%dh%02dm%02ds" % (seconds // 3600, (seconds % 3600) // 60, seconds % 60)


def quote_cmd(argv, env=None, cwd=None, log=None):
    parts = []
    if cwd:
        parts.append("cd " + shlex.quote(cwd) + " &&")
    if env:
        parts.append("env")
        parts += ["%s=%s" % (k, shlex.quote(v)) for k, v in env.items()]
    parts += [shlex.quote(a) for a in argv]
    if log:
        parts.append("> " + shlex.quote(log) + " 2>&1")
    return " ".join(parts)


# ---------------------------------------------------------------- arguments

def parse_args():
    if any(a in ("-h", "--help") for a in sys.argv[1:]):
        print(usage_text())
        sys.exit(0)
    p = argparse.ArgumentParser(prog="gate.sh", add_help=False)
    p.add_argument("--repo")
    p.add_argument("--sim")
    p.add_argument("--final", action="store_true")
    p.add_argument("--out")
    p.add_argument("--only")
    p.add_argument("--skip-kotlin", action="store_true")
    p.add_argument("--skip-builds", action="store_true")
    p.add_argument("--skip-unit", action="store_true")
    p.add_argument("--skip-ui", action="store_true")
    p.add_argument("--from", dest="from_step")
    p.add_argument("--ui-mode", choices=("build-once", "per-class"), default=DEFAULT_UI_MODE)
    p.add_argument("--fixtures")
    p.add_argument("--manifest", default=os.path.join(HERE, "gate-manifest.json"))
    p.add_argument("--min-free-gb", type=float, default=6.0)
    p.add_argument("--lock-wait", type=int, default=0)
    p.add_argument("--keep-results", action="store_true")
    p.add_argument("--leave-booted", action="store_true")
    p.add_argument("--dry-run", action="store_true")
    a = p.parse_args()
    if not a.repo:
        die("--repo <clone or submodule path> is required (--help for usage)")
    if not a.out:
        die("--out <log dir> is required")
    a.repo = os.path.abspath(os.path.expanduser(a.repo))
    a.out = os.path.abspath(os.path.expanduser(a.out))
    a.manifest = os.path.abspath(os.path.expanduser(a.manifest))
    if a.fixtures:
        a.fixtures = os.path.abspath(os.path.expanduser(a.fixtures))
    if not os.path.isdir(os.path.join(a.repo, PROJECT)) or not os.path.isfile(os.path.join(a.repo, "gradlew")):
        die("--repo %s is not a NuvioMobile checkout (no %s or gradlew)" % (a.repo, PROJECT))
    if a.final and not a.sim:
        a.sim = FIXTURE_SIM
    if not a.sim:
        die("--sim <udid> is required (scripts/device/sim.sh clone <project> prints one; --final uses FA87)")
    a.sim = a.sim.upper()
    if a.sim == FIXTURE_SIM.upper() and not a.final:
        die("SIM REFUSED: %s is the FA87 fixture simulator, for final gates only. "
            "Use your own clone (scripts/device/sim.sh clone <project>) or pass --final." % a.sim)
    if a.final and a.sim != FIXTURE_SIM.upper():
        die("--final is the gate on the FA87 fixture (%s); drop --final to run on %s" % (FIXTURE_SIM, a.sim))
    for tool in (WITH_LOCK, WITH_SIM_LOCK):
        if not os.access(tool, os.X_OK):
            die("missing or not executable: " + tool)
    return a


# ---------------------------------------------------------------- manifest

def load_manifest(path):
    try:
        with open(path, encoding="utf-8") as f:
            m = json.load(f)
    except (OSError, ValueError) as e:
        die("cannot read the manifest %s: %s" % (path, e))
    seen = set()
    for e in m.get("ui", []):
        if "id" not in e:
            die("manifest: a ui entry has no id")
        if e["id"] in seen:
            die("manifest: duplicate ui entry " + e["id"])
        seen.add(e["id"])
        checks = [(e["id"], e)] + [(e["id"] + "/" + t, v) for t, v in e.get("tests", {}).items()]
        for name, v in checks:
            st = v.get("status", "normal")
            if st not in ("normal", "known-flaky", "known-baseline-failure"):
                die("manifest: %s has unknown status %r" % (name, st))
            if st != "normal" and not (v.get("reason") and v.get("date")):
                die("manifest: %s is %s and needs a reason and a date" % (name, st))
    return m


def entry_class(entry_id):
    return entry_id.split("/")[0]


def full_name(entry_id, key):
    """Manifest test key -> Class/test. A key with a slash is already Class/test."""
    return key if "/" in key else entry_class(entry_id) + "/" + key


def normalised(entry):
    """Copy of a manifest entry with tests and expect_skip keyed Class/test."""
    e = dict(entry)
    e["env"] = dict(entry.get("env", {}))
    e["tests"] = dict((full_name(entry["id"], k), v) for k, v in entry.get("tests", {}).items())
    e["expect_skip"] = dict((full_name(entry["id"], k), v) for k, v in entry.get("expect_skip", {}).items())
    e["status"] = entry.get("status", "normal")
    return e


def select_ui(manifest, only, warn):
    entries = [normalised(e) for e in manifest.get("ui", [])]
    if not only:
        return entries
    by_id = dict((e["id"], e) for e in entries)
    picked = []
    for item in [x.strip() for x in only.split(",") if x.strip()]:
        if item.startswith(UI_TARGET + "/") and item not in by_id and item[len(UI_TARGET) + 1:] in by_id:
            item = item[len(UI_TARGET) + 1:]
        if item in by_id:
            picked.append(by_id[item])
            continue
        cls = entry_class(item)
        if "/" in item and cls in by_id:
            base = by_id[cls]
            e = dict(base)
            e["id"] = item
            e["tests"] = dict((k, v) for k, v in base["tests"].items() if k == item)
            e["expect_skip"] = dict((k, v) for k, v in base["expect_skip"].items() if k == item)
            picked.append(e)
            continue
        kin = [e for e in entries if e["id"].startswith(item + "/")]
        e = {"id": item, "env": {}, "tests": {}, "expect_skip": {}, "status": "normal"}
        for k in kin:
            e["env"].update(k["env"])
            e["tests"].update(k["tests"])
            e["expect_skip"].update(k["expect_skip"])
        if kin:
            warn("--only %s is not a manifest entry; running it whole with what the manifest knows about %d of its tests"
                 % (item, len(kin)))
        else:
            warn("--only %s is not in the manifest: no environment, no known cases" % item)
        picked.append(e)
    return picked


# ---------------------------------------------------------------- simulator

def sim_info(udid):
    try:
        raw = subprocess.run(["xcrun", "simctl", "list", "devices", "-j"], capture_output=True, text=True,
                             stdin=subprocess.DEVNULL, timeout=60).stdout
        for devs in json.loads(raw)["devices"].values():
            for d in devs:
                if d["udid"].upper() == udid.upper():
                    return d["name"], d["state"]
    except (OSError, ValueError, KeyError, subprocess.SubprocessError):
        pass
    return None, None


# ---------------------------------------------------------------- log parsing

CASE_RE = re.compile(r"Test Case '-\[[^.\s\]]+\.(\S+) ([^\]]+)\]' (passed|failed|skipped) \(([\d.]+) seconds\)")
SKIP_RE = re.compile(r": -\[[^.\s\]]+\.(\S+) ([^\]]+)\] : Test skipped(?: - (.*))?$")
FAIL_RE = re.compile(r": error: -\[[^.\s\]]+\.(\S+) ([^\]]+)\] : (.*)$")
EXEC_RE = re.compile(r"Executed (\d+) tests?, with (?:(\d+) tests? skipped and )?(\d+) failures?")
LOCK_WAIT_RE = re.compile(r"^\[with-lock\] waiting for", re.M)
LOCK_GOT_RE = re.compile(r"^\[with-lock\] acquired after (\d+) s", re.M)


def parse_xctest_log(path):
    """-> {Class/test: {"res", "sec", "why"}}, the last 'Executed' triple, the last error-ish lines."""
    tests, executed, tail = {}, None, []
    try:
        f = open(path, encoding="utf-8", errors="replace")
    except OSError:
        return tests, executed, tail
    reasons, failures = {}, {}
    with f:
        for line in f:
            line = line.rstrip("\n")
            m = CASE_RE.search(line)
            if m:
                name = m.group(1) + "/" + m.group(2)
                tests[name] = {"res": m.group(3), "sec": float(m.group(4))}
                continue
            m = SKIP_RE.search(line)
            if m:
                reasons[m.group(1) + "/" + m.group(2)] = (m.group(3) or "no reason given").strip()
                continue
            m = FAIL_RE.search(line)
            if m:
                failures.setdefault(m.group(1) + "/" + m.group(2), m.group(3).strip())
                continue
            m = EXEC_RE.search(line)
            if m:
                executed = (int(m.group(1)), int(m.group(2) or 0), int(m.group(3)))
                continue
            if ("error:" in line or line.startswith("Testing failed") or "** TEST FAILED **" in line
                    or "** BUILD FAILED **" in line or "** TEST EXECUTE FAILED **" in line
                    or "Restarting after unexpected exit" in line or line.startswith("xcodebuild: error")):
                tail.append(line.strip()[:240])
    for name, t in tests.items():
        if t["res"] == "skipped":
            t["why"] = reasons.get(name, "no reason given")
        elif t["res"] == "failed":
            t["why"] = failures.get(name, "see the log")
    return tests, executed, tail[-3:]


def kotlin_counts(repo, reports_dir, since):
    d = os.path.join(repo, reports_dir)
    total = failed = skipped = fresh = 0
    bad, skips = [], []
    files = sorted(glob.glob(os.path.join(d, "*.xml")))
    for x in files:
        try:
            root = ET.parse(x).getroot()
        except (ET.ParseError, OSError):
            bad.append(os.path.basename(x) + " (unreadable report)")
            failed += 1
            continue
        if os.path.getmtime(x) >= since:
            fresh += 1
        suites = [root] if root.tag == "testsuite" else list(root.iter("testsuite"))
        for s in suites:
            total += int(s.get("tests", 0))
            failed += int(s.get("failures", 0)) + int(s.get("errors", 0))
            skipped += int(s.get("skipped", 0))
            for c in s.iter("testcase"):
                label = "%s.%s" % (c.get("classname", "?"), c.get("name", "?"))
                if c.find("failure") is not None or c.find("error") is not None:
                    bad.append(label)
                elif c.find("skipped") is not None:
                    skips.append(label)
    return {"files": len(files), "fresh": fresh, "total": total, "failed": failed, "skipped": skipped,
            "bad": bad, "skips": skips}


# ---------------------------------------------------------------- the run

class Gate:
    def __init__(self, args):
        self.a = args
        self.dry = args.dry_run
        self.repo, self.out = args.repo, args.out
        self.dest = "platform=tvOS Simulator,id=" + args.sim
        self.live = []            # [Popen, role, command text]
        self.warnings = []
        self.results = {}         # step id -> result dict
        self.order = []           # step ids in plan order
        self.server_url = None
        self.sim_holder = None
        self.sim_ready = False
        self.sim_booted_by_us = False
        self.sim_name = None
        self.started = time.time()
        self.stop_note = None
        self.head = None
        self.prepared = False     # True once --out exists and the run has really begun
        self.base_env = dict((k, v) for k, v in os.environ.items() if not k.startswith("TEST_RUNNER_"))
        self.dropped_env = sorted(k for k in os.environ if k.startswith("TEST_RUNNER_"))

    # ---- output
    def say(self, msg):
        line = "[gate %s] %s" % (time.strftime("%H:%M:%S"), msg)
        print(line, flush=True)
        if not self.dry:
            with open(os.path.join(self.out, "gate.log"), "a", encoding="utf-8") as f:
                f.write(line + "\n")

    def warn(self, msg):
        self.warnings.append(msg)
        self.say("WARNING: " + msg)

    # ---- processes this script started
    def write_pids(self):
        if self.dry:
            return
        path = os.path.join(self.out, "gate.pids")
        with open(path + ".tmp", "w", encoding="utf-8") as f:
            f.write("# processes started by gate.sh pid %d; each is its own process group; "
                    "kill only these\n" % os.getpid())
            alive = [x for x in self.live if x[0].poll() is None]
            for proc, role, text in alive:
                f.write("%d\t%s\t%s\n" % (proc.pid, role, text[:300]))
            if not alive:
                f.write("# none alive at %s\n" % time.strftime("%Y-%m-%d %H:%M:%S"))
        os.replace(path + ".tmp", path)

    def spawn(self, role, argv, env=None, cwd=None, stdout=None, stderr=None):
        proc = subprocess.Popen(argv, cwd=cwd, env=env if env is not None else self.base_env,
                                stdin=subprocess.DEVNULL, stdout=stdout, stderr=stderr,
                                start_new_session=True)
        self.live.append([proc, role, " ".join(argv)])
        self.write_pids()
        return proc

    def reap(self, proc):
        self.live = [x for x in self.live if x[0] is not proc]
        self.write_pids()

    def kill(self, proc, grace=15):
        """Signals only the process group of a child this script started and has not reaped."""
        if proc.poll() is None:
            for sig, wait in ((signal.SIGTERM, grace), (signal.SIGKILL, 10)):
                try:
                    os.killpg(proc.pid, sig)
                except (ProcessLookupError, PermissionError):
                    break
                try:
                    proc.wait(timeout=wait)
                    break
                except subprocess.TimeoutExpired:
                    continue
        self.reap(proc)

    def kill_all(self, keep=None):
        for proc, role, _ in list(reversed(self.live)):
            if proc is keep:
                continue
            if proc.poll() is None:
                self.say("stopping %s (pid %d)" % (role, proc.pid))
            self.kill(proc)

    # ---- one locked, logged command
    def run_locked(self, step_id, argv, log_name, timeout_s, env_extra=None):
        """Runs argv under with-lock.sh in the repo. -> (rc, wall_s, lock_wait_s, timed_out)."""
        log_path = os.path.join(self.out, log_name)
        full = [WITH_LOCK] + argv
        if self.dry:
            print("  " + quote_cmd(full, env_extra, self.repo, log_path))
            return 0, 0.0, 0.0, False
        self.check_disk(step_id)
        env = dict(self.base_env)
        env.update(env_extra or {})
        logf = open(log_path, "w", encoding="utf-8")
        logf.write("# %s\n" % quote_cmd(full, env_extra, self.repo))
        logf.flush()
        t0 = time.time()
        proc = self.spawn(step_id, full, env=env, cwd=self.repo, stdout=logf, stderr=subprocess.STDOUT)
        logf.close()
        self.say("%s: started (pid %d, log %s)" % (step_id, proc.pid, log_name))
        waiting, run_start, lock_wait, beat, timed_out = None, t0, 0.0, t0, False
        try:
            while proc.poll() is None:
                time.sleep(1)
                now = time.time()
                if waiting is not False:
                    with open(log_path, encoding="utf-8", errors="replace") as f:
                        head = f.read(4096)
                    got = LOCK_GOT_RE.search(head)
                    if got:
                        waiting, run_start, lock_wait = False, now, now - t0
                        self.say("%s: build lock acquired after %s" % (step_id, hms(lock_wait)))
                    elif LOCK_WAIT_RE.search(head):
                        if waiting is None:
                            waiting = True
                            self.say("%s: waiting for the build lock (%s)" % (step_id, self.lock_holder()))
                        if self.a.lock_wait and now - t0 > self.a.lock_wait:
                            self.kill(proc)
                            raise Stop(EXIT_LOCK, "BUILD LOCK BUSY: %s waited %s (--lock-wait %d); resume with --from %s"
                                       % (step_id, hms(now - t0), self.a.lock_wait, step_id))
                    elif waiting is None and len(head) >= 4096:
                        waiting = False            # the log is past its head with no wait line: it never waited
                if waiting is not True and timeout_s and now - run_start > timeout_s:
                    timed_out = True
                    self.say("%s: over its %s limit, stopping it" % (step_id, hms(timeout_s)))
                    self.kill(proc)
                    break
                if now - beat >= 300:
                    beat = now
                    self.say("%s: %s (%s)" % (step_id, "still waiting for the build lock" if waiting
                                              else "still running", hms(now - t0)))
        finally:
            if proc.poll() is None:
                self.kill(proc)
        rc = proc.returncode
        self.reap(proc)
        wall = time.time() - run_start
        return rc, wall, lock_wait, timed_out

    def lock_holder(self):
        try:
            out = subprocess.run([LOCK_SH, "who", "build"], capture_output=True, text=True,
                                 stdin=subprocess.DEVNULL, timeout=10).stdout.strip()
            return out[:160] or "holder unknown"
        except (OSError, subprocess.SubprocessError):
            return "holder unknown"

    def check_disk(self, step_id):
        free = shutil.disk_usage(self.repo).free / 1e9
        if free < self.a.min_free_gb:
            raise Stop(EXIT_DISK, "LOW DISK: %.1f GB free before %s (limit %.1f GB); resume with --from %s"
                       % (free, step_id, self.a.min_free_gb, step_id))

    # ---- simulator (lock under --final, boot only when shut down)
    def ensure_sim(self):
        if self.sim_ready:
            return
        if self.dry:
            if self.a.final:
                print("  # simulator lock, held until the end of the run:")
                print("  " + quote_cmd(self.holder_argv()))
            print("  # only if the simulator is shut down (then shut down again at the end):")
            print("  xcrun simctl boot %s && xcrun simctl bootstatus %s -b" % (self.a.sim, self.a.sim))
            self.sim_ready = True
            return
        if self.a.final:
            self.say("taking the FA87 simulator lock through with-sim-lock.sh (waits while another session holds it)")
            errf = open(os.path.join(self.out, "sim-lock.log"), "w", encoding="utf-8")
            holder = self.spawn("sim-lock-holder", self.holder_argv(), stdout=subprocess.PIPE, stderr=errf)
            errf.close()
            self.sim_holder = holder
            line = holder.stdout.readline()
            if b"GATE_SIM_LOCK_HELD" not in line:
                raise Stop(EXIT_FAIL, "could not take the simulator lock (see sim-lock.log)")
            self.say("simulator lock held")
        name, state = sim_info(self.a.sim)
        if state == "Shutdown":
            self.say("booting %s (%s)" % (name, self.a.sim))
            r = subprocess.run(["xcrun", "simctl", "boot", self.a.sim], capture_output=True, text=True,
                               stdin=subprocess.DEVNULL)
            if r.returncode != 0:
                raise Stop(EXIT_FAIL, "simctl boot failed: " + (r.stderr.strip() or r.stdout.strip())[:200])
            self.sim_booted_by_us = True
            try:
                subprocess.run(["xcrun", "simctl", "bootstatus", self.a.sim, "-b"], capture_output=True,
                               stdin=subprocess.DEVNULL, timeout=300)
            except subprocess.TimeoutExpired:
                self.warn("the simulator did not report a finished boot within 5 minutes; going on")
        else:
            self.warn("simulator %s is already %s: not booted by this run, it will be left as it is" % (name, state))
        self.sim_ready = True

    def holder_argv(self):
        script = 'echo GATE_SIM_LOCK_HELD; while kill -0 "$1" 2>/dev/null; do sleep 2; done'
        return [WITH_SIM_LOCK, "/usr/bin/env", "GATE=gate.sh--final:" + os.path.basename(self.repo),
                "/bin/sh", "-c", script, "gate-sim-lock", str(os.getpid())]

    def release_sim(self):
        if self.sim_booted_by_us and not self.a.leave_booted:
            self.say("shutting down the simulator this run booted (%s)" % self.a.sim)
            subprocess.run(["xcrun", "simctl", "shutdown", self.a.sim], capture_output=True,
                           stdin=subprocess.DEVNULL)
            self.sim_booted_by_us = False
        if self.sim_holder is not None:
            self.kill(self.sim_holder, grace=5)
            self.sim_holder = None
            self.say("simulator lock released")

    # ---- fixtures
    def fixture_plan(self, entries):
        """-> ({file: source path or 'generate:<kind>'}, [missing lines]) for every {server}/file in use."""
        fs = self.manifest.get("fixture_server", {})
        dirs = [self.a.fixtures] if self.a.fixtures else []
        for d in fs.get("search", []):
            dirs.append(os.path.expanduser(d.replace("{repo}", self.repo).replace("{outer}", OUTER)))
        users = {}
        for e in entries:
            for v in e["env"].values():
                for fname in re.findall(r"\{server\}/([^\s?#]+)", v):
                    users.setdefault(fname, []).append(e["id"])
        plan, missing = {}, []
        for fname, ids in users.items():
            hit = next((os.path.join(d, fname) for d in dirs if os.path.isfile(os.path.join(d, fname))), None)
            if hit:
                plan[fname] = hit
            elif fname in fs.get("generated", {}):
                plan[fname] = "generate:" + fs["generated"][fname]
            else:
                missing.append("%s (needed by %s)" % (fname, ", ".join(ids)))
        return plan, missing, dirs

    def write_generated(self, kind, path):
        if kind != "sync-srt":
            raise Stop(EXIT_USAGE, "manifest: unknown fixture generator %r" % kind)

        def stamp(sec):
            return "%02d:%02d:%02d,000" % (sec // 3600, (sec % 3600) // 60, sec % 60)
        with open(path, "w", encoding="utf-8") as f:
            for i in range(1, 301):
                start = (i - 1) * 2
                f.write("%d\n%s --> %s\nSync cue %d\n\n" % (i, stamp(start), stamp(start + 1), i))

    def start_fixtures(self, entries):
        plan, missing, _ = self.fixture_plan(entries)
        if not plan:
            return
        fs = self.manifest["fixture_server"]
        script = os.path.join(OUTER, fs["script"])
        root = os.path.join(self.out, "fixtures")
        base_port = int(fs.get("port", 8766))
        if self.dry:
            print("  # fixture directory %s:" % root)
            for fname, src in sorted(plan.items()):
                print("  #   %s <- %s" % (fname, src))
            print("  " + quote_cmd([sys.executable, script, str(base_port), root],
                                   log=os.path.join(self.out, "fixture-server.log"))
                  + " &   # or the next free port")
            self.server_url = "http://127.0.0.1:%d" % base_port
            return
        os.makedirs(root, exist_ok=True)
        for fname, src in plan.items():
            dst = os.path.join(root, fname)
            if os.path.lexists(dst):
                os.remove(dst)
            if src.startswith("generate:"):
                self.write_generated(src.split(":", 1)[1], dst)
            else:
                os.symlink(src, dst)
        probe = sorted(plan)[0]
        for port in range(base_port, base_port + 30):
            with socket.socket() as s:
                s.settimeout(0.3)
                if s.connect_ex(("127.0.0.1", port)) == 0:
                    continue
            logf = open(os.path.join(self.out, "fixture-server.log"), "a", encoding="utf-8")
            proc = self.spawn("fixture-server", [sys.executable, script, str(port), root],
                              stdout=logf, stderr=subprocess.STDOUT)
            logf.close()
            url = "http://127.0.0.1:%d" % port
            for _ in range(50):
                if proc.poll() is not None:
                    break
                try:
                    req = urllib.request.Request(url + "/" + probe, method="HEAD")
                    with urllib.request.urlopen(req, timeout=1) as r:
                        if r.status == 200 and proc.poll() is None:
                            self.server_url = url
                            self.say("fixture server on %s serving %s (pid %d)"
                                     % (url, ", ".join(sorted(plan)), proc.pid))
                            if port != base_port:
                                self.say("port %d was taken by another process; using %d" % (base_port, port))
                            return
                except OSError:
                    time.sleep(0.1)
            self.kill(proc)
        raise Stop(EXIT_FAIL, "the fixture server did not start on ports %d-%d (see fixture-server.log)"
                   % (base_port, base_port + 29))

    def leg_env(self, entry):
        env = {}
        for k, v in entry["env"].items():
            env["TEST_RUNNER_" + k] = v.replace("{server}", self.server_url or "http://127.0.0.1:0")
        return env

    # ---- steps
    def record(self, step_id, label, result, run=None, failed=None, skipped=None, wall=None, note="", **more):
        r = {"id": step_id, "label": label, "result": result, "run": run, "failed": failed,
             "skipped": skipped, "wall_s": wall, "note": note, "ok": result in OK_WORDS,
             "ran": True, "lock_wait_s": 0, "rows": [], "baseline": [], "flaky": [], "unexpected_skips": [],
             "expected_skips": [], "failures": []}
        r.update(more)
        self.results[step_id] = r
        if not self.dry:
            self.save()
            self.say("%s: %s%s" % (step_id, result, (" - " + note) if note else ""))
        return r

    def not_run(self, step_id, label, why):
        self.results[step_id] = {"id": step_id, "label": label, "result": "-", "run": None, "failed": None,
                                 "skipped": None, "wall_s": None, "note": why, "ok": True, "ran": False,
                                 "rows": [], "baseline": [], "flaky": [], "unexpected_skips": [],
                                 "expected_skips": [], "failures": []}

    def step_kotlin(self, step):
        k = self.manifest.get("kotlin", {})
        tasks = k.get("tasks", [])
        t0 = time.time()
        rc, wall, lock_wait, timed_out = self.run_locked(
            "kotlin", ["./gradlew"] + [t["task"] for t in tasks], "kotlin.log", k.get("timeout_s", 5400))
        if self.dry:
            return
        notes, total, failed, skipped, bad, skips, stale = [], 0, 0, 0, [], [], []
        for t in tasks:
            c = kotlin_counts(self.repo, t["reports"], t0)
            total += c["total"]; failed += c["failed"]; skipped += c["skipped"]
            bad += ["%s %s" % (t["task"], b) for b in c["bad"]]
            skips += ["%s %s" % (t["task"], s) for s in c["skips"]]
            notes.append("%s %d" % (t["task"].split(":")[-1], c["total"]))
            if c["files"] == 0:
                stale.append(t["task"] + " has no XML reports")
            elif c["fresh"] == 0:
                stale.append(t["task"] + " up to date (reports from an earlier run)")
        note = " / ".join(notes)
        if stale:
            note += "; " + "; ".join(stale)
        if lock_wait:
            note += "; lock wait " + hms(lock_wait)
        allowed = int(k.get("expected_skipped", 0))
        unexpected = [{"test": s, "why": "skipped in the Kotlin report"} for s in skips] if skipped > allowed else []
        if timed_out:
            result, note = "ERROR", "timed out after %s; %s" % (hms(wall), note)
        elif rc != 0 and not bad:
            result, note = "ERROR", "gradle exit %d with no failed test in the reports (compile or task failure, see kotlin.log); %s" % (rc, note)
        elif rc != 0 or failed:
            result = "FAIL"
        elif any("no XML" in s for s in stale):
            result = "ERROR"
        elif unexpected:
            result = "SKIPS"
        else:
            result = "PASS"
        self.record("kotlin", step["label"], result, total, failed, skipped, wall, note,
                    failures=[{"test": b, "why": "see kotlin.log"} for b in bad[:40]],
                    unexpected_skips=unexpected, lock_wait_s=lock_wait)

    def step_build(self, step):
        cfg = step["cfg"]
        argv = ["xcodebuild", "-project", PROJECT, "-scheme", "NuvioTV", "-configuration", cfg,
                "-destination", self.dest, "-derivedDataPath", DD_APP]
        rc, wall, lock_wait, timed_out = self.run_locked(step["id"], argv, "build-%s.log" % cfg, 3600)
        if self.dry:
            return
        self.record_build(step, rc, wall, lock_wait, timed_out, "build-%s.log" % cfg)

    def step_ui_build(self, step):
        argv = ["xcodebuild", "build-for-testing", "-project", PROJECT, "-scheme", UI_TARGET,
                "-destination", self.dest, "-derivedDataPath", DD_TESTS]
        rc, wall, lock_wait, timed_out = self.run_locked("ui-build", argv, "ui-build.log", 3600)
        if self.dry:
            return
        self.record_build(step, rc, wall, lock_wait, timed_out, "ui-build.log")

    def record_build(self, step, rc, wall, lock_wait, timed_out, log_name):
        note = "lock wait " + hms(lock_wait) if lock_wait else ""
        if timed_out:
            result, note = "ERROR", "timed out after " + hms(wall)
        elif rc != 0:
            _, _, tail = parse_xctest_log(os.path.join(self.out, log_name))
            result, note = "FAIL", "xcodebuild exit %d: %s" % (rc, " | ".join(tail) or "see " + log_name)
        else:
            result = "PASS"
        self.record(step["id"], step["label"], result, None, None, None, wall, note, lock_wait_s=lock_wait)

    def xctest_argv(self, action, scheme, only, bundle):
        argv = ["xcodebuild", action, "-project", PROJECT, "-scheme", scheme]
        argv += ["-only-testing:%s/%s" % (scheme, o) for o in only]
        argv += ["-destination", self.dest, "-derivedDataPath", DD_TESTS,
                 "-collect-test-diagnostics", "never", "-resultBundlePath", bundle]
        return argv

    def run_xctest(self, step_id, action, scheme, only, log_stem, timeout_s, env):
        """One xcodebuild test run. -> dict with rc, wall, tests, executed, tail, timed_out, lock_wait."""
        bundle = os.path.join(self.out, "xcresult", log_stem + ".xcresult")
        if not self.dry:
            os.makedirs(os.path.dirname(bundle), exist_ok=True)
            if os.path.lexists(bundle):
                shutil.rmtree(bundle, ignore_errors=True)
        rc, wall, lock_wait, timed_out = self.run_locked(
            step_id, self.xctest_argv(action, scheme, only, bundle), log_stem + ".log", timeout_s, env)
        if self.dry:
            return None
        tests, executed, tail = parse_xctest_log(os.path.join(self.out, log_stem + ".log"))
        return {"rc": rc, "wall": wall, "lock_wait": lock_wait, "timed_out": timed_out, "tests": tests,
                "executed": executed, "tail": tail, "bundle": bundle, "log": log_stem + ".log"}

    def drop_bundle(self, run, keep):
        b = run["bundle"]
        inside = os.path.commonpath([os.path.realpath(b), os.path.realpath(self.out)]) == os.path.realpath(self.out)
        if not keep and not self.a.keep_results and inside and os.path.isdir(b):
            shutil.rmtree(b, ignore_errors=True)

    def step_xctest(self, step):
        """NuvioTVTests and every UI leg: run, classify against the manifest, rerun known-flaky failures once."""
        entry, scheme, step_id = step["entry"], step["scheme"], step["id"]
        stem = step["log"]
        timeout_s = entry.get("timeout_s", self.manifest.get("default_timeout_s", 2700))
        env = self.leg_env(entry) if step["kind"] == "ui" else {}
        only = [entry["id"]] if step["kind"] == "ui" else []
        action = "test" if step["kind"] == "unit" or self.a.ui_mode == "per-class" else "test-without-building"
        self.ensure_sim()
        if self.dry:
            self.run_xctest(step_id, action, scheme, only, stem, timeout_s, env)
            flaky = [t for t, v in entry["tests"].items() if v.get("status") == "known-flaky"]
            if entry.get("status") == "known-flaky":
                print("  # known-flaky entry: any failed test is rerun once on its own")
            elif flaky:
                print("  # rerun once, only if it fails (known-flaky): " + ", ".join(flaky))
            return
        run = self.run_xctest(step_id, action, scheme, only, stem, timeout_s, env)
        tests = run["tests"]

        def status_of(name):
            return entry["tests"].get(name, {}).get("status", entry.get("status", "normal"))

        def reason_of(name):
            v = entry["tests"].get(name) or entry
            return "%s (%s)" % (v.get("reason", "no reason recorded"), v.get("date", "undated"))

        failed = sorted(t for t, v in tests.items() if v["res"] == "failed")
        skipped = sorted(t for t, v in tests.items() if v["res"] == "skipped")
        passed = sorted(t for t, v in tests.items() if v["res"] == "passed")
        baseline = [t for t in failed if status_of(t) == "known-baseline-failure"]
        flaky = [t for t in failed if status_of(t) == "known-flaky"]
        hard = [t for t in failed if t not in baseline and t not in flaky]
        rows, flaky_report, rerun = [], [], None
        if flaky and not run["timed_out"]:
            self.say("%s: rerunning known-flaky %s once" % (step_id, ", ".join(flaky)))
            rerun = self.run_xctest(step_id + " rerun", action, scheme, flaky, stem + "-rerun", timeout_s, env)
            for t in flaky:
                second = rerun["tests"].get(t, {}).get("res", "did not run")
                flaky_report.append({"test": t, "first": "failed", "second": second, "why": reason_of(t),
                                     "first_error": tests[t].get("why", "")})
                if second != "passed":
                    hard.append(t)
            r2 = rerun["tests"]
            rows.append({"label": "rerun: " + ", ".join(t.split("/")[-1] for t in flaky),
                         "result": "PASS" if all(f["second"] == "passed" for f in flaky_report) else "FAIL",
                         "run": len(r2), "failed": sum(1 for v in r2.values() if v["res"] == "failed"),
                         "skipped": sum(1 for v in r2.values() if v["res"] == "skipped"),
                         "wall_s": rerun["wall"], "note": "log " + rerun["log"]})
            self.drop_bundle(rerun, keep=rows[-1]["result"] != "PASS")
        unexpected = [{"test": t, "why": tests[t].get("why", "")} for t in skipped if t not in entry["expect_skip"]]
        expected = [{"test": t, "why": entry["expect_skip"][t]} for t in skipped if t in entry["expect_skip"]]
        notes = []
        if run["timed_out"]:
            result = "ERROR"
            notes.append("timed out after %s (limit %s)" % (hms(run["wall"]), hms(timeout_s)))
        elif not tests:
            result = "ERROR"
            notes.append("no test ran (xcodebuild exit %d): %s" % (run["rc"], " | ".join(run["tail"]) or "see " + run["log"]))
        elif run["rc"] != 0 and not failed:
            result = "ERROR"
            notes.append("xcodebuild exit %d without a failed test: %s" % (run["rc"], " | ".join(run["tail"]) or "see " + run["log"]))
        elif hard:
            result = "FAIL"
            notes.append("failed: " + ", ".join(t.split("/")[-1] for t in hard))
        elif unexpected:
            result = "SKIPS"
        elif baseline:
            result = "BASELINE"
        elif flaky:
            result = "FLAKY"
        else:
            result = "PASS"
        if baseline:
            notes.append("baseline: " + ", ".join(t.split("/")[-1] for t in baseline))
        if flaky:
            notes.append("flaky, " + ", ".join("%s rerun %s" % (f["test"].split("/")[-1], f["second"]) for f in flaky_report))
        if unexpected:
            notes.append("%d UNEXPECTED skip%s" % (len(unexpected), "" if len(unexpected) == 1 else "s"))
        if expected:
            notes.append("%d expected skip%s" % (len(expected), "" if len(expected) == 1 else "s"))
        stale = [t for t in passed if status_of(t) == "known-baseline-failure"]
        if stale:
            notes.append("PASSED though listed as baseline (drop the manifest line?): "
                         + ", ".join(t.split("/")[-1] for t in stale))
        if any("Restarting after unexpected exit" in t for t in run["tail"]):
            notes.append("the test runner restarted after a crash or a hang (see " + run["log"] + ")")
        ex = run["executed"]
        if step["kind"] == "unit" and ex and ex[0] != len(tests):
            notes.append("xcodebuild reports %d executed, %d parsed" % (ex[0], len(tests)))
        if run["lock_wait"]:
            notes.append("lock wait " + hms(run["lock_wait"]))
        self.drop_bundle(run, keep=result not in OK_WORDS)
        self.record(step_id, step["label"], result, len(tests), len(failed), len(skipped), run["wall"],
                    "; ".join(notes), rows=rows,
                    lock_wait_s=run["lock_wait"] + (rerun["lock_wait"] if rerun else 0),
                    baseline=[{"test": t, "why": reason_of(t), "error": tests[t].get("why", "")} for t in baseline],
                    flaky=flaky_report, unexpected_skips=unexpected, expected_skips=expected,
                    failures=[{"test": t, "why": tests[t].get("why", "")} for t in hard if t in tests])

    # ---- plan
    def build_plan(self):
        a, plan = self.a, []
        plan.append({"id": "kotlin", "kind": "kotlin", "label": "Kotlin gate", "skip": "--skip-kotlin" if a.skip_kotlin else None})
        for cfg in ("Debug", "Release"):
            plan.append({"id": cfg.lower(), "kind": "build", "cfg": cfg, "label": cfg + " sim build",
                         "skip": "--skip-builds" if a.skip_builds else None})
        unit = dict(self.manifest.get("unit", {}))
        unit_entry = {"id": "", "env": {}, "status": "normal", "timeout_s": unit.get("timeout_s", 2700),
                      "tests": dict(unit.get("tests", {})), "expect_skip": dict(unit.get("expect_skip", {}))}
        scheme = unit.get("scheme", "NuvioTVTests")
        plan.append({"id": "unit", "kind": "unit", "label": scheme, "scheme": scheme, "entry": unit_entry,
                     "log": "unit", "skip": "--skip-unit" if a.skip_unit else None})
        ui_skip = "--skip-ui" if a.skip_ui else None
        if a.ui_mode == "build-once":
            plan.append({"id": "ui-build", "kind": "ui-build", "label": "UI build-for-testing",
                         "skip": ui_skip or (None if self.ui_entries else "no UI entry selected")})
        for e in self.ui_entries:
            plan.append({"id": "ui:" + e["id"], "kind": "ui", "label": e["id"], "scheme": UI_TARGET, "entry": e,
                         "log": "ui-" + e["id"].replace("/", "_"), "skip": ui_skip})
        return plan

    def resume_index(self, plan):
        f = self.a.from_step
        if not f:
            return 0
        ids = [s["id"] for s in plan]
        if f == "ui":
            hit = next((i for i, s in enumerate(plan) if s["kind"] == "ui"), None)
        elif f in ids:
            hit = ids.index(f)
        elif "ui:" + f in ids:
            hit = ids.index("ui:" + f)
        else:
            hit = None
        if hit is None:
            die("--from %s is not a step of this run; steps: %s" % (f, ", ".join(ids)))
        return hit

    # ---- results on disk
    def save(self):
        data = {"order": self.order, "results": self.results}
        tmp = os.path.join(self.out, "results.json.tmp")
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=1)
        os.replace(tmp, os.path.join(self.out, "results.json"))
        with open(os.path.join(self.out, "summary.md"), "w", encoding="utf-8") as f:
            f.write(self.summary(final=False))

    def load_previous(self):
        try:
            with open(os.path.join(self.out, "results.json"), encoding="utf-8") as f:
                return json.load(f).get("results", {})
        except (OSError, ValueError):
            return {}

    def git(self, *args):
        try:
            return subprocess.run(["git", "-C", self.repo] + list(args), capture_output=True, text=True,
                                  stdin=subprocess.DEVNULL, timeout=30).stdout.strip()
        except (OSError, subprocess.SubprocessError):
            return ""

    def verdict(self):
        rs = [self.results[i] for i in self.order if i in self.results]
        bad = [r for r in rs if not r["ok"]]
        unexpected = sum(len(r["unexpected_skips"]) for r in rs)
        pending = [i for i in self.order if i not in self.results]
        partial = ["%s: %s" % (r["label"], r["note"]) for r in rs if not r["ran"]]
        if self.a.only:
            partial.append("UI entries limited by --only")
        if bad or unexpected:
            words = [self.stop_note] if self.stop_note else []
            if bad:
                words.append("%d step%s not green (%s)" % (len(bad), "" if len(bad) == 1 else "s",
                                                           ", ".join(r["label"] for r in bad)))
            if unexpected:
                words.append("%d unexpected skip%s" % (unexpected, "" if unexpected == 1 else "s"))
            return False, "GATE: FAIL", "; ".join(words), partial, pending
        if self.stop_note:
            return False, "GATE: STOPPED", self.stop_note, partial, pending
        return True, "GATE: PASS", "every step that ran is green and no skip was unexpected", partial, pending

    def summary(self, final=True):
        def cell(v):
            return "-" if v is None else str(v)

        def clean(s):
            return str(s).replace("|", "/").replace("\n", " ")

        L = ["# Gate summary", ""]
        L.append("- Repo: `%s` at `%s`" % (self.repo, self.head or "?"))
        L.append("- Simulator: %s (`%s`)%s" % (self.sim_name or "?", self.a.sim, ", FINAL gate under the simulator lock" if self.a.final else ""))
        L.append("- UI mode: %s; manifest `%s`" % (self.a.ui_mode, self.a.manifest))
        L.append("- Started %s, %s" % (datetime.datetime.fromtimestamp(self.started).strftime("%Y-%m-%d %H:%M:%S"),
                                      "took " + hms(time.time() - self.started) if final else "still running"))
        L.append("- Logs: `%s`" % self.out)
        L += ["", "| step | result | run / failed / skipped | wall | note |", "|---|---|---|---|---|"]
        for i in self.order:
            r = self.results.get(i)
            if r is None:
                L.append("| %s | pending | - | - | |" % i.replace("ui:", ""))
                continue
            counts = "-" if r["run"] is None else "%s / %s / %s" % (cell(r["run"]), cell(r["failed"]), cell(r["skipped"]))
            wall = "-" if r["wall_s"] is None else hms(r["wall_s"])
            L.append("| %s | %s | %s | %s | %s |" % (clean(r["label"]), r["result"], counts, wall, clean(r["note"])))
            for row in r["rows"]:
                L.append("| ↳ %s | %s | %s / %s / %s | %s | %s |" % (
                    clean(row["label"]), row["result"], row["run"], row["failed"], row["skipped"],
                    hms(row["wall_s"]), clean(row["note"])))
        rs = [self.results[i] for i in self.order if i in self.results]
        in_steps = sum((r["wall_s"] or 0) + sum(x["wall_s"] for x in r["rows"]) for r in rs if r["ran"])
        in_wait = sum(r.get("lock_wait_s", 0) or 0 for r in rs if r["ran"])
        L += ["", "run = tests executed, skipped ones included (the XCTest and Gradle totals). "
              "wall = time holding the build lock; time spent waiting for it is in the note.",
              "", "Time: %s in the steps, %s waiting for the build lock." % (hms(in_steps), hms(in_wait))]

        def section(title, key, fmt, empty):
            items = [(r, x) for r in rs for x in r[key]]
            L.extend(["", "## " + title, ""])
            if not items:
                L.append(empty)
            for r, x in items:
                L.append("- " + clean(fmt(r, x)))

        section("Unexpected skips (these fail the gate)", "unexpected_skips",
                lambda r, x: "%s: `%s` skipped: %s" % (r["label"], x["test"], x["why"]), "None.")
        section("Failures", "failures", lambda r, x: "%s: `%s`: %s" % (r["label"], x["test"], x["why"]), "None.")
        section("Baseline failures (reported, do not fail the gate)", "baseline",
                lambda r, x: "`%s`: %s. This run: %s" % (x["test"], x["why"], x["error"]), "None.")
        section("Flaky reruns", "flaky",
                lambda r, x: "`%s`: first run %s, rerun %s. Known flaky: %s. First error: %s"
                % (x["test"], x["first"], x["second"], x["why"], x["first_error"]), "None.")
        section("Expected skips", "expected_skips", lambda r, x: "`%s`: %s" % (x["test"], x["why"]), "None.")
        if self.warnings:
            L += ["", "## Warnings", ""] + ["- " + clean(w) for w in self.warnings]
        ok, word, why, partial, pending = self.verdict()
        L += ["", "## Verdict", ""]
        if final:
            L.append("**%s** - %s." % (word, why))
        else:
            L.append("**GATE: RUNNING** - %d of %d steps recorded." % (len(self.order) - len(pending), len(self.order)))
        if pending and final:
            L.append("")
            L.append("Not reached: " + ", ".join(p.replace("ui:", "") for p in pending) + ".")
        if partial:
            L.append("")
            L.append("Partial gate, left out: " + "; ".join(partial) + ".")
        return "\n".join(L) + "\n"

    # ---- main
    def main(self):
        a = self.a
        self.manifest = load_manifest(a.manifest)
        pre = []
        self.ui_entries = [] if a.skip_ui else select_ui(self.manifest, a.only, pre.append)
        plan = self.build_plan()
        start = self.resume_index(plan)
        self.order = [s["id"] for s in plan]
        todo_ui = [s["entry"] for s in plan[start:] if s["kind"] == "ui" and not s["skip"]]
        fplan, missing, dirs = self.fixture_plan(todo_ui)
        if missing:
            die("FIXTURE MISSING, nothing was started:\n  " + "\n  ".join(missing)
                + "\n searched: " + ", ".join(dirs) + "\n (add the file to one of them or pass --fixtures <dir>)")
        self.sim_name, state = sim_info(a.sim)
        if self.sim_name is None:
            die("SIM REFUSED: no simulator with udid %s (scripts/device/sim.sh list)" % a.sim)
        if self.sim_name == TEMPLATE_NAME:
            die("SIM REFUSED: %s is the shut-down template; it is never booted. Clone it: scripts/device/sim.sh clone <project>" % a.sim)
        self.head = "%s%s" % (self.git("rev-parse", "--short=9", "HEAD") or "?",
                              " (%s)" % self.git("branch", "--show-current") if self.git("branch", "--show-current") else " (detached)")
        dirty = [l for l in self.git("status", "--porcelain", "--untracked-files=no").splitlines() if l.strip()]
        if self.dry:
            print("# gate.sh dry run: nothing is started and nothing is written")
            print("# repo %s at %s; simulator %s (%s, %s); UI mode %s" % (self.repo, self.head, self.sim_name, a.sim, state, a.ui_mode))
            print("# out %s; manifest %s" % (self.out, a.manifest))
        else:
            os.makedirs(self.out, exist_ok=True)
            self.prepared = True
            self.say("gate on %s at %s, simulator %s (%s, %s), UI mode %s"
                     % (self.repo, self.head, self.sim_name, a.sim, state, a.ui_mode))
        for w in pre:
            self.warn(w) if not self.dry else print("# WARNING: " + w)
        if dirty and not self.dry:
            self.warn("the tree has %d modified tracked file%s; the gate covers the working tree, not the commit"
                      % (len(dirty), "" if len(dirty) == 1 else "s"))
        if self.dropped_env and not self.dry:
            self.warn("dropped from the environment so legs see only their manifest env: " + ", ".join(self.dropped_env))
        previous = self.load_previous() if (start and not self.dry) else {}
        for s in plan[:start]:
            if s["id"] in previous:
                r = previous[s["id"]]
                if "(earlier run)" not in r.get("note", ""):
                    r["note"] = ("(earlier run) " + r.get("note", "")).strip()
                self.results[s["id"]] = r
            else:
                self.not_run(s["id"], s["label"], "not run (--from %s)" % a.from_step)
        server_started = False
        for s in plan[start:]:
            if s["skip"]:
                self.not_run(s["id"], s["label"], "left out (%s)" % s["skip"])
                if self.dry:
                    print("\n# step %s: left out (%s)" % (s["id"], s["skip"]))
                continue
            if self.dry:
                print("\n# step %s" % s["id"])
            if s["kind"] == "ui" and not server_started:
                server_started = True
                self.start_fixtures(todo_ui)
            if s["kind"] == "kotlin":
                self.step_kotlin(s)
            elif s["kind"] == "build":
                self.step_build(s)
            elif s["kind"] == "ui-build":
                self.step_ui_build(s)
                if not self.dry and not self.results["ui-build"]["ok"]:
                    self.stop_note = "the UI build failed, so no UI leg was run"
                    break
            else:
                self.step_xctest(s)

    def finish(self, code_override=None):
        if self.dry or not self.prepared:
            return code_override or 0
        for s in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
            signal.signal(s, signal.SIG_IGN)       # finish the cleanup without a second interruption
        self.kill_all(keep=self.sim_holder)        # the lock holder goes last, after the simulator is down
        try:
            self.release_sim()
        except Exception as e:                     # never let cleanup hide the result
            self.say("cleanup: %s" % e)
        end_head = self.git("rev-parse", "--short=9", "HEAD")
        if self.head and end_head and not self.head.startswith(end_head):
            self.warn("HEAD moved during the gate: started at %s, now %s" % (self.head, end_head))
        ok, word, why, partial, pending = self.verdict()
        text = self.summary(final=True)
        with open(os.path.join(self.out, "summary.md"), "w", encoding="utf-8") as f:
            f.write(text)
        with open(os.path.join(self.out, "results.json"), "w", encoding="utf-8") as f:
            json.dump({"order": self.order, "results": self.results}, f, indent=1)
        self.write_pids()
        print()
        print(text, flush=True)
        code = code_override if code_override is not None else (0 if ok else EXIT_FAIL)
        self.say("%s (exit %d); summary: %s" % (word, code, os.path.join(self.out, "summary.md")))
        return code


def on_signal(signum, frame):
    raise Interrupted(signal.Signals(signum).name)


def run():
    args = parse_args()
    gate = Gate(args)
    for s in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
        signal.signal(s, on_signal)
    code = None
    try:
        gate.main()
    except Stop as e:
        gate.stop_note = e.why
        code = e.code
        gate.say(e.why) if not gate.dry else print("gate.sh: " + e.why, file=sys.stderr)
    except Interrupted as e:
        gate.stop_note = "interrupted by %s" % e
        code = EXIT_INT
        if not gate.dry:
            gate.say("interrupted (%s): stopping what this run started" % e)
    finally:
        code = gate.finish(code)
    sys.exit(code)


run()
PY
