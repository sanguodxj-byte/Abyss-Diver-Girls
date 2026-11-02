import sys
from PIL import Image
a=Image.open('/workspace/work/ref/man.jpg').convert('RGB'); b=Image.open(sys.argv[1]).convert('RGB')
h=540
a=a.resize((int(a.width*h/a.height),h)); b=b.resize((int(b.width*h/b.height),h))
o=Image.new('RGB',(a.width+b.width,h)); o.paste(a,(0,0)); o.paste(b,(a.width,0)); o.save(sys.argv[2],quality=88)
