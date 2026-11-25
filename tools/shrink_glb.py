#!/usr/bin/env python3
"""Shrink the textures embedded in a GLB (Meshy ships 2K/4K JPEGs; a phone needs 1K).
usage: python3 tools/shrink_glb.py in.glb out.glb [size=1024] [quality=85]
Also strips any animations baked into the mesh file (clips ship separately, tools/bake_clips.gd)."""
import io, json, struct, sys
from PIL import Image

def main(src, dst, size=1024, q=85):
    d = open(src, 'rb').read()
    jl = struct.unpack('<I', d[12:16])[0]
    j = json.loads(d[20:20 + jl])
    b0 = 20 + jl
    bl = struct.unpack('<I', d[b0:b0 + 4])[0]
    binc = d[b0 + 8:b0 + 8 + bl]
    views = j['bufferViews']
    new_img = {}
    for i in j.get('images', []):
        v = views[i['bufferView']]
        raw = binc[v.get('byteOffset', 0):v.get('byteOffset', 0) + v['byteLength']]
        im = Image.open(io.BytesIO(raw))
        im = im.convert('RGBA' if im.mode in ('RGBA', 'LA', 'P') and 'A' in im.getbands() else 'RGB')
        if max(im.size) > size:
            im = im.resize((size, size * im.size[1] // im.size[0]), Image.LANCZOS)
        out = io.BytesIO()
        if im.mode == 'RGBA':
            im.save(out, 'PNG', optimize=True); i['mimeType'] = 'image/png'
        else:
            im.save(out, 'JPEG', quality=q, optimize=True); i['mimeType'] = 'image/jpeg'
        new_img[i['bufferView']] = out.getvalue()
    j.pop('animations', None)
    # rebuild the binary chunk view by view (keep order, 4-byte aligned)
    blob = bytearray()
    for k, v in enumerate(views):
        data = new_img.get(k)
        if data is None:
            data = binc[v.get('byteOffset', 0):v.get('byteOffset', 0) + v['byteLength']]
        while len(blob) % 4:
            blob.append(0)
        v['byteOffset'] = len(blob)
        v['byteLength'] = len(data)
        blob += data
    while len(blob) % 4:
        blob.append(0)
    j['buffers'][0]['byteLength'] = len(blob)
    js = json.dumps(j, separators=(',', ':')).encode()
    js += b' ' * ((4 - len(js) % 4) % 4)
    out = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(blob))
    out += struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(blob), 0x004E4942) + bytes(blob)
    open(dst, 'wb').write(out)
    print(f'{src} -> {dst}: {len(d)//1024} KB -> {len(out)//1024} KB')

if __name__ == '__main__':
    a = sys.argv[1:]
    main(a[0], a[1], int(a[2]) if len(a) > 2 else 1024, int(a[3]) if len(a) > 3 else 85)
