#!/usr/bin/env python3

"""Process a Jekyll post containing markdown output by Notion's export to be
more fitting for inclusion in a Jekyll post.
"""

import os
import re
import sys

from html import escape
from io import StringIO
from itertools import chain
from urllib.parse import urlparse, quote

def process(s, path):
    lines = s.splitlines()
    front_matter, content = _split_front_matter(lines)
    # If more processing needs to be done here, do a .tell() here and seek
    # back to this position every pass.
    _process_images(lines, path)

    return '\n'.join(chain(front_matter, (line for line in lines if line is not None))) + '\n'

def _split_front_matter(lines):
    # I dunno if Jekyll allows comments after the --- like plain YAML does,
    # but let's not handle that for now.
    if lines[0] == '---':
        for i, line in enumerate(lines[1:], 1):
            if line == '---':
                return lines[:i + 1], lines[i + 1:]
    else:
        return [], lines

SLUG_RE = re.compile(r"^[0-9]+-[0-9]+-[0-9]+-(?P<slug>.+)$")
IMAGE_RE = re.compile(r"^!\[(?P<alt>.*)\]\((?P<src>.*)\)$")
IMAGES_STOP_RE = re.compile(r"^(?:(?:-{3,}|\_{3,}|\*{3,})|#{1,6} .+|[*-] .+)$")
def _process_images(lines, path=""):
    slug = quote(SLUG_RE.match(os.path.splitext(os.path.basename(path))[0]).group('slug'))
    cur_num_images = 0
    at_least_one_caption = False
    first_image_index = None
    prev_valid_index = None
    caption_added = None
    prev_line_blank = False
    for i, line in enumerate(lines):
        m = IMAGE_RE.match(line)
        if not line.strip():
            prev_line_blank = True
            continue
        if m:
            alt = m.group('alt')
            src = m.group('src')
            parsed = urlparse(src)
            if not parsed.netloc and parsed.path.startswith('Export-'):
                src = f"{{{{ site.baseurl }}}}/assets/episodes/{slug}/images/{parsed.path.split('/', 1)[1]}"

            alt = f'alt="{escape(alt, quote=True)}" ' if alt and alt != src else ""
            lines[i] = f'    <img {alt}src="{src}">'

            cur_num_images += 1
            if first_image_index is None:
                first_image_index = i
            prev_valid_index = i
            caption_added = False
        else:
            if prev_valid_index is None:
                prev_line_blank = False
                continue

            if IMAGES_STOP_RE.match(line) or caption_added or len(line) > 300:
                # Cap off images div if:
                # * An element that can't be a caption is encountered,
                # * A non-image element is encountered after a caption, or
                # * The line is too long to be a caption
                _cap_off(lines, first_image_index, prev_valid_index, cur_num_images, at_least_one_caption)
                
                cur_num_images = 0
                at_least_one_caption = False
                first_image_index = None
                prev_valid_index = None
                caption_added = None
            else:
                # It's a caption!
                lines[prev_valid_index] = '    <div class="image-container">\n    ' + lines[prev_valid_index]
                lines[i] = '        <div class="caption">' + lines[i] + '</div>\n    </div>'
                if prev_line_blank:
                    lines[i - 1] = None

                prev_valid_index = i
                at_least_one_caption = True
                caption_added = True
        prev_line_blank = False

    if prev_valid_index is not None:
        _cap_off(lines, first_image_index, prev_valid_index, cur_num_images, at_least_one_caption)

    return lines

def _cap_off(lines, start_index, end_index, num_images, captiony):
    classes = 'images'
    classes += ' captiony' if captiony else ''
    if num_images > 9:
        classes += ' four-wide'
    elif num_images > 2:
        classes += ' three-wide'
    lines[start_index] = f'<div class="{classes}">\n' + lines[start_index]
    lines[end_index] = lines[end_index] + "\n</div>"

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
