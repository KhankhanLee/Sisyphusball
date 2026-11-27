"""Renders one SVG per Sisyphe skin from sisyphe.svg.tmpl (colors only)."""
import pathlib, sys
here = pathlib.Path(__file__).parent
tmpl = (here / 'sisyphe.svg.tmpl').read_text()
skins = {
    'her-exile': dict(HAIR_LIGHT='#ffffff', HAIR='#e4e6ef', HAIR_SHADE='#a9acc4', HAIR_LINE='#7d7f9e',
                      CLOTH_LIGHT='#ffffff', CLOTH_SHADE='#d6cfe6', CLOTH_LINE='#8a7fa6', TRIM='#a58ad0',
                      EYE='#5b6fd6', EYE_LIGHT='#9fd0ff', GLOW='#b9a6ff'),
    'her-marble': dict(HAIR_LIGHT='#ffffff', HAIR='#eef0f4', HAIR_SHADE='#b9bcc9', HAIR_LINE='#8a8c9e',
                       CLOTH_LIGHT='#ffffff', CLOTH_SHADE='#e9e4da', CLOTH_LINE='#a3916a', TRIM='#d4af37',
                       EYE='#3d8fb5', EYE_LIGHT='#b7f0ff', GLOW='#ffe7a3'),
    'her-ember': dict(HAIR_LIGHT='#ffffff', HAIR='#dcdde6', HAIR_SHADE='#8d8fa6', HAIR_LINE='#4c4a5e',
                      CLOTH_LIGHT='#3a2630', CLOTH_SHADE='#170f14', CLOTH_LINE='#000000', TRIM='#ff8a3d',
                      EYE='#e0472b', EYE_LIGHT='#ffc06b', GLOW='#ff7a2e'),
}
out = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else here
for name, colors in skins.items():
    svg = tmpl
    for k, v in sorted(colors.items(), key=lambda kv: -len(kv[0])):
        svg = svg.replace('{' + k + '}', v)
    (out / f'{name}.svg').write_text(svg)
    print(out / f'{name}.svg')
