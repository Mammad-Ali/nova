#!/usr/bin/env python3
"""Builds assets/oui/vendors.txt: MAC address prefixes of brands found in
homes, so the network scan can say "Samsung" or "TP-Link" for a device that
announces no name.

The source is the IEEE's public list of MAC prefixes (MA-L):

  curl -o oui.csv https://standards-oui.ieee.org/oui/oui.csv
  python3 tool/make_vendor_list.py oui.csv

Only the brands below are kept — the full list is 3.8 MB, most of it
industrial makers no one has at home.
"""

import csv
import re
import sys
from collections import Counter

# Shown name, then a pattern for the IEEE's organisation name. First match
# wins, so the more specific patterns come first.
BRANDS = [
    ("Apple", r"^Apple,? Inc"), ("Samsung", r"Samsung Electro|SAMSUNG ELECTRO"), ("Xiaomi", r"Xiaomi"),
    ("Huawei", r"Huawei (Technologies|Device)"), ("Honor", r"Honor Device"), ("OPPO", r"OPPO"),
    ("vivo", r"vivo Mobile"), ("OnePlus", r"OnePlus"), ("realme", r"Realme"), ("Motorola", r"Motorola Mobility"),
    ("Google", r"^Google"), ("Amazon", r"^Amazon"), ("Microsoft", r"^Microsoft"),
    ("Sony PlayStation", r"Sony Interactive"), ("Sony", r"^Sony"), ("Nintendo", r"Nintendo"),
    ("LG", r"^LG Electronics|LG Innotek"), ("Lenovo", r"^Lenovo"), ("Dell", r"^Dell"),
    ("HP", r"Hewlett Packard|^HP Inc"), ("Intel", r"^Intel Corporate"), ("ASUS", r"ASUSTek"), ("Acer", r"^Acer"),
    ("TP-Link", r"TP-LINK|TP-Link"), ("Mercusys", r"MERCUSYS"), ("Netgear", r"NETGEAR"), ("D-Link", r"^D-Link"),
    ("Ubiquiti", r"Ubiquiti"), ("MikroTik", r"Routerboard|MikroTik"), ("Zyxel", r"Zyxel|ZyXEL"),
    ("Keenetic", r"Keenetic"), ("Tenda", r"Tenda"), ("ZTE", r"^zte corporation|^ZTE"), ("Nokia", r"^Nokia"),
    ("Arcadyan", r"Arcadyan"), ("Sagemcom", r"Sagemcom"), ("Technicolor", r"Technicolor"),
    ("Synology", r"Synology"), ("QNAP", r"QNAP"), ("Canon", r"^Canon Inc"), ("Epson", r"Seiko Epson"),
    ("Brother", r"Brother Industries"), ("Sonos", r"^Sonos"), ("Roku", r"^Roku"),
    ("Philips Hue", r"Signify|Philips Lighting"), ("Espressif", r"Espressif"), ("Tuya", r"Tuya"),
    ("Raspberry Pi", r"Raspberry Pi"), ("Hikvision", r"Hikvision"), ("Dahua", r"Dahua"),
]


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    compiled = [(name, re.compile(pattern, re.I)) for name, pattern in BRANDS]
    rows = []
    with open(sys.argv[1], newline="", encoding="utf-8") as f:
        for record in csv.DictReader(f):
            if record["Registry"] != "MA-L":
                continue
            for name, pattern in compiled:
                if pattern.search(record["Organization Name"]):
                    rows.append((record["Assignment"].upper(), name))
                    break
    rows.sort()
    with open("assets/oui/vendors.txt", "w", encoding="utf-8") as out:
        out.write("# MAC address prefixes (IEEE MA-L) of brands found in homes, from\n")
        out.write("# https://standards-oui.ieee.org/oui/oui.csv. Regenerate with the\n")
        out.write("# script in tool/make_vendor_list.py.\n")
        for prefix, name in rows:
            out.write(f"{prefix} {name}\n")
    counts = Counter(name for _, name in rows)
    print(f"{len(rows)} prefixes; " + ", ".join(f"{k} {v}" for k, v in counts.most_common(8)))


if __name__ == "__main__":
    main()
