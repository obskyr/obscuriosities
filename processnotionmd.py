#!/usr/bin/env python3

"""Process a Jekyll post containing markdown output by Notion's export to be
more fitting for inclusion in a Jekyll post.
"""

import os
import re
import sys

from io import StringIO
from urllib.parse import urlparse, quote

def process(s, path):
    lines = s.splitlines()
    start = _skip_front_matter(lines)
    # If more processing needs to be done here, do a .tell() here and seek
    # back to this position every pass.
    _process_images(lines, start, path)

    return '\n'.join(lines) + '\n'

def _skip_front_matter(lines):
    # I dunno if Jekyll allows comments after the --- like plain YAML does,
    # but let's not handle that for now.
    if lines[0] == '---':
        for i, line in enumerate(lines[1:], 1):
            if line == '---':
                return i

SLUG_RE = re.compile(r"^[0-9]+-[0-9]+-[0-9]+-(?P<slug>.+)$")
IMAGE_RE = re.compile(r"^!\[.*]\((?P<src>.*)\)$")
def _process_images(lines, start=0, path=""):
    slug = quote(SLUG_RE.match(os.path.splitext(os.path.basename(path))[0]).group('slug'))
    for i, line in enumerate(lines[start:], start):
        m = IMAGE_RE.match(line)
        if m is None:
            continue
        src = m.group('src')
        parsed = urlparse(src)
        if not parsed.netloc and parsed.path.startswith('Export-'):
            src = f"{{{{ site.baseurl }}}}/assets/episodes/{slug}/images/{parsed.path.split('/', 1)[1]}"

        lines[i] = f'<img src="{src}">'

def main(*argv):
    script_name = os.path.basename(__file__)
    try:
        path = argv[0]
    except IndexError:
        print(f"Usage: {script_name} <path to markdown file>", file=sys.stderr)
        return 1

    with open(path, 'r', encoding='utf-8') as f:
        s = f.read()

    s = process(s, path)

    with open(path, 'w', encoding='utf-8') as f:
        f.write(s)

    print(f"Successfully processed \"{path}\"!")

    return 0

if __name__ == '__main__':
    sys.exit(main(*sys.argv[1:]))
