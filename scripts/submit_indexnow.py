#!/usr/bin/env python3
"""Submit every live sitemap URL to IndexNow.

Used by the GitHub Actions workflow after a production deploy, and safely
re-runnable locally:

    python3 scripts/submit_indexnow.py --dry-run
"""

import argparse
import json
import sys
import time
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET

KEY = "9f2c7a4e1b8d6f30c5a9e2b7d4f1a6c3"
HOST = "www.komiuta.com"
SITEMAP = f"https://{HOST}/sitemap.xml"
ENDPOINT = "https://api.indexnow.org/indexnow"
KEY_LOCATION = f"https://{HOST}/{KEY}.txt"


def fetch_sitemap(url, attempts=8, delay=30):
    last_error = None
    for attempt in range(1, attempts + 1):
        try:
            with urllib.request.urlopen(url, timeout=60) as response:
                body = response.read()
            if response.status == 200:
                return body
        except (urllib.error.URLError, TimeoutError) as error:
            last_error = error
        print(f"sitemap fetch attempt {attempt} failed; retrying …", file=sys.stderr)
        time.sleep(delay)
    raise RuntimeError(f"could not fetch sitemap: {last_error}")


def sitemap_urls(body):
    root = ET.fromstring(body)
    namespace = "{http://www.sitemaps.org/schemas/sitemap/0.9}"
    return [element.text.strip() for element in root.iter(f"{namespace}loc") if element.text]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--sitemap", default=SITEMAP)
    args = parser.parse_args()

    urls = sitemap_urls(fetch_sitemap(args.sitemap))
    print(f"Submitting {len(urls)} URLs to IndexNow")

    if args.dry_run:
        print("\n".join(urls))
        return

    payload = {"host": HOST, "key": KEY, "keyLocation": KEY_LOCATION, "urlList": urls}
    request = urllib.request.Request(
        ENDPOINT,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json; charset=utf-8"},
        method="POST",
    )

    with urllib.request.urlopen(request, timeout=60) as response:
        print(f"IndexNow responded HTTP {response.status}")

    if response.status not in (200, 202):
        raise SystemExit("IndexNow submission was rejected")


if __name__ == "__main__":
    main()
