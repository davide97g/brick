#!/usr/bin/env python3
"""Capture the App Store screenshot set from the Simulator.

Every screen is seeded through the state file rather than tapped, so a pass is
repeatable and covers the screens behind a tap — see the `-uiPreview` hook in
`BrickApp`. Screens that need a running session, or a reverse setup standing,
get their own seed.

    python3 store/screenshots/capture.py            # 6.9" set, then the 6.5" derivation
    python3 store/screenshots/capture.py --content-size accessibility-extra-extra-extra-large

Note the app must be a Debug build: `-uiPreview` is compiled out of Release.
"""

import argparse, json, os, plistlib, re, shutil, subprocess, sys, time, uuid
from datetime import datetime, timedelta, timezone

BUNDLE = "com.davideghiotto.brick"
GROUP = "group.com.davideghiotto.brick"
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DD = os.path.join(ROOT, "build", "dd")
APP = os.path.join(DD, "Build", "Products", "Debug-iphonesimulator", "Brick.app")
OUT_69 = os.path.join(ROOT, "store", "screenshots", "6.9")
OUT_65 = os.path.join(ROOT, "store", "screenshots", "6.5")

# The 6.5" slot rejects 1320 × 2868, so it is scaled to width and centre-cropped
# — the aspect ratios differ by 0.4%, and cropping a sliver of margin beats
# stretching the dial into an ellipse.
SIZE_69 = (1320, 2868)
SIZE_65 = (1242, 2688)


def run(*args, **kw):
    return subprocess.run(args, check=True, capture_output=True, text=True, **kw).stdout


def iso(dt):
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def minutes(count):
    return count * 60.0


# MARK: the seeds

P1, P2, P3 = str(uuid.uuid4()), str(uuid.uuid4()), str(uuid.uuid4())
T1, T2, T3 = "04A2B3C4D5E680", "04FF11223344AA", "0499887766AABB"


def profiles():
    return [
        {
            "id": P1, "name": "Deep work",
            "appCount": 12, "categoryCount": 2, "webDomainCount": 3,
            "defaultDuration": minutes(90), "minimumDuration": minutes(30),
            "mode": "block",
            # Two steps: the price of leaving is a walk through the flat.
            "exitRoute": [T1, T2],
            "routeWindow": minutes(10),
            "permitAllowance": 3, "permitWindow": 24 * 3600,
            "permitDuration": minutes(15),
        },
        {
            "id": P2, "name": "Evening",
            "appCount": 8, "categoryCount": 1, "webDomainCount": 0,
            "defaultDuration": minutes(180), "minimumDuration": minutes(30),
            "mode": "block", "exitRoute": [], "routeWindow": minutes(10),
            "permitAllowance": 3, "permitWindow": 24 * 3600,
            "permitDuration": minutes(15),
        },
        {
            "id": P3, "name": "Sleep",
            "appCount": 20, "categoryCount": 3, "webDomainCount": 0,
            "defaultDuration": minutes(60), "minimumDuration": minutes(30),
            "mode": "reverse", "exitRoute": [], "routeWindow": minutes(10),
            "permitAllowance": 3, "permitWindow": 24 * 3600,
            "permitDuration": minutes(15),
        },
    ]


def tags(now):
    return [
        {"uid": T1, "ndefID": str(uuid.uuid4()), "name": "desk slab",
         "placeNote": "on your desk", "profileID": P1,
         "pairedAt": iso(now - timedelta(days=12))},
        {"uid": T2, "ndefID": str(uuid.uuid4()), "name": "kitchen shelf",
         "placeNote": "on the kitchen shelf", "profileID": P2,
         "pairedAt": iso(now - timedelta(days=9))},
        {"uid": T3, "ndefID": str(uuid.uuid4()), "name": "bedside sticker",
         "placeNote": "on the bedside table", "profileID": P3,
         "pairedAt": iso(now - timedelta(days=4))},
    ]


def history(now):
    return [
        {"id": str(uuid.uuid4()),
         "startedAt": iso(now - timedelta(days=1, minutes=90)),
         "plannedEnd": iso(now - timedelta(days=1)),
         "endedAt": iso(now - timedelta(days=1)),
         "endReason": "scheduled", "kind": "block", "profileID": P1,
         "startedByTag": T1, "grantedByEmergency": False},
        {"id": str(uuid.uuid4()),
         "startedAt": iso(now - timedelta(days=2, minutes=120)),
         "plannedEnd": iso(now - timedelta(days=2)),
         "endedAt": iso(now - timedelta(days=2, minutes=20)),
         "endReason": "tappedBrick", "kind": "block", "profileID": P1,
         "startedByTag": T1, "grantedByEmergency": False},
    ]


def state(now, **overrides):
    base = {
        "tags": tags(now),
        "profiles": profiles(),
        "unlock": "brick",
        "history": history(now),
        # One spent this week, so the home screen says two are left rather
        # than showing an untouched quota.
        "emergency": {"uses": [iso(now - timedelta(days=2))]},
        "permits": {"uses": []},
    }
    base.update(overrides)
    return base


def seeds(now):
    running = {
        "id": str(uuid.uuid4()),
        "startedAt": iso(now - timedelta(minutes=26)),
        "plannedEnd": iso(now + timedelta(minutes=64)),
        "kind": "block", "profileID": P1, "startedByTag": T1,
        "grantedByEmergency": False,
    }
    return {
        "idle": state(now),
        "running": state(now, activeSession=running),
        "reverse": state(now, armedProfileID=P3,
                         armedAt=iso(now - timedelta(hours=3)),
                         permits={"uses": [iso(now - timedelta(hours=5))]}),
        # Onboarding is what an install with no key looks like.
        "fresh": {"tags": [], "profiles": [], "unlock": "brick",
                  "history": [], "emergency": {"uses": []}, "permits": {"uses": []}},
    }


# name, seed, launch arguments, and how long to let it settle.
#
# The running dial ticks every second through `.contentTransition(.numericText())`,
# whose blur covers most of each second — every frame after the first tick
# catches the last digit in transit. So that one shot is taken at first paint,
# before the tick has fired at all.
SHOTS = [
    ("01-idle", "idle", []),
    ("02-start-sheet", "idle", ["-uiPreview", "start"]),
    ("03-running", "running", [], 1.2),
    ("04-reverse", "reverse", []),
    ("05-blocklist", "idle", ["-uiPreview", "blocklist"]),
    ("06-setups", "idle", ["-uiPreview", "setups"]),
    ("07-route", "idle", ["-uiPreview", "route"]),
    ("08-bricks", "idle", ["-uiPreview", "bricks"]),
    ("09-brick", "idle", ["-uiPreview", "brick"]),
    ("10-settings", "idle", ["-uiPreview", "settings"]),
    ("11-onboarding", "fresh", ["-uiPreview", "onboard1"]),
]


def device_id(name):
    listing = json.loads(run("xcrun", "simctl", "list", "devices", "-j"))
    for runtime in listing["devices"].values():
        for device in runtime:
            if device["name"] == name and device.get("isAvailable"):
                return device["udid"]
    sys.exit(f"no simulator named {name!r}")


def group_container(udid):
    out = run("xcrun", "simctl", "get_app_container", udid, BUNDLE, "groups")
    for line in out.splitlines():
        if GROUP in line:
            return line.split("\t")[-1].strip() if "\t" in line else line.split()[-1]
    sys.exit("app group container not found — is the app installed?")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--device", default="iPhone 17 Pro Max")
    parser.add_argument("--content-size", default="medium",
                        help="pass an accessibility size to check the layouts scale")
    parser.add_argument("--skip-build", action="store_true")
    parser.add_argument("--only", help="capture one shot by name")
    args = parser.parse_args()

    if not args.skip_build:
        print("building (Debug — -uiPreview is compiled out of Release)")
        run("xcodebuild", "-project", os.path.join(ROOT, "Brick.xcodeproj"),
            "-scheme", "Brick", "-configuration", "Debug",
            "-destination", f"platform=iOS Simulator,name={args.device}",
            "-derivedDataPath", DD, "build", cwd=ROOT)

    udid = device_id(args.device)
    print(f"device {args.device} {udid}")
    subprocess.run(["xcrun", "simctl", "boot", udid], capture_output=True)
    run("xcrun", "simctl", "bootstatus", udid)
    run("xcrun", "simctl", "install", udid, APP)
    run("xcrun", "simctl", "spawn", udid, "defaults", "write", BUNDLE,
        "pretend.authorized", "-bool", "true")
    run("xcrun", "simctl", "ui", udid, "content_size", args.content_size)
    # The clock is the simulator's real one, not Apple's 9:41: the app derives
    # "until 23:41" and "the brick opens at 22:41" from the same now, and a
    # status bar disagreeing with the screen under it reads as a fake.
    run("xcrun", "simctl", "status_bar", udid, "override",
        "--time", datetime.now().strftime("%H:%M"),
        "--batteryState", "charged", "--batteryLevel", "100",
        "--cellularMode", "active", "--cellularBars", "4",
        "--dataNetwork", "wifi", "--wifiBars", "3")

    container = group_container(udid)
    path = os.path.join(container, "brick-state.json")
    os.makedirs(OUT_69, exist_ok=True)

    for shot in SHOTS:
        name, seed, launch_args = shot[0], shot[1], shot[2]
        settle = shot[3] if len(shot) > 3 else None
        if args.only and args.only not in name:
            continue
        subprocess.run(["xcrun", "simctl", "terminate", udid, BUNDLE],
                       capture_output=True)
        # Seeded per shot: "now" has to be fresh, or the running session's
        # remaining time drifts across a long pass.
        with open(path, "w") as f:
            json.dump(seeds(datetime.now(timezone.utc))[seed], f)
        run("xcrun", "simctl", "launch", udid, BUNDLE, *launch_args)
        time.sleep(settle or 3.0)
        out = os.path.join(OUT_69, f"{name}.png")
        run("xcrun", "simctl", "io", udid, "screenshot", out)
        print(f"  {name}.png")

    derive_65()


def derive_65():
    os.makedirs(OUT_65, exist_ok=True)
    for name in sorted(os.listdir(OUT_69)):
        if not name.endswith(".png"):
            continue
        src, dst = os.path.join(OUT_69, name), os.path.join(OUT_65, name)
        shutil.copyfile(src, dst)
        run("sips", "--resampleWidth", str(SIZE_65[0]), dst)
        run("sips", "--cropToHeightWidth", str(SIZE_65[1]), str(SIZE_65[0]), dst)
    print(f"6.5\" set derived into {OUT_65}")


if __name__ == "__main__":
    main()
