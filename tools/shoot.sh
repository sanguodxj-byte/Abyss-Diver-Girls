#!/bin/bash
# usage: unshare -rm shoot.sh [driver] ; driver = vulkan|opengl3
DRV=${1:-vulkan}
[ -d /tmp/xv/root ] || bash /workspace/work/tools/setup_render.sh >/dev/null 2>&1
mount --bind /tmp/usrbin /usr/bin
mkdir -p /tmp/.X11-unix /tmp/shots
L=/tmp/xv/root/usr/lib/aarch64-linux-gnu
LD_LIBRARY_PATH=$L /tmp/xv/root/usr/bin/Xvfb :99 -screen 0 1280x720x24 -xkbdir /tmp/xv/root/usr/share/X11/xkb -nolisten tcp > /tmp/xv/xvfb.log 2>&1 &
sleep 2
export DISPLAY=:99
export VK_ICD_FILENAMES=$(ls /tmp/xv/root/usr/share/vulkan/icd.d/lvp_icd*.json | head -1)
sed -i "s#\"library_path\": \"[^\"]*libvulkan_lvp.so\"#\"library_path\": \"$L/libvulkan_lvp.so\"#" $VK_ICD_FILENAMES
export LD_LIBRARY_PATH=$L
export LP_NATIVE_VECTOR_WIDTH=128 LP_NUM_THREADS=2
cd /workspace/work/salvage_crew
rm -f ~/.local/share/godot/app_userdata/*/salvage_save.json
timeout ${GT:-200} /tmp/Godot_v4.4.1-stable_linux.arm64 --path . --rendering-driver $DRV $EXTRA --resolution ${RES:-1280x720} -- ${SHOT:---shot} > /workspace/work/godot.log 2>&1; echo EXIT $?; tail -30 /tmp/xv/godot.log
kill %1
