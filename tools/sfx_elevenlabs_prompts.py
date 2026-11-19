# -*- coding: utf-8 -*-
"""
全量 215+ 音效 ID 的 ElevenLabs Sound Effects V3 提示词与生成参数表。
风格定位：重工业废土机甲战术射击（写实弹道、重型液压机械、几丁质异虫生物声学、精密物理终端微动），
禁止廉价卡通合成音与电子蜂鸣。
格式：sid -> (text, gen_duration_sec, prompt_influence)
其中 gen_duration_sec 满足 ElevenLabs API [0.5, 30.0] 范围，极短瞬态按 0.5s 生成后由母带精确裁切至目标 dur。
"""

VARIANT_MODS = [
    "",
    ", slightly lower pitch and heavier mechanical resonance, distinct transient",
    ", slightly tighter and crisper acoustic attack, distinct texture",
    ", deeper chest impact with gritty dry surface detail, alternate take",
]


def prompt_for(sid: str, variant_idx: int) -> tuple[str, float, float]:
    if sid not in PROMPTS:
        raise KeyError(f"Missing prompt definition for SFX ID: {sid}")
    base_text, dur_s, infl = PROMPTS[sid]
    mod = VARIANT_MODS[variant_idx % len(VARIANT_MODS)]
    return base_text + mod, float(dur_s), float(infl)


PROMPTS = {
    # ================================================================ 武器与换弹
    "wpn_mg_fire": (
        "Single heavy 30mm mech autocannon shot, dry supersonic crack, punchy propellant blast, heavy metallic breech bolt clack, realistic battlefield recording, zero reverb tail",
        0.5, 0.50,
    ),
    "wpn_shotgun_fire": (
        "Single heavy mech flak shotgun cannon blast, massive low-end muzzle boom, supersonic pellet roar, heavy steel breech recoil and shell clatter",
        1.25, 0.45,
    ),
    "wpn_flamer_ignite": (
        "Heavy industrial napalm flamethrower ignition, pressurized fuel valve clunk, sharp piezo spark click, sudden pressurized liquid fire whoosh and deep combustion roar",
        0.9, 0.45,
    ),
    "wpn_flamer_loop": (
        "Continuous heavy military flamethrower roaring fire jet, turbulent burning fuel pressure, roaring combustion hiss, steady seamless loop",
        2.5, 0.45,
    ),
    "wpn_laser_fire": (
        "Single focused high-energy industrial thermal laser discharge, crisp capacitor snap, ionized air crackle and tight optical beam pulse, realistic sci-fi weapon, no cartoon pew",
        0.7, 0.50,
    ),
    "wpn_railgun_charge": (
        "Heavy electromagnetic railgun charging sequence, metallic breech locking clunk, rising turbine capacitor whine, magnetic rail hum and high-voltage arc crackles",
        1.4, 0.45,
    ),
    "wpn_railgun_fire": (
        "Massive hypersonic electromagnetic railgun shot, thunderous mach sonic boom cracking the air, heavy sub-bass punch, metallic rail ring and venting steam",
        0.95, 0.48,
    ),
    "wpn_arc_fire": (
        "High-voltage tactical arc cannon discharge, sharp thunder-like air ionization snap, violent electric whip crackle and transformer hum",
        0.65, 0.48,
    ),
    "wpn_mortar_fire": (
        "Heavy mech mortar tube firing thump, deep hollow steel barrel boom, heavy baseplate clank and outgoing artillery shell whoosh",
        0.9, 0.45,
    ),
    "wpn_drill_ignite": (
        "Heavy siege rock drill startup, massive steel clutch engagement clank, hydraulic motor spinning up with gritty metal-on-stone torque roar",
        0.95, 0.45,
    ),
    "wpn_drill_loop": (
        "Continuous heavy industrial mining rock drill grinding into stone and armor, diesel hydraulic motor rumble with tungsten teeth scraping metal, seamless loop",
        2.0, 0.45,
    ),
    "wpn_plasma_fire": (
        "Heavy military plasma cannon discharge, magnetic containment chamber thump, superheated ionized gas whoosh and sharp thermal pop",
        0.75, 0.45,
    ),
    "wpn_drone_fire": (
        "Single compact tactical defense drone pulse rifle shot, crisp mechanical bolt snap and tight electromagnetic crack, dry clean transient",
        0.5, 0.50,
    ),
    "wpn_mg_reload": (
        "Heavy mech autocannon reload sequence, steel ammo box latch release, heavy belt feed ratchet and firm metallic bolt rack lock",
        1.75, 0.42,
    ),
    "wpn_shotgun_reload": (
        "Heavy mech shotgun cannon reload, massive breech unlatch, thick brass shells sliding into chamber and heavy steel pump lock slam",
        2.15, 0.42,
    ),
    "wpn_flamer_reload": (
        "Industrial flamethrower fuel canister swap, pressurized hose hiss release, empty steel tank unclamp and new heavy tank lock with valve seal",
        2.35, 0.42,
    ),
    "wpn_laser_reload": (
        "Heavy thermal laser power cell reload, ejector latch click, burnt battery cartridge hiss drop and new capacitor module locking in with brief hum",
        1.95, 0.42,
    ),
    "wpn_reload_done": (
        "Crisp mechanical weapon bolt lock ready click, solid machined steel slide snap into battery, tight dry mechanical confirmation",
        0.5, 0.50,
    ),
    "wpn_empty": (
        "Dry metallic firing pin click on empty heavy autocannon chamber, sharp crisp mechanical misfire snap, no echo",
        0.5, 0.55,
    ),

    # ================================================================ 命中与爆炸
    "hit_metal": (
        "Single ballistic bullet impact ricochet on thick steel armor plate, sharp metallic ping crack and crisp metal dent thud, dry immediate transient",
        0.65, 0.50,
    ),
    "hit_chitin": (
        "Single bullet impact on hard insectoid chitin carapace, crisp bone-shell crack mixed with dense wet organic thud, dry immediate impact",
        0.55, 0.50,
    ),
    "hit_spit": (
        "Corrosive alien acid glob splattering on hot metal armor, wet sticky impact splash followed by sizzling chemical fizz",
        0.85, 0.45,
    ),
    "explosion": (
        "Massive realistic military artillery explosion outdoors, instant sharp concussive blast wave, deep chest-rattling sub boom, flying dirt and metallic shrapnel debris tail",
        2.8, 0.45,
    ),
    "mech_slam": (
        "Ten-ton armored mech slamming heavily into steel and concrete, massive hydraulic crash, sub-bass ground shockwave and screeching metal impact",
        1.45, 0.45,
    ),

    # ================================================================ 机甲底盘与动作
    "step_biped": (
        "Single heavy armored biped mech footstep on gravel and concrete, crisp solid steel footpad clunk, tight gravel crunch and hydraulic strut snap, ultra-short dry isolated step",
        0.5, 0.55,
    ),
    "step_quad": (
        "Single sharp spider-mech steel claw leg tap on rocky ground, crisp metallic spike strike with tiny stone crunch, ultra-short dry isolated step",
        0.5, 0.55,
    ),
    "legs_tread_loop": (
        "Continuous heavy armored tank treads rolling over dirt and gravel, steady metallic track links clanking with deep diesel turbine rumble, seamless loop",
        2.0, 0.45,
    ),
    "mech_land": (
        "Heavy armored mech landing hard from jump boost, deep hydraulic shock absorber compression thump, metallic joint settle and ground gravel crunch",
        0.72, 0.48,
    ),

    # ================================================================ 技能与护盾
    "skill_dash": (
        "Heavy mech thruster dash ignition, mechanical valve pop followed by fierce short rocket thruster jet blast and air shear whoosh",
        0.72, 0.48,
    ),
    "skill_ram": (
        "Heavy tracked mech ramming charge startup, diesel engine surge roar, bulldozer plow steel drop slam and grinding forward momentum",
        0.95, 0.45,
    ),
    "skill_leap": (
        "Spider-mech hydraulic leap takeoff, high-pressure pneumatic pistons firing downward, earth kick crunch and upward air rush",
        0.80, 0.45,
    ),
    "skill_missile": (
        "Mech shoulder missile pod salvo launch, armor hatch clack open followed by rapid sequence of four crisp rocket whoosh ignitions",
        0.95, 0.45,
    ),
    "skill_shield": (
        "Industrial tactical energy deflector shield activation, mechanical relay snap, deep electromagnetic bass swell and shimmering plasma barrier expansion",
        0.90, 0.45,
    ),
    "skill_decoy": (
        "Tactical acoustic decoy launcher pop, compact metallic tube eject thump and electronic beacon pulse startup hum",
        0.85, 0.45,
    ),
    "skill_overdrive": (
        "Mech reactor overdrive limiter release, heavy breaker slam, accelerating turbine spool-up, furnace roar and electrical arc surges",
        1.20, 0.45,
    ),
    "skill_quake": (
        "Heavy mech seismic ground stomp shockwave, massive pile-driver steel impact cracking concrete and deep earth tremor rumble",
        1.10, 0.45,
    ),
    "skill_charge": (
        "Mech capacitor rapid energy surge, magnetic coil whine rising in power with sharp electrical discharge snaps",
        0.95, 0.45,
    ),
    "skill_vent": (
        "Mech emergency thermal steam vent purge, heavy pressure valve snap open followed by violent high-pressure white steam jet hiss",
        0.95, 0.45,
    ),
    "skill_repair": (
        "Mech field nanite repair assembly burst, crisp mechanical tool clicks, brief arc welding sputter and pressurized sealant spray",
        1.00, 0.45,
    ),
    "skill_emp": (
        "Heavy electromagnetic pulse discharge blast, deep sub-bass coil thump, sharp air snap and descending magnetic power-drain whoosh",
        1.10, 0.45,
    ),
    "skill_cloak": (
        "Tactical optical camo cloak engagement, camera shutter click, quiet relay snap and low-frequency phase hum fading into air rush",
        0.85, 0.45,
    ),
    "skill_guard": (
        "Heavy mech fortress guard armor lock, hydraulic servo slide followed by massive interlocking steel shield plates slamming shut",
        0.85, 0.45,
    ),
    "skill_jam": (
        "Electronic warfare jammer pulse emission, sharp trigger clack, crackling radio static burst and harsh electromagnetic buzz",
        0.95, 0.45,
    ),
    "skill_denied": (
        "Crisp mechanical double-click lockout switch on tactical cockpit console, stiff metallic button dead-stop clack, zero electronic synth beep",
        0.5, 0.55,
    ),
    "shield_up": (
        "Tactical energy shield power up, heavy capacitor relay engage, expanding electromagnetic barrier hum and air shimmer",
        0.90, 0.45,
    ),
    "shield_hit": (
        "Ballistic impact deflecting off taut energy barrier shield, crisp electric crackle and resonant force-field thud, instant transient",
        0.5, 0.50,
    ),
    "shield_down": (
        "Tactical energy shield collapse and power down, descending electromagnetic capacitor discharge fizz and dead relay click",
        0.85, 0.45,
    ),
    "barrier_deploy": (
        "Tactical extraction slow-field barrier pylons slamming into ground, heavy hydraulic spike lock and resonating cyan force-field hum",
        1.10, 0.45,
    ),
    "coolant_vent": (
        "Cryogenic coolant canister injection into mech reactor, sharp lock valve twist, cold pressurized liquid gas rushing through pipes with icy steam hiss",
        1.00, 0.45,
    ),

    # ================================================================ 机甲状态与消耗品
    "mech_hurt": (
        "Internal cockpit view of heavy armor taking direct ballistic hit, muffled dull metal hull thud, structural shudder and tiny bolt rattle",
        0.52, 0.50,
    ),
    "mech_part_lost": (
        "Catastrophic mech limb module severed, violent shearing metal tear, pneumatic line burst hiss and dull hydraulic power drop",
        1.20, 0.45,
    ),
    "mech_destroyed": (
        "Armored mech reactor catastrophic meltdown and shutdown, internal explosion boom, collapsing steel chassis crash, dying turbine spin-down and sparks",
        2.60, 0.42,
    ),
    "mech_vent": (
        "Drop-pod mech standing up and purging hydraulic steam, crisp piston clank and pressurized exhaust release hiss",
        1.10, 0.45,
    ),
    "energy_low": (
        "Subtle mechanical cockpit warning claxon click and dying reactor capacitor dip, industrial analog warning signal, restrained",
        0.75, 0.48,
    ),
    "energy_emergency": (
        "Mech main reactor emergency shutdown, heavy breaker trip slam, turbine spinning down and harsh mechanical reserve relay engage",
        1.20, 0.45,
    ),
    "energy_alarm_loop": (
        "Restrained deep low-pitch industrial analog cockpit warning thump, muted mechanical relay click and warm low-frequency diesel reserve pulse, no high-pitched whistle, seamless loop",
        1.50, 0.48,
    ),
    "energy_restored": (
        "Mech reactor power restored, solid main breaker engage clank, rising auxiliary turbine hum and steady system lock",
        1.10, 0.45,
    ),
    "use_fuel_cell": (
        "Plugging heavy fuel cell battery into mech slot, solid metal slide, heavy bayonet lock twist and energizing reactor hum",
        1.00, 0.45,
    ),
    "use_repair_kit": (
        "Field mech emergency repair kit activation, tool latch snap, rapid pneumatic rivet fastening and welding torch sparks",
        1.20, 0.45,
    ),
    "use_beacon": (
        "Orbital extraction radio beacon activation, heavy metal toggle switch flip, antenna spring pop and brief encrypted telemetry burst",
        1.10, 0.45,
    ),
    "use_denied": (
        "Dry mechanical empty latch clack on tactical supply console, stiff double-thud rejection switch, no synth beep",
        0.5, 0.55,
    ),

    # ================================================================ 基础虫族与虫巢
    "bug_ling_appear": (
        "Agile alien insectoid crawler bursting out of dirt, quick dry chitin clicking, gravel scramble and sharp predatory hiss",
        0.55, 0.45,
    ),
    "bug_ling_windup": (
        "Small alien insectoid predator tensing to pounce, rapid mandible clicking and taut wet breathing hiss",
        0.5, 0.45,
    ),
    "bug_ling_attack": (
        "Fast alien blade-claw bug slashing strike, sharp chitin scythe whoosh through air and vicious mandible snap",
        0.5, 0.48,
    ),
    "bug_ling_hurt": (
        "Small alien insectoid shriek in pain, wet chitin crunch and sharp guttural chittering squeal",
        0.5, 0.48,
    ),
    "bug_ling_death": (
        "Small alien insectoid bug crushed and dying, wet organic splat, cracking shell and deflating hiss",
        0.72, 0.45,
    ),
    "bug_spitter_appear": (
        "Acid-spitting alien insectoid emerging, wet gurgling throat sac inflation and heavy chitin leg scuttling",
        0.70, 0.45,
    ),
    "bug_spitter_windup": (
        "Alien acid spitter bug charging venom sac, bubbling corrosive liquid gurgle and pressurized hiss buildup",
        0.65, 0.45,
    ),
    "bug_spitter_attack": (
        "Alien bug spitting pressurized acid glob, wet forceful throat projection splat and chemical air hiss",
        0.65, 0.48,
    ),
    "bug_spitter_hurt": (
        "Acid-filled alien insectoid injured, wet membrane rupture squeal and bubbling organic hiss",
        0.55, 0.48,
    ),
    "bug_spitter_death": (
        "Acid-spitting alien bug bursting upon death, wet pressurized sac pop, acid splatter and dying gurgle",
        0.95, 0.45,
    ),
    "bug_beetle_appear": (
        "Heavy armored alien beetle emerging, deep scraping chitin plates, heavy stomping legs and low guttural thorax rumble",
        0.90, 0.45,
    ),
    "bug_beetle_windup": (
        "Giant armored beetle raising heavy crushing pincers, creaking thick chitin armor and deep aggressive throat growl",
        0.80, 0.45,
    ),
    "bug_beetle_attack": (
        "Heavy armored beetle slamming giant pincers, dense bone-armor crunch, crushing impact thud and air gust",
        0.85, 0.45,
    ),
    "bug_beetle_hurt": (
        "Armored alien beetle struck on thick carapace, hollow hard shell knock and angry low insectoid grunt",
        0.65, 0.48,
    ),
    "bug_beetle_death": (
        "Heavy armored alien beetle collapsing dead, cracking heavy carapace plates, wet internal collapse and heavy ground thud",
        1.25, 0.45,
    ),
    "nest_loop": (
        "Underground biomechanical alien foundry nest throbbing ambient loop, deep rhythmic organic pulse mixed with faint furnace hum and wet bubbling, seamless loop",
        4.60, 0.40,
    ),
    "nest_spawn": (
        "Alien biomechanical hive pod rupturing open to birth creature, tearing wet membrane rip, pressurized hiss and chitinous skitter",
        1.10, 0.42,
    ),
    "nest_hurt": (
        "Bullet damage hitting biomechanical alien nest structure, heavy metal-flesh thud and strained organic groan",
        0.75, 0.45,
    ),
    "nest_destroyed": (
        "Biomechanical alien foundry nest collapsing in structural destruction, inner furnace pop, shattering chitin shell and wet organic rupture",
        2.60, 0.42,
    ),

    # ================================================================ 进阶变异虫族
    "bug_mantis_appear": (
        "Predatory mantis alien bug snapping sharp scythe blades together, agile chitin rattle and aggressive hiss",
        0.65, 0.45,
    ),
    "bug_mantis_windup": (
        "Alien mantis creature coiling back to strike, metallic-like chitin blade scrape and tense hissing rasp",
        0.55, 0.45,
    ),
    "bug_mantis_attack": (
        "Alien mantis double scythe slash lunge, razor air whoosh, sharp twin chitin blade slice and snappy click",
        0.55, 0.48,
    ),
    "bug_mantis_hurt": (
        "Predatory alien mantis wounded, sharp agitated insectoid screech and cracked shell click",
        0.50, 0.48,
    ),
    "bug_mantis_death": (
        "Alien mantis dying, spasming chitin limbs clattering down and fading wet hiss",
        0.85, 0.45,
    ),
    "bug_bomber_appear": (
        "Bloated volatile alien bomber bug dragging swollen sac, wet sloshing belly and wheezing gas hiss",
        0.70, 0.45,
    ),
    "bug_bomber_windup": (
        "Volatile alien bomber bug inflating unstable gas sac to burst, stretching wet membrane creak and rising pressurized fizz",
        0.65, 0.45,
    ),
    "bug_bomber_fuse": (
        "Dying alien bomber bug volatile sac sizzling down like chemical fuse before detonation, bubbling pressure hiss and strained membrane",
        0.85, 0.45,
    ),
    "bug_bomber_attack": (
        "Volatile alien bomber bug exploding in wet bio-chemical blast, heavy concussive pop, wet gore splatter and acidic hiss",
        1.40, 0.45,
    ),
    "bug_bomber_hurt": (
        "Bloated alien bomber bug taking hit, wet slosh thud and pressurized gas leak squeal",
        0.55, 0.48,
    ),
    "bug_bomber_death": (
        "Alien bomber bug ruptured fatally, heavy wet sac burst and bubbling organic spill",
        1.30, 0.45,
    ),
    "bug_crystal_bug_appear": (
        "Crystalline-armored alien beetle moving, heavy mineral crystal chimes rubbing together with deep stony chitin footsteps",
        0.75, 0.45,
    ),
    "bug_crystal_bug_windup": (
        "Crystal-backed alien beetle lowering head to ram, grinding quartz crystal plates and low stony rumble",
        0.65, 0.45,
    ),
    "bug_crystal_bug_attack": (
        "Crystal-armored bug heavy ramming slam, dense mineral stone impact thud and sharp glass-like crystal clatter",
        0.75, 0.45,
    ),
    "bug_crystal_bug_hurt": (
        "Projectile glancing off crystal alien carapace, sharp crystalline chime ring and hard stony knock",
        0.60, 0.48,
    ),
    "bug_crystal_bug_death": (
        "Crystal-armored alien beetle shattering in death, cascading mineral crystal shards breaking apart with heavy collapse thud",
        1.10, 0.45,
    ),
    "bug_burrower_appear": (
        "Subterranean alien burrower shifting under soil, muffled dirt scraping rumble and shifting pebbles",
        0.80, 0.45,
    ),
    "bug_burrower_windup": (
        "Alien burrower tunneling rapidly beneath ground, grinding earth, digging claws and muffled subterranean tremor",
        0.70, 0.45,
    ),
    "bug_burrower_erupt": (
        "Giant subterranean alien bug erupting up through soil and rock, explosive dirt spray, cracking gravel and deep beast roar",
        1.00, 0.45,
    ),
    "bug_burrower_attack": (
        "Burrowing alien beast slamming upward from earth, heavy rock-dirt impact and snapping jaws",
        0.70, 0.45,
    ),
    "bug_burrower_hurt": (
        "Subterranean alien burrower struck, thick mud-coated carapace thud and guttural beast grunt",
        0.60, 0.48,
    ),
    "bug_burrower_death": (
        "Burrowing alien creature dying, collapsing earth pile, cracking armor and low dying groan",
        1.10, 0.45,
    ),
    "bug_mech_beetle_appear": (
        "Cyborg retrofitted steel-plated beetle advancing, whirring tiny servos mixed with heavy metal leg clanks",
        0.80, 0.45,
    ),
    "bug_mech_beetle_windup": (
        "Cyborg jammer beetle charging dorsal antenna, rising electromagnetic transformer hum and erratic electrical sparks",
        0.70, 0.45,
    ),
    "bug_mech_beetle_attack": (
        "Cyborg jammer beetle emitting disruptive EMP interference pulse, harsh electric static zap and metallic relay snap",
        0.80, 0.45,
    ),
    "bug_mech_beetle_jam": (
        "Electromagnetic interference draining mech systems, harsh static sputter, power sag hum and relay clatter",
        0.90, 0.45,
    ),
    "bug_mech_beetle_hurt": (
        "Bullet striking steel-armored cyborg beetle, hollow welded metal plate clang and brief electrical short spark",
        0.65, 0.48,
    ),
    "bug_mech_beetle_death": (
        "Cyborg mech-beetle destroyed, electrical short-circuit pop, detaching steel armor plates clattering and dying servo whine",
        1.20, 0.45,
    ),
    "bug_wasp_appear": (
        "Large flying alien hornet hovering in, rapid intimidating insect wing buzz and sharp chitin clicks",
        0.65, 0.45,
    ),
    "bug_wasp_windup": (
        "Flying alien wasp revving wings to dive, rising intense buzzing pitch and sharp venomous hiss",
        0.55, 0.45,
    ),
    "bug_wasp_attack": (
        "Flying alien wasp diving slash attack, fast Doppler wing-buzz whoosh and sharp stinger snap",
        0.55, 0.48,
    ),
    "bug_wasp_hurt": (
        "Flying alien wasp hit mid-air, faltering wing buzz sputter and sharp insectoid shriek",
        0.50, 0.48,
    ),
    "bug_wasp_death": (
        "Flying alien wasp shot down crashing to ground, spinning dying wing buzz ending in crisp shell crunch",
        0.75, 0.45,
    ),
    "bug_shielder_appear": (
        "Heavy shield-bearing alien beetle moving, wide armored carapace rattle and deep low resonant hum",
        0.85, 0.45,
    ),
    "bug_shielder_windup": (
        "Shield-vein alien beetle flaring wide dorsal umbrella shell, creaking chitin struts and rising low energy hum",
        0.70, 0.45,
    ),
    "bug_shielder_pulse": (
        "Alien shielder emitting protective bio-energy wave, deep resonant sub-bass pulse and shimmering air whoosh",
        0.95, 0.45,
    ),
    "bug_shielder_attack": (
        "Shielded alien beetle heavy bash attack, broad hard carapace slam and dull low thud",
        0.80, 0.45,
    ),
    "bug_shielder_hurt": (
        "Hit absorbed by shielded alien carapace, muffled resonant barrier knock and chitin thud",
        0.65, 0.48,
    ),
    "bug_shielder_death": (
        "Shield-vein alien beetle killed, collapsing bio-field fizzle and heavy armored shell falling apart",
        1.20, 0.45,
    ),
    "bug_mortar_appear": (
        "Heavy artillery mortar alien bug lumbering, heavy bulbous abdomen slosh and four-legged chitin plodding",
        0.85, 0.45,
    ),
    "bug_mortar_windup": (
        "Artillery mortar bug elevating abdomen to aim, straining muscular chitin plates and deep bubbling pressure buildup",
        0.80, 0.45,
    ),
    "bug_mortar_launch": (
        "Artillery mortar bug firing heavy acid shell skyward, deep organic cannon thump and wet projectile whistle",
        0.95, 0.45,
    ),
    "bug_mortar_attack": (
        "Incoming alien acid mortar shell bursting on impact, concussive wet explosion splash and sizzling acid mist",
        0.85, 0.45,
    ),
    "bug_mortar_hurt": (
        "Artillery mortar bug struck, heavy hollow abdomen thump and wet pained groan",
        0.65, 0.48,
    ),
    "bug_mortar_death": (
        "Artillery mortar bug destroyed, rupturing internal acid chamber explosion and collapsing chitin shell",
        1.25, 0.45,
    ),
    "bug_ironjaw_appear": (
        "Heavy iron-jawed alien charger stomping forward, metallic-hard mandibles snapping shut and deep beast snort",
        0.80, 0.45,
    ),
    "bug_ironjaw_windup": (
        "Iron-jawed alien beast snapping massive steel-like mandibles before charge, heavy jaw clack and scraping claws",
        0.70, 0.45,
    ),
    "bug_ironjaw_attack": (
        "Iron-jawed alien beast crushing bite and charge ram, violent heavy jaw clamp snap and impact thud",
        0.75, 0.45,
    ),
    "bug_ironjaw_hurt": (
        "Iron-jawed alien beast hit, hard dense skull knock and fierce angered growl",
        0.60, 0.48,
    ),
    "bug_ironjaw_death": (
        "Iron-jawed alien beast dying, final heavy jaw snap falling slack and massive armored body slamming dirt",
        1.15, 0.45,
    ),

    # ================================================================ 三大领主 Boss
    "boss_brood_roar": (
        "Colossal alien broodmother rising from fungal hive, terrifying deep sub-bass monster roar with wet gargling resonance and cavern echo",
        2.40, 0.40,
    ),
    "boss_brood_hatch": (
        "Giant broodmother egg sacs violently bursting open, massive wet tearing splat, deep maternal groan and screeching hatchlings",
        1.60, 0.42,
    ),
    "boss_king_roar": (
        "Colossal armored king beetle smashing through rock wall, deafening bass-heavy monster bellow, resonant heavy chitin chest rumble and falling rubble",
        2.50, 0.40,
    ),
    "boss_king_stomp": (
        "Colossal armored king beetle twin-pillar leg ground stomp, earth-shattering sub-bass tremor, cracking bedrock and heavy armor clatter",
        1.60, 0.42,
    ),
    "boss_king_core": (
        "Colossal king beetle dorsal carapace splitting open to expose glowing core, cracking heavy armor plates, surging plasma arc crackle and pressurized steam",
        1.80, 0.42,
    ),
    "boss_queen_roar": (
        "Abyssal alien queen awakening in deep shaft, haunting colossal multi-layered monster shriek, sub-bass tremor and shimmering crystalline resonance",
        2.60, 0.40,
    ),
    "boss_queen_wail": (
        "Abyssal alien queen piercing phase transition wail, sharp intake whoosh into eerie resonant monster cry and pulsing shockwave",
        2.20, 0.40,
    ),
    "boss_queen_core": (
        "Abyssal alien queen chest crystal core unleashing energy, deep earth tremor, violent electric storm arcs and singing crystal resonance",
        2.00, 0.42,
    ),
    "boss_phase_shift": (
        "Colossal boss monster enraged phase shift, explosive molting shell shatter, shockwave air blast and furious awakened roar",
        2.20, 0.40,
    ),
    "bug_broodmother_appear": (
        "Colossal broodmother monster advancing, heavy earth-shaking footsteps, wet fungal squelch and low menacing growl",
        1.40, 0.42,
    ),
    "bug_broodmother_windup": (
        "Colossal broodmother tensing for strike, creaking massive chitin plates, wet hissing intake and deep chest rumble",
        1.00, 0.42,
    ),
    "bug_broodmother_attack": (
        "Colossal broodmother heavy sweeping slam, fierce air rush, devastating ground impact boom and monstrous hiss",
        1.20, 0.42,
    ),
    "bug_broodmother_hurt": (
        "Colossal broodmother wounded, wet thick flesh impact, cracking carapace and pained deep monster roar",
        0.85, 0.45,
    ),
    "bug_broodmother_death": (
        "Colossal broodmother monster slain, cascading internal ruptures, collapsing heavy carapace and long fading abyssal death groan",
        2.60, 0.40,
    ),
    "bug_king_beetle_appear": (
        "Colossal armored king beetle marching, twin thunderous armored footsteps, heavy metal-like chitin clanking and deep bellow",
        1.40, 0.42,
    ),
    "bug_king_beetle_windup": (
        "Colossal king beetle bracing massive body for charge, grinding heavy shell armor and low intimidating snort",
        1.00, 0.42,
    ),
    "bug_king_beetle_attack": (
        "Colossal king beetle devastating ramming smash, brutal seismic impact boom, shattering rock and fierce roar",
        1.20, 0.42,
    ),
    "bug_king_beetle_hurt": (
        "Colossal king beetle taking heavy fire, resonant thick armor plate clang and angry low grunt",
        0.85, 0.45,
    ),
    "bug_king_beetle_death": (
        "Colossal armored king beetle defeated and collapsing, shattering thick armor plates, thunderous mountain-like ground crash and dying groan",
        2.60, 0.40,
    ),
    "bug_abyss_queen_appear": (
        "Colossal abyssal queen gliding forward, crystalline carapace chimes, low sub-bass hover hum and eerie hiss",
        1.40, 0.42,
    ),
    "bug_abyss_queen_windup": (
        "Abyssal queen gathering energy for strike, singing crystal vibrations, electrical crackle and tense monster screech",
        1.00, 0.42,
    ),
    "bug_abyss_queen_attack": (
        "Abyssal queen devastating crystal-energy strike, sharp electric whip blast, shattering crystal impact and piercing roar",
        1.20, 0.42,
    ),
    "bug_abyss_queen_hurt": (
        "Abyssal queen struck by weapon fire, cracking crystal chime, wet chitin thud and sharp shriek",
        0.85, 0.45,
    ),
    "bug_abyss_queen_death": (
        "Abyssal queen slain, catastrophic crystal armor shatter, surging energy discharge and echoing monstrous death wail",
        2.60, 0.40,
    ),

    # ================================================================ 搜刮、货舱、空投、撤离与运输机
    "loot_open": (
        "Opening rugged industrial metal field crate, crisp steel latch snap, squeaky hinge and lid hitting limit stop",
        0.75, 0.45,
    ),
    "loot_open_supply": (
        "Opening pressurized military supply crate, twin clamp snaps, vacuum rubber seal air hiss and hydraulic lid lift",
        0.95, 0.45,
    ),
    "loot_open_tool": (
        "Opening steel mechanic toolbox, crisp metal clasp pop and folding metal trays rattling open",
        0.80, 0.45,
    ),
    "loot_open_military": (
        "Opening heavy armored ordnance chest, twist valve release, four heavy bolts unlatching and thick steel lid lifting on gas struts",
        1.10, 0.45,
    ),
    "loot_open_safe": (
        "Cracking armored industrial safe, rapid mechanical dial clicks, heavy deadbolt sliding back and thick steel door swinging open",
        1.20, 0.45,
    ),
    "loot_open_bug": (
        "Prying open alien bug carcass shell, crisp chitin crack followed by wet tearing organic membrane squelch",
        0.95, 0.45,
    ),
    "loot_open_nest": (
        "Breaking open alien hive core sac, thick carapace crunch, hollow cavity resonance and wet viscous burst",
        1.15, 0.45,
    ),
    "loot_reveal": (
        "Tactical field scanner revealing loot item, crisp camera shutter mechanical click and light metal part tap",
        0.5, 0.50,
    ),
    "loot_reveal_rare": (
        "Discovering high-value rare relic inside crate, pneumatic lock release and clean resonant crystal-alloy chime, realistic industrial feel",
        1.00, 0.45,
    ),
    "loot_take": (
        "Picking up salvaged mechanical part into cargo bay, crisp robotic claw grab and solid lock clack into rack",
        0.5, 0.50,
    ),
    "loot_put": (
        "Placing salvaged hardware item back into crate, latch release tick and dull metallic drop thud",
        0.5, 0.50,
    ),
    "loot_close": (
        "Slamming metal supply crate lid shut, brief air whoosh, heavy lid thud and locking clasp snap",
        0.50, 0.48,
    ),
    "cargo_full": (
        "Mech cargo bay full warning, strained hydraulic suspension groan and heavy double dead-stop mechanical latch clack",
        0.75, 0.45,
    ),
    "cargo_overload": (
        "Mech chassis severely overloaded, groaning stressed steel frame, hydraulic pressure relief valve hiss and heavy warning bolt knock",
        1.20, 0.45,
    ),
    "drop_fall": (
        "Orbital drop-pod supersonic atmospheric reentry, deep sonic boom, roaring plasma wind turbulence and rattling heat-shield hull",
        2.20, 0.42,
    ),
    "drop_retro": (
        "Drop-pod terminal retro-rockets firing before impact, explosive heat-shield bolt pop and fierce roaring solid rocket braking thrust",
        1.40, 0.45,
    ),
    "drop_impact": (
        "Heavy orbital drop-pod slamming into rocky earth, thunderous earth-shattering crater impact, exploding door bolts and hissing hydraulic ramp drop",
        2.20, 0.42,
    ),
    "extract_start": (
        "Activating orbital extraction beacon terminal, heavy steel lever throw, hydraulic antenna mast extending and strong electromagnetic signal pulse",
        1.60, 0.45,
    ),
    "extract_cancel": (
        "Extraction uplink interrupted, heavy circuit breaker trip slam, turbine spinning down and pressure release hiss",
        1.20, 0.45,
    ),
    "extract_success": (
        "Boarding heavy extraction dropship, hydraulic cargo ramp closing and sealing shut, followed by roaring afterburner jet takeoff",
        2.60, 0.42,
    ),
    "transport_arrive": (
        "Heavy military VTOL dropship descending to landing zone, approaching jet turbine roar, reverse thrust wash, landing gear impact and cargo ramp clank",
        3.00, 0.42,
    ),
    "transport_idle_loop": (
        "Heavy VTOL dropship idling on landing pad, steady low dual-turbine engine rumble and warm hydraulic hum, seamless loop",
        4.40, 0.42,
    ),
    "transport_depart": (
        "Heavy military dropship lifting off and departing, cargo ramp slam, roaring jet turbines spooling up to full power and fading skyward whoosh",
        2.80, 0.42,
    ),

    # ================================================================ 战术 UI 与机库整备
    "ui_click": (
        "Single crisp tactile mechanical micro-switch button press on industrial military console, clean solid click, ultra-short dry isolated",
        0.5, 0.55,
    ),
    "ui_hover": (
        "Single ultra-light tiny magnetic rotary detent tick on precision instrument dial, crisp delicate click, ultra-short dry isolated",
        0.5, 0.55,
    ),
    "ui_confirm": (
        "Two-stage military toggle switch locking firmly into armed position, crisp trigger pre-click and solid steel latch snap, dry clean",
        0.5, 0.55,
    ),
    "ui_cancel": (
        "Mechanical console latch release spring reset, crisp unlatch tick followed by damped lower metallic return clack, dry clean",
        0.5, 0.55,
    ),
    "ui_tab": (
        "Crisp mechanical rotary selector switch clicking cleanly to next detent notch on military radio panel, ultra-short dry",
        0.5, 0.55,
    ),
    "ui_open": (
        "Precision aluminum tactical slate sliding open on smooth rails, crisp latch pop, light slide whoosh and end-stop click",
        0.5, 0.50,
    ),
    "ui_close": (
        "Precision tactical panel sliding shut and latching closed, smooth quick mechanical slide and firm catch click",
        0.5, 0.50,
    ),
    "ui_denied": (
        "Stiff blocked mechanical lockout lever double-clack on industrial panel, dull double metallic stop, zero electronic beep",
        0.5, 0.55,
    ),
    "hub_detach": (
        "Hangar crane uncoupling heavy mech weapon module, heavy pneumatic unlock hiss, hydraulic piston retract and steel mount clank",
        0.95, 0.45,
    ),
    "hub_dock": (
        "Hangar assembly docking heavy mech module into hardpoint, smooth servo slide, heavy steel locking pin slam and pneumatic pressure seal",
        0.95, 0.45,
    ),
    "hub_explode": (
        "Hangar blueprint exploded-view mechanical separation, crisp pneumatic unclamp and synchronized hydraulic rail slides spreading outward",
        1.10, 0.45,
    ),
    "hub_assemble": (
        "Hangar assembly pulling mech armor parts tightly back together, synchronized rail slide inward and solid heavy locking clank",
        1.20, 0.45,
    ),
    "hub_starter": (
        "Emergency mech frame gantry lowering and powering up in hangar, heavy gantry chains, frame touchdown thud and auxiliary reactor ignition",
        2.20, 0.42,
    ),
    "cargo_load": (
        "Loading supply crate into mech cargo bay, sturdy metal latch click and solid seated thud",
        0.55, 0.48,
    ),
    "cargo_unload": (
        "Unloading supply crate from mech cargo bay back to storage, latch unclip and light metallic set-down clank",
        0.55, 0.48,
    ),
    "shop_buy": (
        "Military quartermaster requisition stamped and dispatched, crisp mechanical stamper clack and brass coin/token lock drop",
        0.80, 0.45,
    ),
    "shop_sell": (
        "Salvage transaction completed in industrial depot, crisp metallic ledger click and clean mechanical drawer latch",
        0.75, 0.45,
    ),
    "request_complete": (
        "Logistics contract fulfilled stamp, solid heavy mechanical seal punch, pneumatic tube swoosh and subtle alloy chime",
        1.40, 0.45,
    ),

    # ================================================================ 养成、剧情、动态战场与天气
    "grow_upgrade": (
        "Airship hangar facility mechanical upgrade completed, pneumatic torque wrench tightening, heavy steel clamp lock and turbine spin-up",
        1.20, 0.45,
    ),
    "grow_research": (
        "Engineering blueprint research breakthrough, mechanical plotter rail stop, vacuum chamber lock and clean resonant tuning-fork chime",
        1.30, 0.45,
    ),
    "grow_level": (
        "Pilot rank promotion seal, heavy steel badge stamp impact followed by subtle warm resonant brass-bell ring and turbine hum",
        1.50, 0.42,
    ),
    "grow_affinity": (
        "Warm intimate crew bond moment, soft mechanical pocket-watch ratchet ticks and gentle warm glass harmonic chime",
        1.00, 0.45,
    ),
    "grow_gift": (
        "Presenting a keepsake gift box, delicate metal clasp unlatching, soft slide and gentle resonant glass tap on wooden desk",
        0.85, 0.45,
    ),
    "grow_meal": (
        "Field airship mess hall meal preparation, stainless steel mess tray clink, cutlery tap and hot steam pan sizzle",
        1.10, 0.45,
    ),
    "grow_recover": (
        "Medical bay recovery chamber unsealing, soft air pressure release hiss, calm deep vent breath and gentle latch release",
        1.30, 0.45,
    ),
    "story_open": (
        "Opening classified mission briefing projector, crisp mechanical aperture shutter snap and smooth rail deploy",
        0.65, 0.45,
    ),
    "story_close": (
        "Closing mission briefing dossier, shutter release click, smooth slide back and crisp metal clasp shut",
        0.50, 0.48,
    ),
    "story_text": (
        "Single tiny crisp mechanical teletype key striker tap, ultra-short dry isolated precision typewriter tick",
        0.5, 0.55,
    ),
    "comm_open": (
        "Encrypted military field radio PTT push-to-talk click, solid handset switch press followed by brief analog radio static squelch",
        0.55, 0.48,
    ),
    "archive_pickup": (
        "Extracting armored black-box data cassette, crisp metal cartridge eject clack and secure pouch slot snap",
        0.75, 0.45,
    ),
    "cargo_crash": (
        "Distant orbital cargo freighter crashing to ground, screaming atmospheric descent whoosh, massive distant explosion and tearing steel hull wreckage",
        2.80, 0.42,
    ),
    "decoy_deploy": (
        "Deploying mechanical acoustic decoy pod, grenade launcher pop, metallic bounce on dirt and rising pulse hum",
        1.10, 0.45,
    ),
    "decoy_off": (
        "Tactical decoy unit burning out and shutting down, capacitor pop, dying micro-turbine spin-down and brief steam vent",
        0.75, 0.45,
    ),
    "distress_beacon": (
        "Damaged field distress beacon pulsing, electric spark crackle, rotating mechanical beacon hum and weathered metallic ping",
        1.40, 0.45,
    ),
    "drone_deploy": (
        "Mech shoulder defense drone ejecting into air, locking hook clack, pneumatic launch pop and compact ducted fan spinning up to hover",
        1.10, 0.45,
    ),
    "energy_cell_plug": (
        "Heavy tactical energy rod docking straight into mech port, firm bayonet metal twist lock and pressurized coolant hiss",
        0.95, 0.45,
    ),
    "flare_ignite": (
        "Signaling magnesium flare ignition, crisp striker scratch pop followed by fierce hissing bright chemical burn and upward whoosh",
        1.40, 0.45,
    ),
    "relay_unlock": (
        "Activating industrial communications relay tower, heavy breaker throw, hydraulic dish unfolding lock and high-voltage power hum",
        1.60, 0.45,
    ),
    "supply_drop_land": (
        "Heavy military orbital supply crate slamming into dirt and gravel, parachute snap release, dense metallic ground thud and pneumatic latch vent",
        1.25, 0.45,
    ),
    "sandstorm_start": (
        "Severe desert sandstorm front rolling in, ominous low pressure rumble, howling gale wind and gritty sand pelting steel armor",
        2.50, 0.42,
    ),
    "sandstorm_end": (
        "Desert sandstorm subsiding, howling dusty wind calming down to quiet breeze and mech dust-louver shutters resetting",
        2.00, 0.42,
    ),
    "weather_rain_loop": (
        "Continuous heavy alien acid rain storm ambience, dense steady rainfall patter on metal mech cockpit roof and distant low thunder rumble, seamless loop",
        6.40, 0.42,
    ),
    "web_pulse": (
        "Electro-net launcher firing weighted shock mesh, pneumatic canister pop, spreading net whoosh and snapping stun-arc crackle",
        0.85, 0.45,
    ),
}
