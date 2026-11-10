#!/usr/bin/env python3
"""Device proofs on the test phone, against a throwaway PocketBase.

    ANDROID_SERIAL=<test phone> tool/e2e_phone.py <command>

    up                     start the throwaway PocketBase on :8091, tunnel it over USB,
                           keep the phone awake while charging
    login                  launch the app, point it at the tunnel, sign in as the test
                           user, continue without syncing
    logout                 sign out and put the server address back (E2E_RESTORE_HOST)
    down                   remove the tunnel and stop PocketBase
    labels                 print what is on screen: bounds, then the label
    tap <label>            tap the element whose label is, or starts with, <label>
    wait <label> [secs]    wait until such an element is on screen
    type <text>            type into the focused field
    push <tag> <title> <text>
                           post a notification from the shell (debug builds read it as a
                           bank push; a tag starting "paypal" goes to the PayPal buffer)
    shot <file.png>        save a screenshot

Never point this at a phone with real data: `login` signs the app in to an empty
server and `logout` signs it out. ANDROID_SERIAL must be set, so the phone is
always chosen on purpose. Nothing here touches the stack on :8090.

Needs: adb, python3, a PocketBase 0.39.x binary (E2E_PB_BIN) and the server repo
beside this one (E2E_SERVER_DIR) for its migrations and hooks. Standard library only.
"""

import json
import os
import pathlib
import re
import signal
import subprocess
import sys
import time
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET

APP = "com.devilteo911.budgetti.budgetti"
PORT = 8091
EMAIL, PASSWORD = "qa@example.com", "qaqa123456"  # throwaway server only
CACHE = pathlib.Path.home() / ".cache" / "budgetti-e2e"
PB_BIN = pathlib.Path(os.environ.get("E2E_PB_BIN", CACHE / "bin" / "pocketbase"))
PB_DATA = CACHE / "pb_data"
PID_FILE = CACHE / "pocketbase.pid"
SERVER_DIR = pathlib.Path(
    os.environ.get("E2E_SERVER_DIR", pathlib.Path(__file__).resolve().parents[2] / "server")
)
RESTORE_HOST = os.environ.get("E2E_RESTORE_HOST", "192.168.0.0")
BASE = f"http://127.0.0.1:{PORT}"


def adb(*args, check=True):
    return subprocess.run(["adb", *args], check=check, capture_output=True, text=True).stdout


def nodes():
    """(label, class, (x1, y1, x2, y2)) for every element with a label or text."""
    # A screen that is still animating has no idle state to dump: nothing is on
    # it yet, and the callers poll.
    adb("shell", "rm", "-f", "/sdcard/e2e_ui.xml")
    adb("shell", "uiautomator", "dump", "/sdcard/e2e_ui.xml", check=False)
    try:
        root = ET.fromstring(adb("exec-out", "cat", "/sdcard/e2e_ui.xml", check=False))
    except ET.ParseError:
        return []
    out = []
    for n in root.iter("node"):
        label = n.get("content-desc") or n.get("text") or ""
        box = tuple(map(int, re.findall(r"\d+", n.get("bounds", ""))))
        if len(box) == 4 and (label or n.get("class", "").endswith("EditText")):
            out.append((label, n.get("class", ""), box))
    return out


def find(label):
    """An exact label wins over a prefix, so "Elimina" is the button, not the
    dialog title "Eliminare le transazioni?"."""
    found = nodes()
    first_line = lambda s: s.split("\n")[0]
    for match in (lambda s: first_line(s) == label, lambda s: s.startswith(label)):
        for text, _, box in found:
            if match(text):
                return box
    return None


def tap_box(box):
    adb("shell", "input", "tap", str((box[0] + box[2]) // 2), str((box[1] + box[3]) // 2))


def wait(label, seconds=15):
    deadline = time.time() + seconds
    while time.time() < deadline:
        box = find(label)
        if box:
            return box
        time.sleep(0.7)
    sys.exit(f'"{label}" did not appear within {seconds}s')


def tap(label, seconds=15):
    tap_box(wait(label, seconds))


def type_text(text):
    adb("shell", "input", "text", text.replace(" ", "%s"))


def fields():
    return [box for _, cls, box in nodes() if cls.endswith("EditText")]


def close_keyboard():
    # Back, not Escape: Escape also closes a bottom sheet.
    if "mInputShown=true" in adb("shell", "dumpsys", "input_method"):
        adb("shell", "input", "keyevent", "4")
        time.sleep(0.6)


def replace_field(box, text):
    tap_box(box)
    time.sleep(0.6)
    adb("shell", "input", "keyevent", "123")  # MOVE_END
    adb("shell", "input", "keyevent", *["67"] * 40)  # DEL
    type_text(text)


def set_server_host(host):
    """On the login screen: the address under the button opens host and port."""
    tap("http")
    wait("Server PocketBase")
    replace_field(fields()[0], host)
    close_keyboard()
    tap("Salva")
    wait(f"http://{host}")


def request(path, body=None, token=None):
    req = urllib.request.Request(
        BASE + path,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"content-type": "application/json", **({"Authorization": token} if token else {})},
    )
    with urllib.request.urlopen(req, timeout=5) as res:
        return json.load(res)


def healthy():
    try:
        return request("/api/health")["code"] == 200
    except (urllib.error.URLError, OSError):
        return False


def up():
    if not PB_BIN.exists():
        sys.exit(f"No PocketBase binary at {PB_BIN}: download 0.39.x there or set E2E_PB_BIN")
    if not (SERVER_DIR / "pb_migrations").is_dir():
        sys.exit(f"No pb_migrations in {SERVER_DIR}: set E2E_SERVER_DIR to the server repo")
    PB_DATA.mkdir(parents=True, exist_ok=True)
    # --automigrate=false, or the dashboard writes migration files into the server repo.
    common = ["--dir", str(PB_DATA), "--migrationsDir", str(SERVER_DIR / "pb_migrations"),
              "--automigrate=false"]
    if not healthy():
        subprocess.run([PB_BIN, "superuser", "upsert", EMAIL, PASSWORD, *common],
                       check=True, capture_output=True, cwd=CACHE)
        log = open(CACHE / "pocketbase.log", "w")
        proc = subprocess.Popen(
            [PB_BIN, "serve", "--http", f"127.0.0.1:{PORT}", *common,
             "--hooksDir", str(SERVER_DIR / "pb_hooks")],
            stdout=log, stderr=log, cwd=CACHE, start_new_session=True)
        PID_FILE.write_text(str(proc.pid))
        for _ in range(40):
            if healthy():
                break
            time.sleep(0.25)
        else:
            sys.exit(f"PocketBase did not come up, see {CACHE / 'pocketbase.log'}")
    token = request("/api/collections/_superusers/auth-with-password",
                    {"identity": EMAIL, "password": PASSWORD})["token"]
    try:  # public signup is closed: the test user is made with the superuser token
        request("/api/collections/users/records",
                {"email": EMAIL, "password": PASSWORD, "passwordConfirm": PASSWORD,
                 "verified": True}, token)
    except urllib.error.HTTPError as e:
        if e.code != 400:  # 400 = already there
            raise
    adb("reverse", f"tcp:{PORT}", f"tcp:{PORT}")
    adb("shell", "settings", "put", "global", "stay_on_while_plugged_in", "3")
    print(f"PocketBase on {BASE}, tunnelled to the phone; test user {EMAIL}")


def down():
    adb("reverse", "--remove", f"tcp:{PORT}", check=False)
    if PID_FILE.exists():
        try:
            os.kill(int(PID_FILE.read_text()), signal.SIGTERM)
        except (ProcessLookupError, ValueError):
            pass
        PID_FILE.unlink()
    print("tunnel removed, PocketBase stopped")


def login():
    if not healthy():
        sys.exit("PocketBase is not up: run `up` first")
    adb("shell", "am", "force-stop", APP)
    adb("shell", "monkey", "-p", APP, "-c", "android.intent.category.LAUNCHER", "1")
    wait("Accedi", 30)  # fails here, on purpose, when the app is already signed in
    set_server_host("127.0.0.1")
    replace_field(fields()[0], EMAIL)
    close_keyboard()
    replace_field(fields()[1], PASSWORD)
    close_keyboard()
    tap("Accedi")
    tap("Continua senza sincronizzare", 30)
    wait("Dashboard", 30)
    print("signed in, local data left as it was")


def logout():
    tap("Impostazioni")
    tap("Profilo")
    tap("Esci")
    wait("Accedi", 30)
    set_server_host(RESTORE_HOST)
    print(f"signed out, server address back to {RESTORE_HOST}")


def main():
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help"):
        sys.exit(__doc__)
    cmd, args = sys.argv[1], sys.argv[2:]
    if not os.environ.get("ANDROID_SERIAL"):
        sys.exit("Set ANDROID_SERIAL to the TEST phone (adb devices): never the one with real data")
    if cmd == "labels":
        for label, cls, box in nodes():
            print(box, repr(label) if label else f"<{cls.split('.')[-1]}>")
    elif cmd == "tap":
        tap(args[0])
    elif cmd == "wait":
        wait(args[0], float(args[1]) if len(args) > 1 else 15)
    elif cmd == "type":
        type_text(args[0])
    elif cmd == "push":
        tag, title, text = args
        quote = lambda s: "'" + s.replace("'", "'\\''") + "'"
        # One remote command, quoted whole: adb joins its arguments and the phone's
        # shell splits them again.
        adb("shell", f"cmd notification post -S bigtext -t {quote(title)} {quote(tag)} {quote(text)}")
    elif cmd == "shot":
        pathlib.Path(args[0]).write_bytes(
            subprocess.run(["adb", "exec-out", "screencap", "-p"], check=True,
                           capture_output=True).stdout)
    elif cmd in ("up", "down", "login", "logout"):
        globals()[cmd]()
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
