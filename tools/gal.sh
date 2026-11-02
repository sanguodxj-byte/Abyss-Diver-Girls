#!/bin/bash
# usage: gal.sh view1 view2 ...  -> /tmp/shots/gallery_<view>.png
for v in "$@"; do
  SHOT="--gallery --view=$v" unshare -rm /workspace/work/tools/shoot.sh opengl3 >/dev/null 2>&1
  grep -E "SCRIPT ERROR|Parse Error" -A2 /tmp/xv/godot.log | head -6
  cp /tmp/shots/gallery_$v.png /tmp/shots/G_${v}_$(date +%H%M%S).png
done
ls -t /tmp/shots | head -5
