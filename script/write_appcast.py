#!/usr/bin/env python3
import email.utils
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path
root = Path(__file__).resolve().parent.parent
config = json.loads((root / 'release.json').read_text())
version = (root / 'VERSION').read_text().strip()
archive = root / f'dist/Panorama-{version}.zip'
signature = (root / 'dist/update-signature.txt').read_text()
match = re.search(r'sparkle:edSignature="([^"]+)"', signature)
if not match:
    raise SystemExit('Sparkle signing output did not include a signature')
ns = 'http://www.andymatuschak.org/xml-namespaces/sparkle'
ET.register_namespace('sparkle', ns)
rss = ET.Element('rss', version='2.0')
channel = ET.SubElement(rss, 'channel')
ET.SubElement(channel, 'title').text = 'Panorama updates'
item = ET.SubElement(channel, 'item')
ET.SubElement(item, 'title').text = f'Panorama {version}'
ET.SubElement(item, 'pubDate').text = email.utils.formatdate(usegmt=True)
ET.SubElement(item, f'{{{ns}}}version').text = version
ET.SubElement(item, f'{{{ns}}}shortVersionString').text = version
ET.SubElement(item, f'{{{ns}}}minimumSystemVersion').text = '14.0'
ET.SubElement(item, 'description').text = f'See the GitHub release notes for Panorama {version}.'
ET.SubElement(item, 'enclosure', {
    'url': f'https://github.com/{config["repository"]}/releases/download/v{version}/{archive.name}',
    'length': str(archive.stat().st_size), 'type': 'application/octet-stream',
    f'{{{ns}}}edSignature': match.group(1),
})
ET.indent(rss)
(root / 'dist/appcast.xml').write_bytes(ET.tostring(rss, encoding='utf-8', xml_declaration=True))
