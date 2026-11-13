#!/usr/bin/env python3
"""Build two original, asset-free test ROMs. No proprietary SDK required.
Orbit Catch: Game Boy LR35902 code. Color Signal: NES 6502 code.
The tiny assemblers make every byte and hardware register easy to study.
"""
from pathlib import Path
import struct
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'Resources'/'Homebrew';OUT.mkdir(exist_ok=True)
class GB:
 def __init__(self):self.code=bytearray();self.labels={};self.fixups=[]
 def e(self,*b):self.code.extend(b)
 def label(self,n):self.labels[n]=0x150+len(self.code)
 def jp(self,n,op=0xC3):self.e(op,0,0);self.fixups.append((len(self.code)-2,n))
 def a(self,n):self.e(0x3E,n)
 def store(self,n):self.e(0xEA,n&255,n>>8)
 def load(self,n):self.e(0xFA,n&255,n>>8)
 def done(self):
  for i,n in self.fixups:self.code[i:i+2]=struct.pack('<H',self.labels[n])
  return self.code
# Five-bit rows of original, compact block lettering.
font={'A':[14,17,17,31,17,17,17],'B':[30,17,17,30,17,17,30],'C':[15,16,16,16,16,16,15],'E':[31,16,16,30,16,16,31],'F':[31,16,16,30,16,16,16],'G':[15,16,16,19,17,17,15],'H':[17,17,17,31,17,17,17],'I':[31,4,4,4,4,4,31],'L':[16,16,16,16,16,16,31],'N':[17,25,21,19,17,17,17],'O':[14,17,17,17,17,17,14],'R':[30,17,17,30,20,18,17],'S':[15,16,16,14,1,1,30],'T':[31,4,4,4,4,4,4],'0':[14,17,19,21,25,17,14],'1':[4,12,4,4,4,4,14],'2':[14,17,1,2,4,8,31],'3':[30,1,1,14,1,1,30],'4':[2,6,10,18,31,2,2],'5':[31,16,16,30,1,1,30],'6':[14,16,16,30,17,17,14],'7':[31,1,2,4,8,8,8],'8':[14,17,17,14,17,17,14],'9':[14,17,17,15,1,1,14]}
tiles=[bytes(16), bytes([0x18,0x18,0x3c,0x3c,0x7e,0x7e,0xff,0xff,0x7e,0x7e,0x3c,0x3c,0x18,0x18,0,0]),bytes([0,0,0,0,0,0,0x81,0x81,0xc3,0xc3,0xff,0xff,0x7e,0x7e,0,0])]
chars={}
for ch in '0123456789ABCEFGHILORST':
 chars[ch]=len(tiles);rows=font[ch]+[0];tiles.append(bytes(v for row in rows for v in (row<<1,row<<1)))
g=GB();g.e(0xF3,0x31,0xFE,0xFF)
g.label('waitlcd');g.e(0xF0,0x44,0xFE,144);g.jp('waitlcd',0xDA)
g.a(0);g.e(0xE0,0x40);g.a(0x0A);g.store(0);g.load(0xA000);g.e(0xFE,10);g.jp('bestok',0xDA);g.a(0)
g.label('bestok');g.store(0xC004)
for addr,value in [(0xC000,80),(0xC001,24),(0xC002,80),(0xC003,0),(0xC005,0)]:g.a(value);g.store(addr)
# Copy tile patterns; clear the background tile map.
g.e(0x21,0,0x80,0x11,0,0x10,0x01,(len(tiles)*16)&255,(len(tiles)*16)>>8)
g.label('tiles');g.e(0x1A,0x22,0x13,0x0B,0x78,0xB1);g.jp('tiles',0xC2)
g.e(0x21,0,0x98,0x01,0,4)
g.label('clear');g.a(0);g.e(0x22,0x0B,0x78,0xB1);g.jp('clear',0xC2)
for text,addr in [('ORBIT CATCH',0x9845),('SCORE',0x9A02),('BEST',0x9A0D),('LEFT  RIGHT',0x9A24)]:
 for i,ch in enumerate(text):g.a(chars.get(ch,0));g.store(addr+i)
for addr,value in [(0xFE00,24),(0xFE01,80),(0xFE02,1),(0xFE03,0),(0xFE04,128),(0xFE05,80),(0xFE06,2),(0xFE07,0)]:g.a(value);g.store(addr)
# Hide unused sprites.
g.e(0x21,8,0xFE,0x06,152);g.label('oam');g.a(0);g.e(0x22,0x05);g.jp('oam',0xC2)
g.a(0xE4);g.e(0xE0,0x47,0xE0,0x48);g.a(0);g.e(0xE0,0x42,0xE0,0x43);g.a(0x93);g.e(0xE0,0x40)
g.label('frame');g.e(0xF0,0x44,0xFE,144);g.jp('frame',0xDA)
# Update visible digits, then poll the directional pad.
g.load(0xC003);g.e(0xC6,chars['0']);g.store(0x9A09);g.load(0xC004);g.e(0xC6,chars['0']);g.store(0x9A12)
g.a(0x20);g.e(0xE0,0,0xF0,0,0xF0,0,0x47,0xCB,0x40);g.jp('left',0xC2)
g.load(0xC000);g.e(0xFE,152);g.jp('left',0xD2);g.e(0x3C,0x3C);g.store(0xC000)
g.label('left');g.e(0xCB,0x48);g.jp('move',0xC2);g.load(0xC000);g.e(0xFE,17);g.jp('move',0xDA);g.e(0x3D,0x3D);g.store(0xC000)
g.label('move');g.load(0xC000);g.store(0xFE05);g.load(0xC005);g.e(0x3C);g.store(0xC005);g.e(0xE6,1);g.jp('present',0xC2)
g.load(0xC001);g.e(0x3C);g.store(0xC001);g.e(0xFE,128);g.jp('present',0xDA)
# Catch if the horizontal difference is less than twelve pixels.
g.load(0xC002);g.e(0x47);g.load(0xC000);g.e(0x90);g.jp('positive',0xD2);g.e(0x2F,0x3C)
g.label('positive');g.e(0xFE,12);g.jp('resetstar',0xD2)
g.load(0xC003);g.e(0x3C,0xFE,10);g.jp('scoreok',0xDA);g.a(0)
g.label('scoreok');g.store(0xC003);g.e(0x47);g.load(0xC004);g.e(0xB8);g.jp('resetstar',0xD2);g.e(0x78);g.store(0xC004);g.store(0xA000)
g.label('resetstar');g.a(24);g.store(0xC001);g.e(0xF0,0x04,0xE6,127,0xC6,16);g.store(0xC002)
g.label('present');g.load(0xC001);g.store(0xFE00);g.load(0xC002);g.store(0xFE01)
g.label('leaveblank');g.e(0xF0,0x44,0xFE,144);g.jp('leaveblank',0xD2);g.jp('frame')
rom=bytearray(32768);rom[0x100:0x104]=bytes([0,0xC3,0x50,1]);rom[0x104:0x134]=bytes.fromhex('CEED6666CC0D000B03730083000C000D0008111F8889000EDCCC6EE6DDDDD999BBBB67636E0EECCCDDDC999FBBB9333E');rom[0x134:0x13F]=b'ORBIT CATCH';rom[0x147]=3;rom[0x148]=0;rom[0x149]=2;rom[0x14A]=1
code=g.done();assert len(code)<0x1000-0x150;rom[0x150:0x150+len(code)]=code;rom[0x1000:0x1000+len(tiles)*16]=b''.join(tiles)
x=0
for b in rom[0x134:0x14D]:x=(x-b-1)&255
rom[0x14D]=x;rom[0x14E:0x150]=struct.pack('>H',sum(rom)&65535);(OUT/'orbit-catch.gb').write_bytes(rom)
# NES: an original 6502/PPU color signal program with a moving star field.
# Arrow keys move the on-screen sprite.
prg=bytearray([0xEA]*16384);code=bytearray();labels={};fix=[]
def e(*b):code.extend(b)
def label(n):labels[n]=0xC000+len(code)
def jump(n,op=0x4C):e(op,0,0);fix.append((len(code)-2,n))
def lda(n):e(0xA9,n)
def sta(n):e(0x8D,n&255,n>>8)
label('reset');e(0x78,0xD8,0xA2,0xFF,0x9A);lda(0);sta(0x2000);sta(0x2001);sta(0x4010)
label('wait');e(0x2C,2,0x20);e(0x10,0xFB)
lda(0x3F);sta(0x2006);lda(0);sta(0x2006);e(0xA2,0)
label('palette');e(0xBD,0,0xC3);sta(0x2007);e(0xE8,0xE0,32,0xD0,0xF5)
lda(0x20);sta(0x2006);lda(0);sta(0x2006);e(0xA2,4,0xA0,0);lda(0)
label('clear');sta(0x2007);e(0xC8,0xD0,0xFA,0xCA,0xD0,0xF7)
# Fill a central word made of original block-font CHR tiles.
text='HELIO COLOR SIGNAL';tilemap={c:i+2 for i,c in enumerate(sorted(set(text)-{' '}))}
lda(0x21);sta(0x2006);lda(0x07);sta(0x2006)
for ch in text:lda(tilemap.get(ch,0));sta(0x2007)
lda(120);sta(0x200);lda(1);sta(0x201);lda(0);sta(0x202);lda(120);sta(0x203)
lda(0);sta(0x2005);sta(0x2005);lda(0);sta(0x2000);lda(0x1E);sta(0x2001)
label('loop');e(0x2C,2,0x20,0x10,0xFB);lda(2);sta(0x4014);lda(1);sta(0x4016);lda(0);sta(0x4016)
# Shift serial joypad bits into zero page 0, then move the player.
e(0xA2,8);label('read');e(0xAD,0x16,0x40,0x4A,0x26,0,0xCA,0xD0,0xF7)
for mask,addr,op in [(1,0x203,0xEE),(2,0x203,0xCE),(4,0x200,0xEE),(8,0x200,0xCE)]:
 e(0xA5,0,0x29,mask,0xF0,3,op,addr&255,addr>>8)
jump('loop')
for i,n in fix:code[i:i+2]=struct.pack('<H',labels[n])
assert len(code)<0x300;prg[:len(code)]=code;prg[0x300:0x320]=bytes([0x0F,0x21,0x31,0x30]*8);prg[-6:]=struct.pack('<HHH',labels['reset'],labels['reset'],labels['reset'])
chr=bytearray(8192);chr[16:32]=bytes([0x18,0x3c,0x7e,0xff,0x7e,0x3c,0x18,0]+[0]*8)
for ch,index in tilemap.items():
 rows=font.get(ch,[31,17,4,4,4,17,31])+[0];chr[index*16:index*16+8]=bytes(r<<1 for r in rows)
(OUT/'color-signal.nes').write_bytes(b'NES\x1a'+bytes([1,1])+bytes(10)+prg+chr)
print('Built Orbit Catch (GB) and Color Signal (NES).')
