"""Run untrusted document parsing in a time/size-bounded subprocess, never in API workers."""
import json
import os
import sys
from pathlib import Path

if os.name == 'posix':
    import resource
    resource.setrlimit(resource.RLIMIT_AS, (768 * 1024 * 1024, 768 * 1024 * 1024))
    resource.setrlimit(resource.RLIMIT_CPU, (30, 30))

import fitz
from PIL import Image
Image.MAX_IMAGE_PIXELS = 40000000


def inspect(path, mime, max_pages):
    if mime == 'application/pdf':
        with fitz.open(path) as doc:
            if doc.needs_pass or doc.page_count < 1 or doc.page_count > max_pages:
                raise ValueError('Encrypted, empty or oversized PDF')
            return doc.page_count
    with Image.open(path) as img:
        if img.width * img.height > Image.MAX_IMAGE_PIXELS:
            raise ValueError('Image resolution exceeds limit')
        img.verify()
    return 1


def render(items, output):
    result = fitz.open()
    for item in items:
        source = fitz.open(item['path'])
        if source.needs_pass:
            raise ValueError('Encrypted PDF')
        if not source.is_pdf:
            converted = source.convert_to_pdf()
            source.close()
            source = fitz.open('pdf', converted)
        for number in item['pages']:
            page = source.load_page(number - 1)
            # Only raster pixels reach the printer: no JavaScript, links, forms or attachments.
            area = page.rect.width * page.rect.height
            if area <= 0 or area * (150 / 72) ** 2 > 24000000:
                raise ValueError('Page dimensions exceed limit')
            pix = page.get_pixmap(dpi=150, colorspace=fitz.csRGB if item['colour'] else fitz.csGRAY, alpha=False)
            image = pix.tobytes('png')
            for _ in range(item['copies']):
                target = result.new_page(width=page.rect.width, height=page.rect.height)
                target.insert_image(target.rect, stream=image)
                if len(result) > 1000:
                    raise ValueError('Too many rendered pages')
        source.close()
    result.save(output, garbage=4, deflate=True)
    count = len(result)
    result.close()
    if Path(output).stat().st_size > 100 * 1024 * 1024:
        raise ValueError('Rendered document exceeds limit')
    return count

if __name__ == '__main__':
    request = json.loads(Path(sys.argv[1]).read_text())
    try:
        if request['operation'] == 'inspect':
            pages = inspect(request['path'], request['mime'], request['max_pages'])
        else:
            pages = render(request['items'], request['output'])
        Path(sys.argv[2]).write_text(json.dumps({'pages': pages}))
    except Exception:
        Path(sys.argv[2]).write_text(json.dumps({'error': 'Invalid or unsupported document'}))
        sys.exit(1)
