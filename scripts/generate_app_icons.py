#!/usr/bin/env python3
"""Generate launcher assets from approved design/brand SVGs.
Requires Python 3 + Pillow and Inkscape. Run from any directory.
No Flutter dependency or pubspec asset entry is needed for native launcher icons.
"""
from pathlib import Path
import argparse
import json
import re
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
NS='{http://www.w3.org/2000/svg}'
DENSITIES={'mdpi':1,'hdpi':1.5,'xhdpi':2,'xxhdpi':3,'xxxhdpi':4}
OUTPUTS=[]

def write(path,text):
 path.parent.mkdir(parents=True,exist_ok=True);path.write_text(text)

def save(im,path,size,opaque=False):
 path.parent.mkdir(parents=True,exist_ok=True)
 im=im.resize((size,size),Image.Resampling.LANCZOS)
 if opaque:im=im.convert('RGB')
 im.save(path);OUTPUTS.append((path,size,opaque))

def render(source,dest):
 subprocess.run(['inkscape',str(source),f'--export-filename={dest}','--export-width=1024'],check=True,stdout=subprocess.DEVNULL)
 return Image.open(dest).convert('RGBA')

def rounded(im,inset=0,radius=220):
 out=Image.new('RGBA',(1024,1024));side=1024-2*inset
 tile=im.resize((side,side),Image.Resampling.LANCZOS)
 mask=Image.new('L',(side,side));ImageDraw.Draw(mask).rounded_rectangle((0,0,side-1,side-1),radius=radius,fill=255)
 tile.putalpha(mask);out.alpha_composite(tile,(inset,inset));return out

def generate(app,tmp):
 key=app.name.removeprefix('nx_');brand=app/'design/brand'
 source=brand/f'nx-{key}-icon.svg';marksource=brand/f'nx-{key}-mark.svg'
 background=ET.parse(source).getroot().find(NS+'rect').get('fill')
 icon=render(source,tmp/'icon.png');mark=render(marksource,tmp/'mark.png')
 # iOS assets are opaque squares; iOS applies its own mask.
 for platform in ['ios','macos']:
  catalog=app/platform/'Runner/Assets.xcassets/AppIcon.appiconset'
  contents=catalog/'Contents.json'
  if not contents.exists():continue
  master=icon if platform=='ios' else rounded(icon,90,185)
  for entry in json.loads(contents.read_text())['images']:
   if 'filename' not in entry:continue
   size=round(float(entry['size'].split('x')[0])*float(entry['scale'].rstrip('x')))
   save(master,catalog/entry['filename'],size,platform=='ios')
  project=app/platform/'Runner.xcodeproj/project.pbxproj'
  assert 'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;' in project.read_text(),project
 # Adaptive Android layers are 108dp; keep artwork inside the 66dp safe circle.
 res=app/'android/app/src/main/res'
 if res.exists():
  alpha=mark.getchannel('A');pixels=alpha.load()
  radius=max(((x-512)**2+(y-512)**2)**.5 for y in range(1024) for x in range(1024) if pixels[x,y]>16)
  scale=min(1,300/radius);side=round(1024*scale)
  foreground=Image.new('RGBA',(1024,1024));foreground.alpha_composite(mark.resize((side,side),Image.Resampling.LANCZOS),((1024-side)//2,)*2)
  for density,factor in DENSITIES.items():
   save(rounded(icon),res/f'mipmap-{density}/ic_launcher.png',round(48*factor))
   save(foreground,res/f'drawable-{density}/ic_launcher_foreground.png',round(108*factor))
  write(res/'values/icon_colors.xml',f'<?xml version="1.0" encoding="utf-8"?>\n<resources><color name="ic_launcher_background">{background}</color></resources>\n')
  adaptive='<?xml version="1.0" encoding="utf-8"?>\n<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n    <background android:drawable="@color/ic_launcher_background"/>\n    <foreground android:drawable="@drawable/ic_launcher_foreground"/>\n</adaptive-icon>\n'
  write(res/'mipmap-anydpi-v26/ic_launcher.xml',adaptive)
  manifest=res.parent/'AndroidManifest.xml'
  assert 'android:icon="@mipmap/ic_launcher"' in manifest.read_text(),manifest
 # Web uses ordinary, maskable, Apple touch, and browser tab variants.
 web=app/'web'
 if web.exists():
  manifest=web/'manifest.json'
  data=json.loads(manifest.read_text()) if manifest.exists() else {'name':'Nexus','short_name':'Nexus','start_url':'.','display':'standalone','icons':[{'src':f'icons/Icon-{size}.png','sizes':f'{size}x{size}','type':'image/png'} for size in (192,512)]}
  for size in (192,512):
   if not any(i.get('purpose')=='maskable' and i.get('sizes')==f'{size}x{size}' for i in data['icons']):
    data['icons'].append({'src':f'icons/Icon-maskable-{size}.png','sizes':f'{size}x{size}','type':'image/png','purpose':'maskable'})
  for item in data['icons']:
   size=int(item['sizes'].split('x')[0]);save(icon,web/item['src'],size,True)
  data['background_color']=background;data['theme_color']=background
  write(manifest,json.dumps(data,indent=2)+'\n')
  save(icon,web/'icons/apple-touch-icon.png',180,True)
  save(rounded(icon),web/'favicon.png',32)
  # SVG favicon stays sharp at arbitrary browser UI scaling.
  svg=source.read_text();root=ET.fromstring(svg);root.find(NS+'rect').set('rx','220')
  write(web/'favicon.svg',ET.tostring(root,encoding='unicode'))
  index=web/'index.html';html=index.read_text()
  html=re.sub(r'<link\b[^>]*rel=[\"\']apple-touch-icon[\"\'][^>]*>', '<link rel="apple-touch-icon" sizes="180x180" href="icons/apple-touch-icon.png">',html)
  if 'href="favicon.svg"' not in html:
   html=html.replace('</head>','  <link rel="icon" type="image/svg+xml" href="favicon.svg">\n</head>')
  if 'name="theme-color"' not in html:html=html.replace('</head>',f'  <meta name="theme-color" content="{background}">\n</head>')
  else:html=re.sub(r'<meta\b[^>]*name="theme-color"[^>]*>',f'<meta name="theme-color" content="{background}">',html)
  write(index,html)
 print(f'{app.name}: '+', '.join(p for p in ['ios','android','macos','web'] if (app/p).exists()),flush=True)

if __name__=='__main__':
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('apps',nargs='*',help='Optional nx_cards, nx_books, etc.');args=parser.parse_args()
 apps=[ROOT/n for n in args.apps] if args.apps else sorted(p for p in ROOT.glob('nx_*') if (p/'design/brand'/f'{p.name.replace("_","-")}-icon.svg').exists())
 with tempfile.TemporaryDirectory(prefix='nx-app-icons-') as tmp:
  for app in apps:generate(app,Path(tmp))
 for path,size,opaque in OUTPUTS:
  with Image.open(path) as im:
   assert im.size==(size,size),(path,im.size)
   assert not opaque or im.mode=='RGB',(path,im.mode)
 print(f'Validated {len(OUTPUTS)} PNG assets across {len(apps)} apps.')
