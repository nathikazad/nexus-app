"""Build editable NX identity concepts. Requires Inkscape on PATH."""
from pathlib import Path
import xml.etree.ElementTree as ET
import subprocess
import math
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent
NS='{http://www.w3.org/2000/svg}'
card=ET.parse(ROOT/'nx_cards/design/brand/nx-cards-mark.svg').getroot()
letters=''.join(ET.tostring(p,encoding='unicode').replace('ns0:','').replace(':ns0','') for p in card.iter(NS+'path'))
def nx(scale=1,dx=0,dy=0):return f'<g transform="translate({dx} {dy}) scale({scale})">{letters}</g>'
def rect(x,y,w,h,r,c,extra=''):return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{c}" {extra}/>'
def path(d,c,extra=''):return f'<path d="{d}" fill="{c}" {extra}/>'
def line(d,c='#FFF',w=22):return path(d,'none',f'stroke="{c}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"')
def svg(body,title='NX identity',size='0 0 1024 1024'):return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{size}"><title>{title}</title>{body}</svg>'
def fan(shape,colors):return ''.join(f'<g transform="rotate({a} 512 760)">{shape(c)}</g>' for a,c in zip([-20,-10,0],colors))
apps=[]
# Receipt: the zigzag is part of each sheet, so all three are physically identical.
receipt='M340 232H684Q736 232 736 284V784L680 754L624 784L568 754L512 784L456 754L400 784L344 754L288 784V284Q288 232 340 232Z'
mark=fan(lambda c:path(receipt,c),['#86CBA9','#DCF3E7','#237953'])
mark+=nx(.78,114,8)+line('M365 604H654',w=20)+line('M365 652H520',w=20)+line('M616 652H654',w=20)
apps.append(('expense','Expense','Forest receipts','Receipts, totals, and everyday spending.','#16251E','#237953',mark))
# Clock: offset circular layers carry the same three-tone rhythm.
mark='<circle cx="450" cy="560" r="270" fill="#8DB7E9"/><circle cx="486" cy="536" r="270" fill="#E0EDFF"/><circle cx="522" cy="512" r="270" fill="#326AA8"/>'
for a in [0,90,180,270]:
 t=math.radians(a);x=522+209*math.sin(t);y=512-209*math.cos(t);xx=522+185*math.sin(t);yy=512-185*math.cos(t)
 mark+=line(f'M{x:.2f} {y:.2f}L{xx:.2f} {yy:.2f}',w=16)
mark+=line('M522 363V512L628 572',w=32)+'<circle cx="522" cy="512" r="24" fill="#FFFFFF"/>'
apps.append(('time','Time','Blue hours','A clear dial for time, rhythm, and focus.','#172231','#326AA8',mark))
# Book cover and page block: one complete volume repeated around the same pivot.
def book(c):return rect(280,228,456,568,55,c)
mark=fan(book,['#D89AAA','#F5DEE4','#963F5C'])
mark+=path('M335 228V713Q307 720 304 746V282Q304 243 335 228Z','#6D2943')
mark+=path('M340 716H720V774H340Q308 774 308 745Q308 716 340 716Z','#FFF0E7')
mark+=line('M349 746H695','#D8B5B5',7)+path('M617 716H662V810L640 792L617 810Z','#D9936B')
mark+=nx(.83,96,-27)
apps.append(('books','Books','Burgundy volumes','Clothbound covers, cream pages, a bookmark.','#2B1923','#963F5C',mark))
# Folded sheets: coherent angles and a visible dog-ear, unlike the uncut cards.
sheet='M344 224H590L736 370V744Q736 800 680 800H344Q288 800 288 744V280Q288 224 344 224Z'
mark=fan(lambda c:path(sheet,c),['#87C9C7','#DBF1EC','#237E83'])
mark+=path('M590 224V326Q590 370 634 370H736Z','#ACE0D7')
mark+=nx(.64,177,118)+line('M373 613H651',w=20)+line('M373 666H598',w=20)
apps.append(('docs','Docs','Teal pages','Folded pages for writing and connected ideas.','#16282A','#237E83',mark))
# Hypnosis: soft circular layers with one continuous inward spiral.
mark='<circle cx="450" cy="560" r="270" fill="#B7A0DA"/><circle cx="486" cy="536" r="270" fill="#EDE4F8"/><circle cx="522" cy="512" r="270" fill="#7953A3"/>'
points=[]
for i in range(241):
 t=i/240;angle=-math.pi/2+t*math.pi*3.5;r=181*(1-t)+15
 points.append((522+r*math.cos(angle),512+r*math.sin(angle)))
d='M'+' L'.join(f'{x:.2f} {y:.2f}' for x,y in points)
mark+=line(d,w=27)
apps.append(('hypnosis','Hypnosis','Violet stillness','A slow inward spiral for attention and reflection.','#251D31','#7953A3',mark))
# Cooking: nested pots with soft steam, in a warm saffron palette.
def pot(c):
 return path('M258 434H786V590Q786 752 624 752H420Q258 752 258 590Z',c)
mark='<g transform="translate(-66 40)">'+pot('#EAC279')+'</g><g transform="translate(-33 20)">'+pot('#FFF0CB')+'</g>'+pot('#AF791F')
mark+=line('M266 475H221Q190 475 190 509V548Q190 580 258 580','#AF791F',30)+line('M778 475H823Q854 475 854 509V548Q854 580 786 580','#AF791F',30)
mark+=line('M248 421H796','#FFF0CB',24)
mark+=line('M448 366C404 321 484 301 448 252','#FFF0CB',22)+line('M578 366C534 321 614 301 578 252','#FFF0CB',22)
mark+=nx(.59,215,252)
apps.append(('cooking','Cook','Saffron kitchen','A warm cooking pot, layered like a set of bowls.','#2A2315','#AF791F',mark))
# Projects: a tabbed folder, with a clear completion mark.
folder='M284 280H425Q445 280 461 299L487 331H708Q760 331 760 383V731Q760 783 708 783H284Q232 783 232 731V332Q232 280 284 280Z'
mark=fan(lambda c:path(folder,c),['#A2AFE2','#E3E8FB','#5363A7'])
mark+=line('M369 556L459 646L638 460',w=43)
apps.append(('projects','Projects','Indigo progress','A project folder and a decisive completion stroke.','#1D2134','#5363A7',mark))
# People: a personal address book, with a warm human silhouette.
mark=fan(lambda c:rect(280,228,456,568,55,c),['#EBA99B','#FBE4DB','#BC6552'])
mark+=rect(714,340,47,80,13,'#FBE4DB')+rect(714,449,47,80,13,'#EBA99B')+rect(714,558,47,80,13,'#FBE4DB')
mark+=path('M333 228V796H326Q280 796 280 741V283Q280 228 333 228Z','#914B41')
mark+='<circle cx="530" cy="437" r="66" fill="#FFF7F0"/>'
mark+=path('M408 662V632Q408 530 530 530Q652 530 652 632V662Z','#FFF7F0')
apps.append(('people','People','Coral connections','A personal address book with a friendly silhouette.','#2E201E','#BC6552',mark))
# Post: layered speech tiles for publishing short thoughts.
bubble='M314 260H726Q780 260 780 314V624Q780 678 726 678H484L354 782V678H314Q260 678 260 624V314Q260 260 314 260Z'
mark=fan(lambda c:path(bubble,c),['#DEA1BC','#FAE2EC','#AD4C79'])
mark+=nx(.66,179,31)+line('M370 573H667',w=20)
apps.append(('post','Post','Rose dispatch','A speech tile for publishing words and updates.','#2D1C26','#AD4C79',mark))
# Main: layered hexagons suggest the central hub of the NX collection.
hexagon='M488 235Q522 215 556 235L750 347Q784 367 784 407V631Q784 671 750 691L556 803Q522 823 488 803L294 691Q260 671 260 631V407Q260 367 294 347Z'
mark='<g transform="translate(-64 40)">'+path(hexagon,'#AEBCC5')+'</g><g transform="translate(-32 20)">'+path(hexagon,'#E7EEF0')+'</g>'+path(hexagon,'#536C7A')
mark+=nx(.92,47,38)
apps.append(('main','Nexus','Slate hub','A central hexagonal hub for voice, data, and devices.','#1B252B','#536C7A',mark))

def export(source,dest,width):subprocess.run(['inkscape',str(source),f'--export-filename={dest}',f'--export-width={width}'],check=True,stdout=subprocess.DEVNULL)
# Each app owns its editable masters and raster exports. Launcher assets are untouched.
for key,name,concept,desc,bg,accent,mark in apps:
 folder=ROOT/f'nx_{key}/design/brand';folder.mkdir(parents=True,exist_ok=True)
 prefix=f'nx-{key}'
 (folder/f'{prefix}-mark.svg').write_text(svg(mark,f'NX {name} — {concept}'))
 (folder/f'{prefix}-icon.svg').write_text(svg(rect(0,0,1024,1024,0,bg)+mark,f'NX {name} app icon'))
 export(folder/f'{prefix}-mark.svg',folder/f'{prefix}-mark.png',1024)
 for size in [1024,512,256,128,64,48,32]:export(folder/f'{prefix}-icon.svg',folder/f'{prefix}-icon-{size}.png',size)
 (folder/'README.md').write_text(f'# NX {name} — {concept}\n\n{desc}\n\nPart of the NX Cards visual family: flat layered geometry, a three-tone palette,\nand a dark icon background. Where used, the approved italic Nx is outlined\nvector artwork, with no font dependency.\n\nMain color: {accent}. Background: {bg}.\n\nThe mark SVG has a transparent background. The icon SVG is an opaque square;\nplatform rounding is left to the operating system. PNG exports are provided\nat 1024, 512, 256, 128, 64, 48, and 32 pixels.\n\nLauncher assets are wired into each existing platform target. After regenerating\nthese designs, run `python3 scripts/generate_app_icons.py` from mobile/.\n\nRegenerate using `python3 ../../../design/brand/generate_family.py` from this folder.\n')
# Contact sheet includes Cards as the approved reference, without editing its files.
cardmark=''.join(ET.tostring(x,encoding='unicode').replace('ns0:','').replace(':ns0','') for x in card if x.tag!=NS+'title')
allapps=[('cards','Cards','Orange recall','Approved reference.','#241810','#EA580C',cardmark)]+apps
def contact_sheet(entries,filename,title):
 rows=(len(entries)+2)//3
 height=250+rows*615
 board=rect(0,0,1800,height,0,'#FAF7F2')
 board+=f'<g font-family="sans-serif"><text x="76" y="76" font-size="17" letter-spacing="4" fill="#857366">NEXUS / A FAMILY OF APPS</text><text x="76" y="146" font-size="48" font-weight="bold" fill="#302016">{title}</text></g>'
 for i,(key,name,concept,desc,bg,accent,mark) in enumerate(entries):
  x=76+(i%3)*560;y=200+(i//3)*615
  board+=rect(x,y,528,580,28,'#FFFFFF')+rect(x+104,y+38,320,320,72,bg)
  board+=f'<g transform="translate({x+104} {y+38}) scale(.3125)">{mark}</g>'
  label='Nexus' if key=='main' else f'NX {name}'
  board+=f'<g font-family="sans-serif"><text x="{x+36}" y="{y+414}" font-size="31" font-weight="bold" fill="#302016">{label}</text><text x="{x+36}" y="{y+450}" font-size="18" fill="#857366">{concept}</text></g>'
  for j,size in enumerate([48,32]):
   sx=x+36+j*72;sy=y+484
   board+=rect(sx,sy,size,size,size*.22,bg)+f'<g transform="translate({sx} {sy}) scale({size/1024})">{mark}</g>'
  board+=f'<circle cx="{x+440}" cy="{y+510}" r="16" fill="{accent}"/>'
 board+=f'<text x="76" y="{height-30}" font-family="sans-serif" font-size="16" fill="#857366">Editable SVG masters · Purpose-specific silhouettes · Shared layering and proportions</text>'
 f=OUT/f'{filename}.svg';f.write_text(svg(board,title,f'0 0 1800 {height}'));export(f,OUT/f'{filename}.png',1800)
contact_sheet(allapps,'nx-app-family','Different purposes. A shared character.')
contact_sheet(apps[-5:],'nx-remaining-apps','The rest of the family.')
print(OUT/'nx-remaining-apps.png')
