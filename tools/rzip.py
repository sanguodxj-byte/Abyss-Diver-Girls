# 用 HTTP Range 从远程 zip 中只取需要的文件
import sys, struct, zlib, urllib.request
URL, NAMES, OUT = sys.argv[1], sys.argv[2].split(','), sys.argv[3]
def rng(a, b):
    r = urllib.request.Request(URL, headers={"Range": f"bytes={a}-{b}"})
    return urllib.request.urlopen(r, timeout=120).read()
req = urllib.request.Request(URL, method="HEAD")
size = int(urllib.request.urlopen(req).headers["Content-Length"])
tail = rng(size - 65536, size - 1)
i = tail.rfind(b"PK\x05\x06")
cd_size, cd_off = struct.unpack("<II", tail[i+12:i+20])
z64 = tail.rfind(b"PK\x06\x06")
if cd_off == 0xFFFFFFFF and z64 >= 0:
    cd_size, cd_off = struct.unpack("<QQ", tail[z64+40:z64+56])
cd = rng(cd_off, cd_off + cd_size - 1)
p = 0
while p < len(cd) and cd[p:p+4] == b"PK\x01\x02":
    meth, = struct.unpack("<H", cd[p+10:p+12])
    csz, usz = struct.unpack("<II", cd[p+20:p+28])
    nl, el, cl = struct.unpack("<HHH", cd[p+28:p+34])
    off, = struct.unpack("<I", cd[p+42:p+46])
    name = cd[p+46:p+46+nl].decode()
    print(name, usz)
    if any(name.endswith(n) for n in NAMES):
        h = rng(off, off + 29)
        hnl, hel = struct.unpack("<HH", h[26:30])
        data = rng(off + 30 + hnl + hel, off + 30 + hnl + hel + csz - 1)
        if meth == 8:
            data = zlib.decompress(data, -15)
        open(OUT + "/" + name.split("/")[-1], "wb").write(data)
        print("  -> saved", len(data))
    p += 46 + nl + el + cl
