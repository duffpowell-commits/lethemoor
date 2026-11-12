import base64, json, sys
from PIL import Image
A='/home/claude/lethemoor/assets/art/'
SPRITE='canva_bearer64'
names=['floor_0','floor_1','floor_2','floor_3','wall_face_0','wall_top','thrall','lamp',SPRITE,SPRITE+'_glow']
art={n:'data:image/png;base64,'+base64.b64encode(open(A+n+'.png','rb').read()).decode() for n in names}
sizes={n:list(Image.open(A+n+'.png').size) for n in names}
g=Image.open(A+SPRITE+'_glow.png').convert('RGBA'); sx=sy=n=0
for y in range(g.height):
  for x in range(g.width):
    a=g.getpixel((x,y))[3]/255
    if a>0.1: sx+=(x+.5)*a; sy+=(y+.5)*a; n+=a
flame=[sx/n,sy/n]
room=open('/home/claude/lethemoor/rooms/quay_01.txt').read()
three=sys.argv[1]; out=sys.argv[2]
s=open('template.html').read()
for k,v in {'__THREE__':three,'__ART__':json.dumps(art),'__SIZES__':json.dumps(sizes),'__ROOM__':json.dumps(room),'__SPRITE__':json.dumps(SPRITE),'__FLAME__':json.dumps(flame)}.items():
  s=s.replace(k,v)
open(out,'w').write(s); print(out,len(s))
