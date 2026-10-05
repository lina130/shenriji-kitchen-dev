from __future__ import annotations
from pathlib import Path
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets'/'art'/'formal'/'ui'
OUT.mkdir(parents=True,exist_ok=True)
S=4

PAPER=(242,228,201,245)
PAPER_HI=(255,245,222,255)
INK=(59,46,41,235)
SAGE=(110,139,116,230)
HONEY=(216,166,83,235)
ROSE=(201,130,124,220)
SHADOW=(70,50,42,90)

def canvas(w,h):
    return Image.new('RGBA',(w*S,h*S),(0,0,0,0))

def finish(img,w,h):
    return img.resize((w,h),Image.Resampling.LANCZOS)

def rr(draw,box,r,fill=None,outline=None,width=1):
    draw.rounded_rectangle(tuple(v*S for v in box),radius=r*S,fill=fill,outline=outline,width=width*S)

def panel():
    w=h=96;im=canvas(w,h);d=ImageDraw.Draw(im)
    for off,alpha in [(4,28),(2,42)]:
        rr(d,(off,off,w-off,h-off),22,fill=(70,50,42,alpha))
    rr(d,(3,3,w-3,h-3),20,fill=PAPER)
    rr(d,(6,6,w-6,h-6),17,outline=(255,255,255,120),width=2)
    rr(d,(9,9,w-9,h-9),14,outline=SAGE,width=2)
    d.line((18*S,16*S,78*S,16*S),fill=(255,247,224,155),width=2*S)
    return finish(im,w,h)

def button(state):
    w,h=128,48;im=canvas(w,h);d=ImageDraw.Draw(im)
    fill=PAPER_HI if state=='hover' else PAPER
    border=HONEY if state!='disabled' else (160,150,132,160)
    yoff=2 if state=='pressed' else 0
    rr(d,(4,5+yoff,w-4,h-2+yoff),12,fill=SHADOW)
    rr(d,(3,3+yoff,w-3,h-4+yoff),11,fill=fill,outline=border,width=2)
    rr(d,(7,7+yoff,w-7,h-8+yoff),8,outline=(255,255,255,105),width=1)
    d.line((16*S,(11+yoff)*S,112*S,(11+yoff)*S),fill=(255,246,214,120),width=1*S)
    if state=='disabled':
        d.rectangle((0,0,w*S,h*S),fill=(90,82,72,58))
    return finish(im,w,h)

def slot(selected=False):
    w=h=72;im=canvas(w,h);d=ImageDraw.Draw(im)
    rr(d,(4,5,w-4,h-2),13,fill=(65,48,43,95))
    rr(d,(3,3,w-3,h-3),12,fill=(247,235,211,235),outline=ROSE if selected else SAGE,width=3 if selected else 2)
    rr(d,(7,7,w-7,h-7),9,outline=(255,255,255,110),width=1)
    d.line((14*S,13*S,58*S,13*S),fill=(255,247,224,120),width=1*S)
    return finish(im,w,h)

def title():
    w,h=320,100;im=canvas(w,h);d=ImageDraw.Draw(im)
    rr(d,(4,4,w-4,h-4),22,fill=(65,48,43,80))
    rr(d,(3,3,w-3,h-3),20,fill=(238,222,191,245),outline=HONEY,width=3)
    rr(d,(9,9,w-9,h-9),16,outline=SAGE,width=2)
    d.line((30*S,26*S,290*S,26*S),fill=(255,247,224,145),width=2*S)
    d.line((30*S,76*S,290*S,76*S),fill=(177,140,82,80),width=1*S)
    return finish(im,w,h)

def dialog():
    w,h=128,96;im=canvas(w,h);d=ImageDraw.Draw(im)
    rr(d,(4,4,w-4,h-4),18,fill=(255,244,218,245),outline=ROSE,width=3)
    rr(d,(9,9,w-9,h-9),14,outline=(255,255,255,90),width=1)
    d.polygon([(18*S,90*S),(30*S,90*S),(24*S,102*S)],fill=(255,244,218,245))
    return finish(im,w,h)

assets={
 'panel.png':panel(),
 'button.png':button('normal'),
 'button_hover.png':button('hover'),
 'button_pressed.png':button('pressed'),
 'button_disabled.png':button('disabled'),
 'slot.png':slot(False),
 'slot_selected.png':slot(True),
 'title.png':title(),
 'dialog.png':dialog(),
}
for name,img in assets.items():
    img.save(OUT/name)
print('WARM_UI_GENERATED',len(assets),OUT)
