"""Original top-down vector furniture and navigation art for the warm venue UI."""
from pathlib import Path
import math
OUT=Path(__file__).resolve().parents[1]/'assets'/'topdown'
OUT.mkdir(parents=True, exist_ok=True)
INK='#65472f'
def rect(x,y,w,h,fill,r=0,stroke=INK,sw=2):
 opacity = 1
 if len(fill)==9 and fill.startswith('#'):
  opacity=int(fill[-2:],16)/255
  fill=fill[:7]
 return f'<rect fill-opacity="{opacity}" x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'
def circle(x,y,r,fill,stroke=INK,sw=2):
 return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'
def line(x,y,a,b,color,sw=1):
 return f'<path d="M{x} {y} L{a} {b}" fill="none" stroke="{color}" stroke-width="{sw}"/>'
def svg(name,w,h,s):
 (OUT/(name+'.svg')).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}"><defs><linearGradient id="wood" x2="0" y2="1"><stop stop-color="#dcaf78"/><stop offset="1" stop-color="#bb8352"/></linearGradient><linearGradient id="green" x2="1" y2="1"><stop stop-color="#92995b"/><stop offset="1" stop-color="#65743e"/></linearGradient><linearGradient id="purple" x2="1" y2="1"><stop stop-color="#ab8aaf"/><stop offset="1" stop-color="#796180"/></linearGradient><linearGradient id="screen" x2="1" y2="1"><stop stop-color="#202c3c"/><stop offset="1" stop-color="#775e91"/></linearGradient></defs>{s}</svg>')
def plant(x,y,scale=1):
 s=circle(0,5,15,'#765a3b')+circle(0,0,15,'#e2c49a')+circle(0,0,11,'#6a6040')
 for i in range(7):
  a=i*math.tau/7
  s+=f'<ellipse cx="{math.cos(a)*13}" cy="{math.sin(a)*13-4}" rx="8" ry="18" transform="rotate({i*360/7} {math.cos(a)*13} {math.sin(a)*13-4})" fill="{["#6d8844","#8ba352","#536b35"][i%3]}" stroke="#435a30" stroke-width="1.5"/>'
 return f'<g transform="translate({x} {y}) scale({scale})">{s}</g>'
def sofa(x,y,w,h,color):
 s=rect(x+4,y+6,w,h,'#00000022',15,stroke='none')+rect(x,y,w,h,color,15)
 s+=rect(x+7,y+8,w-14,18,color,8)
 for k in range(3):
  s+=rect(x+12+k*(w-24)/3,y+30,(w-30)/3,h-40,color,9,sw=1.5)
 s+=rect(x+3,y+17,12,h-23,color,6)+rect(x+w-15,y+17,12,h-23,color,6)
 return s
for name,side,color in [('room_green',0,'url(#green)'),('room_purple',1,'url(#purple)')]:
 s=rect(0,0,410,340,'#a5754f',5)+rect(8,9,394,323,'#edcc9f',2)
 for y in range(10,331,22):
  s+=line(9,y,400,y,'#bd956780')
  for x in range(25+(y//22%2)*60,400,120):s+=line(x,y,x,y+22,'#bd956760')
 decor=rect(20,76,96,236,color,15)
 for y in [90,143,196,249]:decor+=rect(32,y,70,48,color,7,sw=1.2)
 decor+=rect(28,80,16,222,color,6)+rect(38,274,137,40,color,10)
 decor+=rect(140,155,113,123,'#86624733',12,stroke='none')+rect(135,148,113,123,'url(#wood)',12)
 decor+=rect(144,157,95,104,'#dcb181',8,sw=1)
 decor+=circle(188,182,19,'#fff2d6')
 for x,y,c in [(177,181,'#be7251'),(189,174,'#d69c3c'),(198,185,'#8c9b43'),(183,189,'#8c9b43')]:decor+=circle(x,y,6,c,sw=1)
 for x in [158,211]:
  decor+=rect(x,214,8,32,'#505759',4)+circle(x+4,215,6,'#969fa0',sw=1)
 decor+=rect(366,123,23,114,'#694b67',5)+rect(370,129,13,102,'url(#screen)',2)
 for y in [86,266]:
  decor+=rect(362,y,28,42,'#343b39',5)+circle(376,y+13,6,'#586165',sw=1)+circle(376,y+30,8,'#d0a45a',sw=1)
 decor+=plant(52,59,.65)
 decor+=rect(22,65,79,4,'#d8afe3',2,stroke='none')
 if side:decor='<g transform="translate(410 0) scale(-1 1)">'+decor+'</g>'
 s+=decor
 # Thick top-down timber wall; an opening at inner edge near bottom.
 s+=rect(0,0,410,12,'#8b6547',2)+rect(0,328,410,12,'#8b6547',2)
 edge=0 if side else 398
 s+=rect(edge,0,12,258,'#8b6547',2)+rect(edge,316,12,24,'#8b6547',2)
 outer=398 if side else 0
 s+=rect(outer,0,12,340,'#8b6547',2)
 # Open wooden door leaf is on room side, does not obstruct corridor.
 dx=14 if side else 365
 s+=rect(dx,258,31,7,'#d3a16b',2)+circle(dx+23,261,1.5,'#f9dda1',sw=0)
 svg(name,410,340,s)
# Spacious continuous tiled reception with desk open to right.
s=rect(0,0,980,410,'#f1dfbb',0,stroke='none')
for x in range(0,981,49):s+=line(x,0,x,410,'#d8c7a4')
for y in range(0,411,41):s+=line(0,y,980,y,'#d8c7a4')
s+=rect(10,0,960,14,'#936b49',2)+rect(10,0,14,410,'#936b49',2)+rect(956,0,14,410,'#936b49',2)
s+=rect(40,32,200,61,'#b2804e',5)
for x in range(50,225,28):s+=rect(x,39,20,25,'#84917a',3)+rect(x+5,43,9,3,'#eddbb6',1,sw=0)
s+=rect(48,80,185,8,'#88623f',1)
s+=rect(46,180,280,103,'#6f50332a',13,stroke='none')+rect(40,170,280,103,'url(#wood)',13)
for x in range(49,314,13):s+=line(x,219,x,263,'#a37648',1)
s+=rect(40,170,280,56,'#e0bc85',13)+rect(101,151,77,38,'#323c3d',5)+rect(131,189,18,9,'#43494a',2)
s+=rect(225,175,51,32,'#444f47',4)
for x in [233,246,259]:
 for y in [183,194]:s+=rect(x,y,8,6,'#e8dab0',1,sw=0)
s+=sofa(630,36,280,98,'url(#green)')+sofa(829,115,81,145,'url(#green)')
s+=rect(669,174,132,98,'#75513922',12,stroke='none')+rect(665,167,132,98,'url(#wood)',12)+circle(730,213,29,'#fff1d5',sw=1)+plant(730,208,.55)
for x,y in [(58,338),(911,342),(899,26)]:s+=plant(x,y,1)
# Walls at front, opening is completely clear.
s+=rect(10,398,370,12,'#936b49',2)+rect(600,398,370,12,'#936b49',2)
svg('lobby',980,410,s)
s=rect(0,0,980,290,'#b8b5a1',0,stroke='none')
for x in range(0,981,46):s+=line(x,0,x,260,'#8c93847a')
for y in range(0,261,36):s+=line(0,y,980,y,'#8c93847a')
for x in [45,125,205,285,620,700,780]:s+=rect(x,32,70,167,'#c3c1ad',2,stroke='#f1e4b7',sw=3)
# Plastic guard chair and tea table, not a booth.
s+=rect(875,102,59,76,'#5b773e',9)+rect(881,108,47,35,'#94ad59',7)
for x in [888,901,914]:s+=line(x,113,x,137,'#526b34',4)
s+=rect(880,144,48,32,'#91a959',6)+rect(818,142,46,48,'#8ea14c',6)+circle(839,162,12,'#f9e8c5')+circle(839,162,7,'#a5793c',sw=0)
s+=rect(0,251,980,39,'#555f5a',0,stroke='none')+line(0,253,980,253,'#efe6cc',4)
for x in range(40,980,160):s+=rect(x,272,72,4,'#e8dfbd',0,stroke='none')
svg('yard',980,290,s)
# Scooter viewed from above.
s=rect(15,9,38,111,'#272e2f',15)+circle(34,112,14,'#2d3434')+circle(34,16,12,'#2d3434')
s+=rect(7,23,54,81,'#b4543c',19)+rect(16,45,36,47,'#404747',12)+rect(13,25,42,20,'#e0c297',10)+rect(20,95,28,9,'#f5dfb9',3)+line(0,25,68,25,'#3d4540',5)+circle(3,18,6,'#e0e4d7')+circle(65,18,6,'#e0e4d7')
svg('scooter',68,130,s)
# Navigation icons share a restrained outlined visual language.
icons={
 'shop':rect(8,26,48,32,'#dcc58b',5)+rect(5,12,54,19,'#acbf77',5)+rect(15,39,14,19,'#91b7ad',2)+rect(35,38,14,12,'#f6e6b8',2),
 'staff':rect(15,12,38,48,'#e8d5a3',5)+rect(23,6,22,12,'#9da968',4)+line(23,28,45,28,INK,3)+line(23,39,45,39,INK,3)+line(23,50,40,50,INK,3),
 'stock':rect(7,26,29,30,'#c79759',3)+rect(31,10,27,31,'#d8ad6b',3)+rect(32,35,29,25,'#e2bc7d',3)+line(20,28,20,44,INK,3)+line(44,12,44,25,INK,3),
 'upgrade':'<path d="M14 9 L25 20 L20 27 L9 17 Q5 34 24 37 L45 59 Q54 65 59 55 Q62 50 55 45 L34 25 Q39 9 24 6 L28 17 L22 20Z" fill="#b8b6a0" stroke="'+INK+'" stroke-width="3"/>',
 'ledger':rect(10,9,38,49,'#e7c795',5)+line(19,22,38,22,INK,3)+line(19,33,38,33,INK,3)+line(19,44,32,44,INK,3)+circle(48,49,12,'#dcb34e')+line(48,42,48,56,INK,2),
}
for name,s in icons.items():svg('icon_'+name,68,68,s)
print('Generated',len(list(OUT.glob('*.svg'))),'original SVG assets')
