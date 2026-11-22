"""Extract plain text from Confluence MIME .doc, Jira HTML .doc, .pptx and report OLE stream names.
Usage: python -I extract-docs.py <input_dir> <output_dir>
"""
import sys, os, re, email, zipfile, html
from email import policy
from html.parser import HTMLParser

class T(HTMLParser):
    BLOCK = {'p','div','br','li','tr','h1','h2','h3','h4','h5','h6','table','ul','ol','pre'}
    def __init__(self):
        super().__init__(); self.out=[]; self.skip=0
    def handle_starttag(self, tag, attrs):
        if tag in ('style','script'): self.skip+=1
        if tag=='li': self.out.append('\n- ')
        elif tag in ('td','th'): self.out.append(' | ')
        elif tag in self.BLOCK: self.out.append('\n')
        if tag=='img':
            a=dict(attrs); self.out.append(f"[img:{a.get('src','')[:80]}]")
    def handle_endtag(self, tag):
        if tag in ('style','script'): self.skip-=1
        if tag in self.BLOCK: self.out.append('\n')
    def handle_data(self, d):
        if not self.skip: self.out.append(d)

def html2text(h):
    p=T(); p.feed(h)
    t=''.join(p.out)
    t=re.sub(r'[ \t\xa0]+',' ',t); t=re.sub(r'\n\s*\n+','\n\n',t)
    return t.strip()

inp, outp = sys.argv[1], sys.argv[2]
os.makedirs(outp, exist_ok=True)
for name in sorted(os.listdir(inp)):
    path=os.path.join(inp,name)
    with open(path,'rb') as f: head=f.read(16)
    out=os.path.join(outp, re.sub(r'[^A-Za-z0-9._-]+','_',name)+'.txt')
    text=None
    if head.startswith(b'Date:') or head.startswith(b'MIME'):
        msg=email.message_from_binary_file(open(path,'rb'), policy=policy.default)
        parts=[]
        for part in msg.walk():
            ct=part.get_content_type()
            if ct=='text/html':
                parts.append(html2text(part.get_content()))
            elif ct.startswith('image/'):
                parts.append(f"[embedded image part: {part.get_filename()} {ct}]")
        text='\n\n'.join(parts)
    elif head.startswith(b'<!DOCTYPE') or head.startswith(b'<html'):
        text=html2text(open(path,encoding='utf-8',errors='replace').read())
    elif head.startswith(b'PK'):
        z=zipfile.ZipFile(path)
        slides=sorted([n for n in z.namelist() if re.match(r'ppt/slides/slide\d+\.xml',n)], key=lambda n:int(re.findall(r'\d+',n)[0]))
        buf=[]
        for s in slides:
            x=z.read(s).decode('utf8')
            paras=re.findall(r'<a:p>.*?</a:p>|<a:p .*?</a:p>',x,flags=re.S)
            lines=[''.join(re.findall(r'<a:t>(.*?)</a:t>',p,flags=re.S)) for p in paras]
            buf.append(f"=== {s} ===\n"+'\n'.join(html.unescape(l) for l in lines if l.strip()))
        notes=[n for n in z.namelist() if n.startswith('ppt/notesSlides/') and n.endswith('.xml')]
        for n in notes:
            x=z.read(n).decode('utf8')
            t=' '.join(re.findall(r'<a:t>(.*?)</a:t>',x,flags=re.S))
            if t.strip(): buf.append(f"=== {n} (notes) ===\n"+html.unescape(t))
        text='\n\n'.join(buf)
    elif head.startswith(b'\xd0\xcf\x11\xe0'):
        data=open(path,'rb').read()
        # crude: pull printable runs (UTF-16LE and ASCII)
        u16=re.findall(rb'(?:[\x20-\x7e\r\n\t]\x00){6,}',data)
        a8=re.findall(rb'[\x20-\x7e\r\n\t]{8,}',data)
        text="OLE2 compound file. Stream markers: "+', '.join(m for m in ['WordDocument','Workbook','PowerPoint Document','Book'] if m.encode('utf-16le') in data)+"\n\n--- UTF-16 runs ---\n"+'\n'.join(r.decode('utf-16le') for r in u16)+"\n\n--- ASCII runs ---\n"+'\n'.join(r.decode('ascii') for r in a8)
    else:
        text=f"unknown format, head={head!r}"
    open(out,'w',encoding='utf-8').write(text)
    print(name, '->', out, len(text))
