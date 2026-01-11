#!/usr/bin/env python3
import argparse
import plistlib
from pathlib import Path

REQUIRED_KEYS = [
    "GOOGLE_APP_ID",
    "BUNDLE_ID",
    "PROJECT_ID",
    "GCM_SENDER_ID",
    "API_KEY",
]


def load_plist(path: Path):
    data = path.read_bytes()

    # plistlib can load both XML and binary plists.
    # If the file is not a well-formed plist, this will throw.
    return plistlib.loads(data)


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate iOS GoogleService-Info.plist for Firebase")
    parser.add_argument(
        "--plist",
        default="ios/Runner/GoogleService-Info.plist",
        help="Path to GoogleService-Info.plist",
    )
    parser.add_argument(
        "--expected-bundle-id",
        default="com.whizz.driver",
        help="Expected iOS bundle identifier",
    )
    args = parser.parse_args()

    plist_path = Path(args.plist)
    if not plist_path.exists():
        print(f"❌ Missing: {plist_path}")
        return 2

    try:
        obj = load_plist(plist_path)
    except Exception as e:
        size = plist_path.stat().st_size
        head = plist_path.read_bytes()[:80]
        print(f"❌ Invalid plist: {plist_path} (size={size})")
        print(f"   Parse error: {e}")
        print(f"   First bytes: {head!r}")
        return 3

    if not isinstance(obj, dict):
        print(f"❌ Unexpected plist root (expected dict): {type(obj)}")
        return 4

    missing = [k for k in REQUIRED_KEYS if k not in obj or not str(obj.get(k, "")).strip()]
    if missing:
        print("❌ Missing required Firebase keys:")
        for k in missing:
            print(f"   - {k}")

    bundle_id = str(obj.get("BUNDLE_ID", ""))
    if bundle_id and bundle_id != args.expected_bundle_id:
        print("❌ BUNDLE_ID mismatch:")
        print(f"   plist BUNDLE_ID: {bundle_id}")
        print(f"   expected:        {args.expected_bundle_id}")

    if missing or (bundle_id and bundle_id != args.expected_bundle_id):
        print("\nFix: download the correct GoogleService-Info.plist from Firebase Console for the iOS app")
        print(f"with bundle id {args.expected_bundle_id}, then replace this file.")
        return 5

    print("✅ GoogleService-Info.plist looks valid")
    print(f"   PROJECT_ID: {obj.get('PROJECT_ID')}")
    print(f"   GCM_SENDER_ID: {obj.get('GCM_SENDER_ID')}")
    print(f"   BUNDLE_ID: {obj.get('BUNDLE_ID')}")
    print(f"   GOOGLE_APP_ID: {obj.get('GOOGLE_APP_ID')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
