#!/bin/bash
# Rebuilds Godot + Xvfb + lavapipe toolchain into /tmp (no root)
set -e
D=http://deb.debian.org/debian/pool/main
mkdir -p /tmp/xv && cd /tmp/xv
get(){ f=$(curl -s -m 30 $D/$1/ | grep -oE "$2" | sort -u | tail -1); [ -n "$f" ] || { echo "miss $2"; return; }; [ -f $f ] || curl -s -m 110 -O $D/$1/$f; dpkg -x $f root; }
get x/xorg-server 'xvfb_21.1.16-1.3\+deb13u[0-9]+_arm64.deb'
get libu/libunwind 'libunwind8_[^"]*arm64.deb'
get libx/libxfont 'libxfont2_[^"]*arm64.deb'
get x/xkeyboard-config 'xkb-data_[^"]*all.deb'
get x/x11-xkb-utils 'x11-xkb-utils_7.7\+9_arm64.deb'
get libx/libxkbfile 'libxkbfile1_[^"]*arm64.deb'
get m/mesa 'mesa-vulkan-drivers_25.0.7-2\+deb13u1_arm64.deb'
mkdir -p /tmp/usrbin && cp -a /usr/bin/. /tmp/usrbin/ 2>/dev/null || true
cp root/usr/bin/xkbcomp /tmp/usrbin/
if [ -x /workspace/work/bin/godot ]; then cp /workspace/work/bin/godot /tmp/Godot_v4.4.1-stable_linux.arm64; fi
if [ ! -x /tmp/Godot_v4.4.1-stable_linux.arm64 ]; then
  cd /tmp && curl -sL -m 110 -o g.zip https://github.com/godotengine/godot/releases/download/4.4.1-stable/Godot_v4.4.1-stable_linux.arm64.zip && unzip -qo g.zip && chmod +x Godot_v4.4.1-stable_linux.arm64
fi
echo SETUP_OK
