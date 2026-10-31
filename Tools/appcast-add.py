#!/usr/bin/env python3
"""Insert an <item> at the top of docs/appcast.xml.
Usage: appcast-add.py APPCAST VERSION BUILD URL LENGTH SIGNATURE"""
import sys
from datetime import datetime, timezone
from email.utils import format_datetime

path, version, build, url, length, sig = sys.argv[1:7]
item = f"""        <item>
            <title>Version {version}</title>
            <pubDate>{format_datetime(datetime.now(timezone.utc))}</pubDate>
            <sparkle:version>{build}</sparkle:version>
            <sparkle:shortVersionString>{version}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
            <enclosure url="{url}" length="{length}" type="application/octet-stream" sparkle:edSignature="{sig}"/>
        </item>
"""
src = open(path, encoding="utf-8").read()
if f"<sparkle:shortVersionString>{version}</sparkle:shortVersionString>" in src:
    print(f"appcast already has {version}, skipping")
    sys.exit(0)
marker = "<language>fr</language>\n"
if marker in src:
    src = src.replace(marker, marker + item, 1)
else:
    src = src.replace("</channel>", item + "    </channel>", 1)
open(path, "w", encoding="utf-8").write(src)
