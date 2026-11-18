#!/usr/bin/env python3
"""Sign a THROWAWAY TEST ACCOUNT out of every device (auth device row D2).

Run by Christian in his own terminal; nothing here is run by an agent.

    python3 scripts/device/revoke-test-sessions.py

What it does, in order:
  1. reads the Nuvio server address and its public client key from
     NuvioMobile/local.properties (the same two values the app is built with);
  2. asks for the test account's email and password (the password is not echoed,
     not stored, not logged and not passed on a command line);
  3. signs in with them to get a short-lived token;
  4. calls the server's "log out everywhere" endpoint with that token, which ends
     every session of that account, including the one on the Apple TV;
  5. prints the two HTTP status codes and nothing else.

It talks to one host only: the Nuvio server from local.properties.
Never use it with the real account: it signs that account out on every device.
"""
import getpass
import json
import pathlib
import re
import sys
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[2]
PROPS = ROOT / "NuvioMobile" / "local.properties"


def read_props(path):
    values = {}
    for line in path.read_text().splitlines():
        match = re.match(r"\s*([A-Za-z0-9_]+)\s*=\s*(.*)\s*$", line)
        if match:
            values[match.group(1)] = match.group(2)
    return values


def post(url, key, body=None, bearer=None):
    headers = {"apikey": key, "Content-Type": "application/json"}
    if bearer:
        headers["Authorization"] = "Bearer " + bearer
    data = json.dumps(body).encode() if body is not None else b""
    request = urllib.request.Request(url, data=data, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as error:
        return error.code, error.read()


def main():
    if not PROPS.exists():
        sys.exit(f"missing {PROPS}")
    props = read_props(PROPS)
    base = (props.get("SUPABASE_URL") or props.get("NUVIO_SUPABASE_URL") or "").rstrip("/")
    key = props.get("SUPABASE_ANON_KEY") or props.get("NUVIO_SUPABASE_ANON_KEY") or ""
    if not base.startswith("https://") or not key:
        sys.exit("local.properties has no https server address or client key")

    print("This signs ONE account out of EVERY device it is signed in on.")
    print("Use it only for the throwaway test account, never your real one.")
    if input("Type TEST to continue: ").strip() != "TEST":
        sys.exit("stopped: nothing was sent")

    email = input("Test account email: ").strip()
    password = getpass.getpass("Test account password (not shown): ")
    if not email or not password:
        sys.exit("stopped: nothing was sent")

    status, payload = post(
        base + "/auth/v1/token?grant_type=password", key, {"email": email, "password": password}
    )
    password = None
    if status != 200:
        sys.exit(f"sign-in failed: HTTP {status} (nothing was signed out)")
    try:
        token = json.loads(payload)["access_token"]
    except (ValueError, KeyError):
        sys.exit("sign-in answered without a token (nothing was signed out)")
    print(f"sign-in: HTTP {status}")

    status, _ = post(base + "/auth/v1/logout?scope=global", key, bearer=token)
    token = None
    print(f"log out everywhere: HTTP {status}")
    if status in (200, 204):
        print("Done: every session of that account is ended. Tell Claude it is done.")
    else:
        sys.exit("the server did not confirm the sign-out; tell Claude the status code")


if __name__ == "__main__":
    main()
