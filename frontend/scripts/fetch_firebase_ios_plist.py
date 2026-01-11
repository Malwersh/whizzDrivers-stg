#!/usr/bin/env python3
"""Fetch GoogleService-Info.plist for an iOS app via Firebase Management API.

This is useful when you have a service account JSON but don't want to manually
copy the config from Firebase Console.

Usage:
  python3 scripts/fetch_firebase_ios_plist.py \
    --service-account /path/to/serviceAccount.json \
    --project-id wizz-business-app \
    --bundle-id com.wiz.wizdriverapp \
    --out ios/Runner/GoogleService-Info.plist
"""

from __future__ import annotations

import argparse
from pathlib import Path

import requests
from google.oauth2 import service_account
from google.auth.transport.requests import AuthorizedSession


SCOPE = "https://www.googleapis.com/auth/firebase"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--service-account", required=True, help="Path to Firebase service account JSON")
    parser.add_argument("--project-id", required=True, help="Firebase project id, e.g. wizz-business-app")
    parser.add_argument("--bundle-id", required=True, help="iOS bundle id, e.g. com.wiz.wizdriverapp")
    parser.add_argument("--out", default="ios/Runner/GoogleService-Info.plist", help="Output path")
    args = parser.parse_args()

    sa_path = Path(args.service_account)
    if not sa_path.exists():
        raise SystemExit(f"Missing service account file: {sa_path}")

    creds = service_account.Credentials.from_service_account_file(
        str(sa_path), scopes=[SCOPE]
    )
    session = AuthorizedSession(creds)

    # 1) List ios apps in the project
    list_url = f"https://firebase.googleapis.com/v1beta1/projects/{args.project_id}/iosApps"
    resp = session.get(list_url, timeout=30)
    if resp.status_code != 200:
        raise SystemExit(f"List iOS apps failed ({resp.status_code}): {resp.text[:500]}")

    data = resp.json()
    apps = data.get("apps", [])
    if not apps:
        raise SystemExit("No iOS apps found in this Firebase project.")

    match = None
    for app in apps:
        if app.get("bundleId") == args.bundle_id:
            match = app
            break

    if not match:
        available = [a.get("bundleId") for a in apps if a.get("bundleId")]
        raise SystemExit(
            "No matching iOS app found for bundle id. "
            f"Wanted: {args.bundle_id}. Available: {available}"
        )

    name = match.get("name")
    if not name:
        raise SystemExit("Matched app is missing resource name.")

    # 2) Download config
    config_url = f"https://firebase.googleapis.com/v1beta1/{name}/config"
    cfg = session.get(config_url, timeout=30)
    if cfg.status_code != 200:
        raise SystemExit(f"Get config failed ({cfg.status_code}): {cfg.text[:500]}")

    cfg_json = cfg.json()
    content = cfg_json.get("configFileContents")
    if not content:
        raise SystemExit("Config response did not include configFileContents")

    # configFileContents is base64
    import base64

    plist_bytes = base64.b64decode(content)

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_bytes(plist_bytes)

    # quick sanity: must look like plist
    if b"<plist" not in plist_bytes and b"bplist" not in plist_bytes[:10]:
        raise SystemExit("Downloaded config does not look like a plist")

    print(f"✅ Wrote GoogleService-Info.plist to: {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
