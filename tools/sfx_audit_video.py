#!/usr/bin/env python3
"""
生成分类音效试听审核视频（MP4，含文件名时码卡片与实时波形条，44.1kHz AAC 192k），
供 video 子代理逐一试听排查尖锐噪音、刺耳高频或混音削波。
"""
import os
import subprocess
import numpy as np
from scipy.io import wavfile
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
REVIEW_DIR = os.path.join(ROOT, "review")
SR = 44100
W, H = 720, 400
FPS = 10

CATEGORIES = {
    "audio_audit_weapons": [
        "wpn_mg_fire_01.wav", "wpn_mg_fire_02.wav",
        "wpn_shotgun_fire_01.wav", "wpn_shotgun_fire_02.wav",
        "wpn_flamer_ignite.wav", "wpn_flamer_loop.wav",
        "wpn_laser_fire_01.wav", "wpn_laser_fire_02.wav",
        "wpn_railgun_charge.wav", "wpn_railgun_fire_01.wav", "wpn_railgun_fire_02.wav",
        "wpn_arc_fire_01.wav", "wpn_arc_fire_02.wav",
        "wpn_mortar_fire_01.wav", "wpn_plasma_fire_01.wav",
        "wpn_drill_ignite.wav", "wpn_drill_loop.wav",
        "wpn_drone_fire_01.wav",
        "wpn_mg_reload.wav", "wpn_laser_reload.wav", "wpn_reload_done_01.wav", "wpn_empty_01.wav",
        "hit_metal_01.wav", "hit_chitin_01.wav", "hit_spit_01.wav",
        "explosion_01.wav", "explosion_02.wav",
    ],
    "audio_audit_mech_ui": [
        "step_biped_01.wav", "step_quad_01.wav", "step_quad_02.wav",
        "legs_tread_loop.wav", "mech_land_01.wav", "mech_slam_01.wav",
        "skill_dash_01.wav", "skill_ram.wav", "skill_leap.wav", "skill_missile.wav",
        "skill_shield.wav", "skill_decoy.wav", "skill_overdrive.wav", "skill_quake.wav",
        "skill_charge.wav", "skill_vent.wav", "skill_repair.wav", "skill_denied.wav",
        "shield_hit_01.wav", "shield_down.wav", "mech_hurt_01.wav", "mech_part_lost.wav",
        "mech_destroyed.wav", "mech_vent.wav",
        "energy_low.wav", "energy_emergency.wav", "energy_alarm_loop.wav", "energy_restored.wav",
        "ui_click_01.wav", "ui_hover.wav", "ui_confirm.wav", "ui_cancel.wav",
        "ui_tab.wav", "ui_open.wav", "ui_close.wav", "ui_denied.wav", "story_text.wav",
    ],
    "audio_audit_bugs_boss": [
        "bug_ling_appear_01.wav", "bug_ling_attack_01.wav", "bug_ling_hurt_01.wav", "bug_ling_death_01.wav",
        "bug_spitter_appear_01.wav", "bug_spitter_attack_01.wav", "bug_spitter_death_01.wav",
        "bug_beetle_appear_01.wav", "bug_beetle_attack_01.wav", "bug_beetle_death_01.wav",
        "bug_mantis_windup_01.wav", "bug_mantis_attack_01.wav",
        "bug_bomber_fuse_01.wav", "bug_bomber_attack_01.wav",
        "bug_crystal_bug_windup_01.wav", "bug_crystal_bug_attack_01.wav",
        "bug_burrower_erupt_01.wav", "bug_mech_beetle_attack_01.wav", "bug_mech_beetle_jam_01.wav",
        "bug_wasp_windup_01.wav", "bug_wasp_attack_01.wav",
        "bug_shielder_pulse_01.wav", "bug_mortar_launch_01.wav", "bug_ironjaw_attack_01.wav",
        "nest_loop.wav", "nest_spawn_01.wav", "nest_destroyed.wav",
        "boss_brood_roar_01.wav", "boss_brood_hatch_01.wav",
        "boss_king_roar_01.wav", "boss_king_stomp_01.wav", "boss_king_core_01.wav",
        "boss_queen_roar_01.wav", "boss_queen_wail_01.wav", "boss_phase_shift_01.wav",
    ],
    "audio_audit_world_ambient": [
        "loot_open_01.wav", "loot_open_safe.wav", "loot_reveal_rare.wav", "loot_take_01.wav",
        "cargo_full.wav", "cargo_overload.wav", "cargo_crash.wav",
        "drop_fall.wav", "drop_retro.wav", "drop_impact.wav",
        "extract_start.wav", "extract_cancel.wav", "extract_success.wav",
        "transport_arrive.wav", "transport_idle_loop.wav", "transport_depart.wav",
        "hub_detach.wav", "hub_dock_01.wav", "hub_assemble.wav", "hub_starter.wav",
        "grow_upgrade.wav", "grow_level.wav", "comm_open_01.wav",
        "decoy_deploy.wav", "drone_deploy.wav", "energy_cell_plug.wav",
        "flare_ignite.wav", "relay_unlock.wav", "web_pulse_01.wav",
        "supply_drop_land_01.wav", "sandstorm_start.wav", "sandstorm_end.wav", "weather_rain_loop.wav",
    ],
}


def load_stereo(fn):
    p = os.path.join(SFX_DIR, fn)
    sr, q = wavfile.read(p)
    x = q.astype(np.float64) / 32768.0
    if x.ndim == 1:
        x = np.stack([x, x], axis=1)
    return x


def build_combat_mix():
    """合成一段 4 秒真实交火混音（机枪连射 + 四足踏步 + 虫族受击 + 爆炸 + 电弧），验证叠加不刺耳不削波。"""
    n = int(4.0 * SR)
    out = np.zeros((n, 2))
    events = []
    for k in range(18):
        events.append((0.15 + k * 0.11, f"wpn_mg_fire_0{(k % 3) + 1}.wav", 0.55))
    for k in range(6):
        events.append((0.20 + k * 0.55, f"step_quad_0{(k % 4) + 1}.wav", 0.70))
    for t_e, fn, g in [
        (0.45, "hit_chitin_01.wav", 0.55),
        (0.95, "wpn_arc_fire_01.wav", 0.65),
        (1.35, "bug_ling_death_01.wav", 0.60),
        (1.85, "explosion_01.wav", 0.75),
        (2.35, "wpn_railgun_fire_01.wav", 0.75),
        (2.85, "hit_metal_01.wav", 0.60),
        (3.20, "boss_king_roar_01.wav", 0.65),
    ]:
        events.append((t_e, fn, g))
    for t_e, fn, g in events:
        if not os.path.exists(os.path.join(SFX_DIR, fn)):
            continue
        seg = load_stereo(fn) * g
        o = int(t_e * SR)
        m = min(len(seg), n - o)
        if m > 0:
            out[o:o + m] += seg[:m]
    pk = np.max(np.abs(out))
    if pk > 0.89:
        out *= 0.89 / pk
    return out


def render_card(title, filename, idx, total, t_cur, rms_db):
    img = Image.new("RGB", (W, H), (18, 22, 28))
    dr = ImageDraw.Draw(img)
    dr.rectangle([20, 20, W - 20, H - 20], outline=(68, 82, 98), width=2)
    try:
        f_lg = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 28)
        f_md = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 20)
        f_sm = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 16)
    except Exception:
        f_lg = ImageFont.load_default()
        f_md = f_lg
        f_sm = f_lg
    dr.text((40, 42), f"SFX AUDIT : {title}", fill=(160, 205, 240), font=f_md)
    dr.text((40, 96), f"[{idx:02d}/{total:02d}] {filename}", fill=(245, 248, 252), font=f_lg)
    dr.text((40, 154), f"TIME: {t_cur:05.2f}s", fill=(180, 195, 210), font=f_md)
    bar_w = int(np.clip((rms_db + 60.0) / 60.0, 0.0, 1.0) * (W - 80))
    dr.rectangle([40, 230, W - 40, 266], fill=(32, 38, 46), outline=(80, 95, 112))
    if bar_w >= 2:
        col = (85, 195, 130) if rms_db < -6.0 else (235, 185, 70)
        dr.rectangle([42, 232, 40 + bar_w, 264], fill=col)
    dr.text((40, 286), f"LEVEL: {rms_db:5.1f} dBFS", fill=(160, 175, 190), font=f_sm)
    return img.tobytes()


def make_video(name, file_list, include_mix=False):
    os.makedirs(REVIEW_DIR, exist_ok=True)
    gap = np.zeros((int(0.24 * SR), 2))
    chunks = []
    timeline = []  # (start_s, end_s, label)
    cur_s = 0.0
    for fn in file_list:
        if not os.path.exists(os.path.join(SFX_DIR, fn)):
            continue
        x = load_stereo(fn)
        chunks.append(x)
        dur = len(x) / SR
        timeline.append((cur_s, cur_s + dur, fn))
        cur_s += dur
        chunks.append(gap)
        cur_s += len(gap) / SR
    if include_mix:
        mix_x = build_combat_mix()
        chunks.append(mix_x)
        dur = len(mix_x) / SR
        timeline.append((cur_s, cur_s + dur, "COMBAT_OVERLAP_MIX_4S"))
        cur_s += dur
        chunks.append(gap)
        cur_s += len(gap) / SR

    audio = np.concatenate(chunks, axis=0)
    wav_tmp = os.path.join(REVIEW_DIR, f"_{name}_tmp.wav")
    mp4_out = os.path.join(REVIEW_DIR, f"{name}.mp4")
    q = np.round(np.clip(audio, -1.0, 1.0) * 32767.0).astype(np.int16)
    wavfile.write(wav_tmp, SR, q)

    total_frames = int(np.ceil(len(audio) / SR * FPS))
    cmd = [
        "ffmpeg", "-y", "-loglevel", "error",
        "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
        "-i", wav_tmp,
        "-c:v", "libx264", "-preset", "ultrafast", "-pix_fmt", "yuv420p",
        "-c:a", "aac", "-b:a", "192k", "-ar", str(SR),
        "-shortest", mp4_out,
    ]
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    t_idx = 0
    total_items = len(timeline)
    for fi in range(total_frames):
        t_cur = fi / FPS
        while t_idx + 1 < total_items and t_cur >= timeline[t_idx][1]:
            t_idx += 1
        label = timeline[t_idx][2] if timeline[t_idx][0] <= t_cur <= timeline[t_idx][1] else "(gap)"
        s0 = int(t_cur * SR)
        s1 = min(len(audio), s0 + SR // FPS)
        rms = float(np.sqrt(np.mean(audio[s0:s1] ** 2))) if s1 > s0 else 1e-6
        rms_db = 20.0 * np.log10(max(rms, 1e-6))
        proc.stdin.write(render_card(name, label, t_idx + 1, total_items, t_cur, rms_db))
    proc.stdin.close()
    ret = proc.wait()
    if os.path.exists(wav_tmp):
        os.remove(wav_tmp)
    if ret != 0:
        raise RuntimeError(f"ffmpeg failed for {name}: {ret}")
    print(f"[audit_video] {mp4_out} ({cur_s:.1f}s, {total_items} items)")


if __name__ == "__main__":
    for k, files in CATEGORIES.items():
        make_video(k, files, include_mix=(k == "audio_audit_weapons"))
