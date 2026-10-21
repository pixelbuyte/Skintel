#!/usr/bin/env python3
"""Read-only App Store Connect check of Skintel's In-App Purchases.

Run by the Codemagic `asc-iap-check` workflow. Uses the App Store Connect API key from the
Codemagic integration (APP_STORE_CONNECT_ISSUER_ID / _KEY_IDENTIFIER / _PRIVATE_KEY), lists
every subscription group, subscription and in-app purchase with its product id, state,
period, US price, localizations and availability, and compares the ids with the ones the app
requests (SubscriptionService.ProductID). It never writes to App Store Connect and never
prints the key or token.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import jwt  # PyJWT, installed by the workflow

BUNDLE_ID = os.environ.get("BUNDLE_ID", "com.skintel.app")
APP_IDS = {
    "com.skintel.app.pro.monthly": "required",
    "com.skintel.app.pro.yearly": "required",
    "com.skintel.app.founding": "optional (not on sale)",
}
API = "https://api.appstoreconnect.apple.com"


def resolve(name: str) -> str:
    """Codemagic integrations may pass `@env:VAR` / `@file:path` references instead of values."""
    v = os.environ.get(name, "").strip()
    for _ in range(3):
        if v.startswith("@file:"):
            v = open(os.path.expanduser(v[len("@file:"):])).read().strip()
        elif v.startswith("@env:"):
            v = os.environ.get(v[len("@env:"):], "").strip()
        else:
            break
    return v


ISSUER = resolve("APP_STORE_CONNECT_ISSUER_ID")
KEY_ID = resolve("APP_STORE_CONNECT_KEY_IDENTIFIER")
# Shapes only, never values: an issuer id is a 36-char UUID, a key id 10 characters.
print(f"credentials: issuer {len(ISSUER)} chars{' (uuid)' if len(ISSUER) == 36 and ISSUER.count('-') == 4 else ''}, "
      f"key id {len(KEY_ID)} chars, private key present={bool(os.environ.get('APP_STORE_CONNECT_PRIVATE_KEY'))}")


def token() -> str:
    key = resolve("APP_STORE_CONNECT_PRIVATE_KEY").replace("\\n", "\n")
    if "BEGIN" not in key:
        # Bare base64 body: rebuild the PEM framing.
        body = "".join(key.split())
        key = "-----BEGIN PRIVATE KEY-----\n" + "\n".join(body[i:i + 64] for i in range(0, len(body), 64)) + "\n-----END PRIVATE KEY-----\n"
    elif "\n" not in key:
        # Header, body and footer squashed onto one line with spaces.
        head, rest = key.split("-----BEGIN PRIVATE KEY-----", 1)
        body, _ = rest.split("-----END PRIVATE KEY-----", 1)
        body = "".join(body.split())
        key = "-----BEGIN PRIVATE KEY-----\n" + "\n".join(body[i:i + 64] for i in range(0, len(body), 64)) + "\n-----END PRIVATE KEY-----\n"
    now = int(time.time())
    return jwt.encode(
        # Team keys carry the issuer id; individual keys (no issuer) use sub="user".
        ({"iss": ISSUER} if ISSUER else {"sub": "user"}) | {"iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"},
        key,
        algorithm="ES256",
        headers={"kid": KEY_ID, "typ": "JWT"},
    )


TOKEN = token()


def get(path: str, **params) -> dict:
    url = API + path + ("?" + urllib.parse.urlencode(params) if params else "")
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {TOKEN}"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        body = e.read().decode()[:400]
        print(f"  ! GET {path} -> HTTP {e.code}: {body}")
        return {"data": [], "included": []}


def main() -> int:
    apps = get("/v1/apps", **{"filter[bundleId]": BUNDLE_ID})["data"]
    if not apps:
        print(f"No app with bundle id {BUNDLE_ID} visible to this API key.")
        return 1
    app = apps[0]
    print(f"App: {app['attributes'].get('name')}  bundle={BUNDLE_ID}  appleId={app['id']}\n")

    found: dict[str, str] = {}

    groups = get(f"/v1/apps/{app['id']}/subscriptionGroups", limit=50)["data"]
    print(f"Subscription groups: {len(groups)}")
    for g in groups:
        gl = get(f"/v1/subscriptionGroups/{g['id']}/subscriptionGroupLocalizations", limit=50)["data"]
        print(f"\n[group] reference name: {g['attributes'].get('referenceName')!r}  "
              f"localizations: {[l['attributes'].get('locale') + '=' + str(l['attributes'].get('state')) for l in gl] or 'NONE'}")
        subs = get(f"/v1/subscriptionGroups/{g['id']}/subscriptions", limit=50)["data"]
        if not subs:
            print("  (no subscriptions)")
        for s in subs:
            a = s["attributes"]
            pid = a.get("productId")
            found[pid] = a.get("state")
            locs = get(f"/v1/subscriptions/{s['id']}/subscriptionLocalizations", limit=50)["data"]
            avail = get(f"/v1/subscriptions/{s['id']}/subscriptionAvailability")
            terr = get(f"/v1/subscriptions/{s['id']}/subscriptionAvailability/availableTerritories", limit=200)["data"] if avail.get("data") else []
            prices = get(f"/v1/subscriptions/{s['id']}/prices", include="subscriptionPricePoint",
                         **{"filter[territory]": "USA"}, limit=5)
            us = [i["attributes"].get("customerPrice") for i in prices.get("included", []) if i.get("type") == "subscriptionPricePoints"]
            intro = get(f"/v1/subscriptions/{s['id']}/introductoryOffers", limit=5)["data"]
            shot = get(f"/v1/subscriptions/{s['id']}/appStoreReviewScreenshot").get("data")
            print(f"  - productId={pid!r}")
            print(f"      name={a.get('name')!r}  state={a.get('state')}  period={a.get('subscriptionPeriod')}")
            print(f"      US price={us or 'NOT SET'}  territories={len(terr)}  intro offers={len(intro)}")
            print(f"      localizations={[l['attributes'].get('locale') + ':' + str(l['attributes'].get('name')) + ':' + str(l['attributes'].get('state')) for l in locs] or 'NONE'}")
            print(f"      review screenshot={'yes' if shot else 'NONE'}")

    iaps = get(f"/v1/apps/{app['id']}/inAppPurchasesV2", limit=50)["data"]
    print(f"\nOther in-app purchases: {len(iaps)}")
    for p in iaps:
        a = p["attributes"]
        found[a.get("productId")] = a.get("state")
        print(f"  - productId={a.get('productId')!r} type={a.get('inAppPurchaseType')} state={a.get('state')} name={a.get('name')!r}")

    print("\n=== The app requests these ids (SubscriptionService.ProductID / api/_apple.ts) ===")
    ok = True
    for pid, need in APP_IDS.items():
        if pid in found:
            print(f"  MATCH    {pid}  ({need})  state={found[pid]}")
        else:
            print(f"  MISSING  {pid}  ({need})")
            if need == "required":
                ok = False
    extra = [p for p in found if p not in APP_IDS]
    if extra:
        print(f"  In App Store Connect but never requested by the app: {extra}")
    print("\nNote: the Paid Apps Agreement, tax and banking status are not exposed by this API;"
          " check Business > Agreements in App Store Connect.")
    print("RESULT:", "product ids match" if ok else "PRODUCT ID MISMATCH - the app will show 'Plans are temporarily unavailable'")
    return 0


if __name__ == "__main__":
    sys.exit(main())
