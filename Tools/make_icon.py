import json, os, re, sys, colorsys, shutil
src, out = sys.argv[1], sys.argv[2]
HUE = 30 / 360  # orange

def orange_hex(m):
    h = m.group(1)
    r, g, b = (int(h[i:i+2], 16) / 255 for i in (0, 2, 4))
    hue, l, s = colorsys.rgb_to_hls(r, g, b)
    if s < 0.08:
        return m.group(0)  # grays and whites stay neutral
    r, g, b = colorsys.hls_to_rgb(HUE, l * 0.88, min(1, s * 1.35))
    return '#%02X%02X%02X' % tuple(round(c * 255) for c in (r, g, b))

def orange_rgb(r, g, b):
    hue, l, s = colorsys.rgb_to_hls(r, g, b)
    return colorsys.hls_to_rgb(HUE, l * 0.88, min(1, s * 1.35))

shutil.rmtree(out, ignore_errors=True)
os.makedirs(os.path.join(out, 'Assets'))
for f in os.listdir(src):
    if f.endswith('.svg'):
        svg = open(os.path.join(src, f)).read()
        svg = re.sub(r'#([0-9A-Fa-f]{6})\b', orange_hex, svg)
        open(os.path.join(out, 'Assets', f), 'w').write(svg)

def gray(w, a=1.0): return 'gray:%.5f,%.5f' % (w, a)
def p3(r, g, b, a): return 'display-p3:%.5f,%.5f,%.5f,%.5f' % (r, g, b, a)
def vertical(): return {'start': {'x': 0.5, 'y': 0}, 'stop': {'x': 0.5, 'y': 1}}
def tinted(value): return [{'appearance': 'tinted', 'value': value}]

def layer(image, name=None, **extra):
    d = {'image-name': image + '.svg', 'name': name or image, 'glass': True}
    d.update(extra)
    return d

overlay = p3(*orange_rgb(0.315, 0.678, 0.464), 0.78)

back_group = lambda layers: {
    'layers': layers,
    'shadow': {'kind': 'layer-color', 'opacity': 0.32},
    'specular': True,
    'lighting': 'individual',
    'translucency': {'enabled': False, 'value': 0.5},
}

icon = {
    'fill': {'linear-gradient': [gray(0.192), gray(0.078)], 'orientation': vertical()},
    'groups': [
        {   # front glyphs
            'layers': [
                layer('9.a.front.copy', **{'fill-specializations': tinted({'solid': gray(1)})}),
                layer('12.star.front', **{'fill-specializations': tinted({'linear-gradient': [gray(1), gray(0.8)], 'orientation': vertical()})}),
                layer('4.heart.front', **{'fill-specializations': tinted({'linear-gradient': [gray(1), gray(0.8)], 'orientation': vertical()})}),
            ],
            'shadow': {'kind': 'neutral', 'opacity': 0.4},
            'specular': True,
            'lighting': 'individual',
            'translucency': {'enabled': False, 'value': 0.5},
        },
        back_group([   # "a" back
            layer('8.a.spec.2', **{'blend-mode': 'multiply'}),
            layer('7.a.spec', **{'blend-mode': 'multiply', 'fill-specializations': tinted({'solid': gray(0.76)})}),
            layer('6.a.back.2'),
            layer('5.a.back.1', '5.a.back.1 tint', fill={'solid': overlay}),
            layer('5.a.back.1'),
        ]),
        back_group([   # star back
            layer('11.star.back.2.copy.2', **{'opacity-specializations': tinted(0.85)}),
            layer('10.star.back.copy.3', **{'opacity-specializations': tinted(0.85)}),
        ]),
        back_group([   # heart back
            layer('3.layer.29', **{'fill-specializations': tinted({'linear-gradient': [gray(0.729), gray(0.467)], 'orientation': {'start': {'x': 0.273, 'y': 0.130}, 'stop': {'x': 0.283, 'y': 0.805}}})}),
            layer('2.heart.back.2.copy', **{'fill-specializations': tinted({'linear-gradient': [gray(0.729), gray(0.467)], 'orientation': {'start': {'x': 0.273, 'y': 0.130}, 'stop': {'x': 0.283, 'y': 0.805}}})}),
        ]),
    ],
    'supported-platforms': {'squares': ['macOS']},
}
json.dump(icon, open(os.path.join(out, 'icon.json'), 'w'), indent=2)
print('ok', len(os.listdir(os.path.join(out, 'Assets'))))
