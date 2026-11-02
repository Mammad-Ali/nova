#!/usr/bin/env python3
"""Writes Sparkle's update feed (appcast.xml) for one release of Nova.

Run by the release job in .github/workflows/build.yml. The feed is published
as a file of the release, so the address in the app's Info.plist —
releases/latest/download/appcast.xml — always serves the newest one. It has
a single entry: the signed zip of this release. Sparkle compares the entry's
build number with the running app's and offers the update when it is higher.

Usage: make_appcast.py --tag v1.5.0 --signature 'sparkle:edSignature="…" length="…"'
The signature line is what Sparkle's sign_update prints for the zip.
"""

import argparse
import re
import sys
from email.utils import formatdate
from xml.sax.saxutils import escape, quoteattr

REPO = "https://github.com/Mammad-Ali/nova"
# MACOSX_DEPLOYMENT_TARGET of the Runner target.
MINIMUM_MACOS = "12.0"


def pubspec_version(path="pubspec.yaml"):
    """("1.5.0", "6") from 'version: 1.5.0+6'."""
    with open(path, encoding="utf-8") as f:
        for line in f:
            match = re.match(r"^version:\s*([0-9.]+)\+([0-9]+)\s*$", line)
            if match:
                return match.group(1), match.group(2)
    sys.exit("pubspec.yaml has no 'version: x.y.z+n' line")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--tag", required=True)
    parser.add_argument("--signature", required=True)
    args = parser.parse_args()

    version, build = pubspec_version()
    if args.tag.removeprefix("v") != version:
        sys.exit(f"tag {args.tag} doesn't match pubspec.yaml's {version}")

    fields = dict(re.findall(r'(sparkle:edSignature|length)="([^"]+)"', args.signature))
    if "sparkle:edSignature" not in fields or "length" not in fields:
        sys.exit("the signature line lacks sparkle:edSignature or length")

    zip_url = f"{REPO}/releases/download/{args.tag}/Nova-macOS.zip"
    notes_url = f"{REPO}/releases/tag/{args.tag}"
    print(f"""<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Nova</title>
    <link>{escape(REPO)}</link>
    <item>
      <title>Nova {escape(version)}</title>
      <pubDate>{formatdate(usegmt=True)}</pubDate>
      <sparkle:version>{escape(build)}</sparkle:version>
      <sparkle:shortVersionString>{escape(version)}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>{MINIMUM_MACOS}</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>{escape(notes_url)}</sparkle:releaseNotesLink>
      <enclosure url={quoteattr(zip_url)}
                 sparkle:edSignature={quoteattr(fields["sparkle:edSignature"])}
                 length={quoteattr(fields["length"])}
                 type="application/octet-stream"/>
    </item>
  </channel>
</rss>""")


if __name__ == "__main__":
    main()
