#!/usr/bin/env python3
"""Fill the App Store Connect listing from `store/METADATA.md`.

The listing copy lives in the repository, not in a web form, so this pushes it
rather than retyping it. Signed with the App Store Connect API key.

    python3 store/connect.py show
    python3 store/connect.py metadata [--video-url URL]
    python3 store/connect.py screenshots

`metadata` writes the version localization (description, keywords, promotional
text, URLs), the app info (name, subtitle, privacy policy, categories) and the
App Review details (notes, contact, no demo account). `screenshots` replaces
every screenshot set with what is in `store/screenshots/`.
"""

import argparse, base64, hashlib, json, os, re, subprocess, sys, time, urllib.error, urllib.request

KEY_ID = "MFCGJ8UX92"
ISSUER = "f8b76e45-dfdd-4938-916a-f2840dde0f09"
KEY_PATH = os.path.expanduser("~/.appstoreconnect/private_keys/AuthKey_MFCGJ8UX92.p8")
BUNDLE = "com.davideghiotto.brick"
LOCALE = "en-US"
HOST = "https://api.appstoreconnect.apple.com"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
METADATA = os.path.join(ROOT, "store", "METADATA.md")

PRIMARY_CATEGORY = "PRODUCTIVITY"
SECONDARY_CATEGORY = "HEALTH_AND_FITNESS"

CONTACT = {
    "contactFirstName": "Davide",
    "contactLastName": "Ghiotto",
    "contactPhone": None,   # left as whatever App Store Connect already holds
    "contactEmail": None,
}

# Which screens go in the listing, in order. The first three are the ones the
# install sheet shows. `09-brick` and `10-settings` are deliberately absent:
# Settings shows the App Review section, which is evidence, not a selling point.
LISTING = [
    "01-idle", "03-running", "04-reverse", "02-start-sheet", "05-blocklist",
    "06-setups", "07-route", "08-bricks", "11-onboarding",
]
# There is no APP_IPHONE_69 in the API: 6.9" artwork (1320 × 2868) goes into the
# 6.7" slot, and the 6.5" slot takes its own smaller size.
SETS = {"APP_IPHONE_67": "6.9", "APP_IPHONE_65": "6.5"}


# MARK: signing and transport

def token():
    def b64(raw):
        return base64.urlsafe_b64encode(raw).rstrip(b"=")

    def der_to_raw(der):
        assert der[0] == 0x30
        index = 2 + (der[1] & 0x7F if der[1] & 0x80 else 0)
        out = b""
        for _ in range(2):
            assert der[index] == 0x02
            length = der[index + 1]
            out += der[index + 2:index + 2 + length].lstrip(b"\x00").rjust(32, b"\x00")
            index += 2 + length
        return out

    now = int(time.time())
    header = {"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}
    payload = {"iss": ISSUER, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"}
    signing = (b64(json.dumps(header, separators=(",", ":")).encode()) + b"."
               + b64(json.dumps(payload, separators=(",", ":")).encode()))
    der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", KEY_PATH],
                         input=signing, capture_output=True, check=True).stdout
    return (signing + b"." + b64(der_to_raw(der))).decode()


BEARER = None


def call(method, path, body=None, raw=None, headers=None, host=None):
    global BEARER
    BEARER = BEARER or token()
    url = path if path.startswith("http") else (host or HOST) + path
    data = raw if raw is not None else (json.dumps(body).encode() if body else None)
    request = urllib.request.Request(url, data=data, method=method)
    if not path.startswith("http"):
        request.add_header("Authorization", "Bearer " + BEARER)
    if body is not None:
        request.add_header("Content-Type", "application/json")
    for key, value in (headers or {}).items():
        request.add_header(key, value)
    try:
        with urllib.request.urlopen(request) as response:
            payload = response.read()
            return json.loads(payload) if payload else None
    except urllib.error.HTTPError as error:
        detail = error.read().decode()
        sys.exit(f"{method} {url} → {error.code}\n{detail}")


def get(path):
    return call("GET", path)


# MARK: the copy, read out of METADATA.md

def metadata_text():
    return open(METADATA).read()


def section(title, text):
    match = re.search(rf"^## {re.escape(title)}.*?\n(.*?)(?=^## )", text, re.S | re.M)
    if not match:
        sys.exit(f"section {title!r} not found in METADATA.md")
    return match.group(1).strip()


def plain(block):
    """Markdown emphasis and hard wraps out; paragraphs and bullets kept."""
    block = block.replace("**", "")
    out, buffer = [], []
    for line in block.split("\n"):
        if not line.strip():
            if buffer:
                out.append(" ".join(buffer)); buffer = []
            out.append("")
        elif line.startswith(("•", "-", "1.", "2.", "3.", "4.")) or line.startswith("  "):
            if buffer:
                out.append(" ".join(buffer)); buffer = []
            out.append(line.strip() if not line.startswith("  ") else line.strip())
            if out[-1].startswith(("  ",)):
                out[-1] = out[-1].strip()
        else:
            buffer.append(line.strip())
    if buffer:
        out.append(" ".join(buffer))
    # Bullets that wrapped in the source get joined back onto their bullet.
    joined = []
    for line in out:
        if joined and line and not line.startswith("•") and joined[-1].startswith("•") and line != "":
            joined[-1] += " " + line
        else:
            joined.append(line)
    return "\n".join(joined).strip()


def copy_for_listing(video_url=None):
    text = metadata_text()
    keywords = re.search(r"^## Keywords.*?\n\n`(.+?)`", text, re.S | re.M).group(1)
    notes = "\n".join(
        line[2:] if line.startswith("> ") else line[1:].strip()
        for line in section("Review notes", text).split("\n")
        if line.startswith(">")
    ).strip()
    notes = plain(notes).replace("`", "")
    # The video URL is the first line App Review reads. Without one, drop the
    # placeholder rather than sending Apple a literal "[VIDEO URL]".
    lines = [line for line in notes.split("\n")]
    lines = [line for line in lines if "[VIDEO URL]" not in line]
    if video_url:
        lines = [f"Demo video (physical iPhone + physical NFC tag): {video_url}", ""] + lines
    notes = "\n".join(lines).strip()

    listing = {
        "description": plain(section("Description (4000)", text)),
        "keywords": keywords,
        "promotionalText": plain(section("Promotional text (170)", text)),
        "supportUrl": "https://github.com/davide97g/brick",
        "marketingUrl": None,
        "whatsNew": None,
    }
    limits = {"description": 4000, "keywords": 100, "promotionalText": 170}
    for field, limit in limits.items():
        if len(listing[field]) > limit:
            sys.exit(f"{field} is {len(listing[field])} characters, over Apple's {limit}")
    return listing, notes


# MARK: the objects

def ids():
    app = get(f"/v1/apps?filter[bundleId]={BUNDLE}")["data"][0]["id"]
    version = get(f"/v1/apps/{app}/appStoreVersions?limit=1")["data"][0]
    localizations = get(f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations")["data"]
    localization = next(l for l in localizations if l["attributes"]["locale"] == LOCALE)
    info = get(f"/v1/apps/{app}/appInfos")["data"][0]
    info_localizations = get(f"/v1/appInfos/{info['id']}/appInfoLocalizations")["data"]
    info_localization = next(l for l in info_localizations if l["attributes"]["locale"] == LOCALE)
    return app, version, localization["id"], info["id"], info_localization["id"]


def show():
    app, version, localization, info, info_localization = ids()
    print(f"app {app}  version {version['attributes']['versionString']} "
          f"({version['attributes'].get('appStoreState') or version['attributes'].get('appVersionState')})")
    build = get(f"/v1/appStoreVersions/{version['id']}/build")
    print("build:", build["data"]["attributes"]["version"] if build.get("data") else "none")
    attributes = get(f"/v1/appStoreVersionLocalizations/{localization}")["data"]["attributes"]
    for key, value in attributes.items():
        print(f"  {key}: {str(value or '')[:70]}")
    # Relationship data only comes back when it is asked for by name.
    info_data = get(f"/v1/appInfos/{info}?include=primaryCategory,secondaryCategory")["data"]
    for key in ("primaryCategory", "secondaryCategory"):
        relationship = info_data["relationships"][key].get("data")
        print(f"  {key}: {relationship['id'] if relationship else None}")
    for key, value in get(f"/v1/appInfoLocalizations/{info_localization}")["data"]["attributes"].items():
        print(f"  {key}: {str(value or '')[:70]}")
    detail = get(f"/v1/appStoreVersions/{version['id']}/appStoreReviewDetail")
    if detail.get("data"):
        attributes = detail["data"]["attributes"]
        print(f"  review notes: {len(attributes.get('notes') or '')} characters")
        print(f"  demo account required: {attributes.get('demoAccountRequired')}")
    else:
        print("  review detail: none")
    for screenshot_set in get(f"/v1/appStoreVersionLocalizations/{localization}/appScreenshotSets")["data"]:
        shots = get(f"/v1/appScreenshotSets/{screenshot_set['id']}/appScreenshots")["data"]
        print(f"  {screenshot_set['attributes']['screenshotDisplayType']}: "
              f"{', '.join(s['attributes'].get('fileName') or '?' for s in shots)}")


def write_metadata(video_url=None):
    listing, notes = copy_for_listing(video_url)
    app, version, localization, info, info_localization = ids()

    call("PATCH", f"/v1/appStoreVersionLocalizations/{localization}", {
        "data": {"type": "appStoreVersionLocalizations", "id": localization,
                 "attributes": {k: v for k, v in listing.items() if v is not None}},
    })
    print("version localization written "
          f"({len(listing['description'])} character description, "
          f"{len(listing['keywords'])} characters of keywords)")

    text = metadata_text()
    subtitle = re.search(r"\| Subtitle \(30\) \| `(.+?)` \|", text).group(1)
    privacy = "https://github.com/davide97g/brick/blob/main/store/PRIVACY.md"
    call("PATCH", f"/v1/appInfoLocalizations/{info_localization}", {
        "data": {"type": "appInfoLocalizations", "id": info_localization,
                 "attributes": {"subtitle": subtitle, "privacyPolicyUrl": privacy}},
    })
    print(f"subtitle {subtitle!r} and privacy policy URL written")

    call("PATCH", f"/v1/appInfos/{info}", {
        "data": {"type": "appInfos", "id": info,
                 "relationships": {
                     "primaryCategory": {"data": {"type": "appCategories", "id": PRIMARY_CATEGORY}},
                     "secondaryCategory": {"data": {"type": "appCategories", "id": SECONDARY_CATEGORY}},
                 }},
    })
    print(f"categories set: {PRIMARY_CATEGORY} / {SECONDARY_CATEGORY}")

    attributes = {"notes": notes, "demoAccountRequired": False}
    attributes.update({k: v for k, v in CONTACT.items() if v})
    detail = get(f"/v1/appStoreVersions/{version['id']}/appStoreReviewDetail")
    if detail.get("data"):
        call("PATCH", f"/v1/appStoreReviewDetails/{detail['data']['id']}",
             {"data": {"type": "appStoreReviewDetails", "id": detail["data"]["id"],
                       "attributes": attributes}})
    else:
        call("POST", "/v1/appStoreReviewDetails", {
            "data": {"type": "appStoreReviewDetails", "attributes": attributes,
                     "relationships": {"appStoreVersion": {
                         "data": {"type": "appStoreVersions", "id": version["id"]}}}},
        })
    print(f"review notes written ({len(notes)} characters)"
          + ("" if video_url else " — no video URL yet, rerun with --video-url"))


def upload_screenshot(set_id, path):
    name = os.path.basename(path)
    blob = open(path, "rb").read()
    created = call("POST", "/v1/appScreenshots", {
        "data": {"type": "appScreenshots",
                 "attributes": {"fileSize": len(blob), "fileName": name},
                 "relationships": {"appScreenshotSet": {
                     "data": {"type": "appScreenshotSets", "id": set_id}}}},
    })["data"]
    for operation in created["attributes"]["uploadOperations"]:
        headers = {h["name"]: h["value"] for h in operation.get("requestHeaders", [])}
        chunk = blob[operation["offset"]:operation["offset"] + operation["length"]]
        call(operation["method"], operation["url"], raw=chunk, headers=headers)
    call("PATCH", f"/v1/appScreenshots/{created['id']}", {
        "data": {"type": "appScreenshots", "id": created["id"],
                 "attributes": {"uploaded": True,
                                "sourceFileChecksum": hashlib.md5(blob).hexdigest()}},
    })
    return created["id"]


def write_screenshots():
    _, _, localization, _, _ = ids()
    existing = {s["attributes"]["screenshotDisplayType"]: s["id"]
                for s in get(f"/v1/appStoreVersionLocalizations/{localization}/appScreenshotSets")["data"]}

    for display_type, folder in SETS.items():
        set_id = existing.get(display_type)
        if set_id:
            # Replaced rather than appended: the old set is a different app.
            for shot in get(f"/v1/appScreenshotSets/{set_id}/appScreenshots")["data"]:
                call("DELETE", f"/v1/appScreenshots/{shot['id']}")
        else:
            set_id = call("POST", "/v1/appScreenshotSets", {
                "data": {"type": "appScreenshotSets",
                         "attributes": {"screenshotDisplayType": display_type},
                         "relationships": {"appStoreVersionLocalization": {
                             "data": {"type": "appStoreVersionLocalizations", "id": localization}}}},
            })["data"]["id"]

        order = []
        for name in LISTING:
            path = os.path.join(ROOT, "store", "screenshots", folder, f"{name}.png")
            order.append(upload_screenshot(set_id, path))
            print(f"  {display_type} {name}.png")
        call("PATCH", f"/v1/appScreenshotSets/{set_id}/relationships/appScreenshots",
             {"data": [{"type": "appScreenshots", "id": i} for i in order]})
        print(f"{display_type}: {len(order)} screenshots, ordered")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["show", "metadata", "screenshots"])
    parser.add_argument("--video-url")
    args = parser.parse_args()
    if args.command == "show":
        show()
    elif args.command == "metadata":
        write_metadata(args.video_url)
    else:
        write_screenshots()


if __name__ == "__main__":
    main()
