import base64, json, sys
b64 = base64.b64encode(open('assets/sprites.png','rb').read()).decode()
meta = json.load(open('assets/sprites.json'))
scene = open('scene.js').read()
tpl = open('preview_tpl.html').read()
out = tpl.replace('__META__', json.dumps(meta)).replace('__SCENE__', scene).replace('__B64__', b64)
open(sys.argv[1] if len(sys.argv)>1 else 'build/preview.html','w').write(out)
print('ok', len(out))
