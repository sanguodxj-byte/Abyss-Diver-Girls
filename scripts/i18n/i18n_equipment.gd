extends RefCounted
## Equipment, items, skills, loot tables, and registry category translations (zh <-> en).

const SLOT_NAMES_EN := {
	"core": "Core",
	"legs": "Chassis",
	"arm_l": "Left Arm",
	"arm_r": "Right Arm",
	"back": "Back Mount",
	"gen": "Reactor",
}

const RARITY_NAMES_EN := ["Common", "Uncommon", "Rare", "Legendary", "Prototype"]

const CAT_NAMES_EN := {
	"food": "Food",
	"misc": "Salvage",
	"use": "Consumable",
	"money": "Currency",
	"module": "Mech Module",
}

const QUALITY_NAMES_EN := ["Smooth", "High", "Ultra"]

const LEG_TYPES_EN := {
	"biped": "Biped",
	"tread": "Tread",
	"quad": "Quad",
	"hex": "Hex",
}

const MODULES_EN := {
	# ---- Core ----
	"core_assault": {
		"name": "AS-2 Assault Frame",
		"tags": ["Recon"],
		"desc": "Frontline assault frame with Class 4 boron-carbide composite armor and tactical optics ([Recon] View +1).",
	},
	"core_command": {
		"name": "CMD-1 Command Frame",
		"tags": ["Recon"],
		"desc": "Command frame with mmWave fire-control optics and wide canopy ([Recon] View +3), Class 3 armor, high ergonomics and cargo bay.",
	},
	"core_fortress": {
		"name": "FT-5 Fortress Frame",
		"desc": "Class 6 heavy composite armor cockpit offering 280 HP and +10% liner mitigation, at the cost of higher rotational inertia.",
	},
	"core_heavy": {
		"name": "BW-3 Heavy Frame",
		"desc": "Class 5 heavy defense frame with welded armor plating and a 24kg rear rack built for high-intensity assaults.",
	},
	"core_scout": {
		"name": "SC-1 Light Frame",
		"tags": ["Recon"],
		"desc": "Standard-issue Class 2 titanium-aluminum recon core ([Recon] View +2). Weighs only 8kg with top-tier ergonomics.",
	},
	"core_std": {
		"name": "MK-II Medium Frame",
		"desc": "Balanced Class 3 rolled homogeneous steel standard frame offering a solid mix of durability, cargo, and handling.",
	},
	"core_m1a2_sepv3": {
		"name": "SEP-V3 Depleted Uranium Composite Wedge Frame",
		"desc": "M1A2 SEPv3-derived heavy frame with asymmetric depleted-uranium cheek armor, TUSK ARAT-2 tiles and blow-out panels.",
	},
	"core_t90m_proryv": {
		"name": "PRV-90 Breakthrough Wedge-Armor Frame",
		"desc": "T-90M Proryv-derived low-profile octagonal turret with Relikt twin wedge ERA, ruby EO jammers and rear cage armor.",
	},
	"core_merkava_mk4m": {
		"name": "MRK-4M Trophy APS Heavy Frame",
		"desc": "Merkava Mk.4M-derived front-engine wedge hull with four Trophy APS radar plates and rear ball-chain curtains.",
	},
	"core_puma_spz": {
		"name": "SPZ-30 Puma Hedgehog Spaced-Armor Frame",
		"desc": "Puma-derived heavy IFV frame with anti-top-attack rubber hedgehog strips, AMAP modular side armor and MUSS warning heads.",
	},
	"core_bmpt_terminator": {
		"name": "BMPT-72 Terminator Twin Grenade-Cheek Frame",
		"desc": "Terminator-derived urban fire-support frame with twin AGS-30 grenade launcher cheek bays and Kontakt-5 tiles.",
	},
	"core_bradley_busk": {
		"name": "M2A4-BK Bradley Urban ERA Frame",
		"desc": "Bradley BUSK III-derived urban frame with full BRAT box ERA coverage, ballast plating and ISU sight box.",
	},
	"core_ka52_alligator": {
		"name": "KA-52M Alligator Coaxial Gunship Frame",
		"tags": ["Recon"],
		"desc": "Ka-52M-derived gunship frame with radar nose, side-by-side ejection cockpit and coaxial rotor hub.",
	},
	"core_mi24_hind": {
		"name": "MI-24P Hind Twin-Step Gunship Frame",
		"tags": ["Recon"],
		"desc": "Mi-24P-derived armored gunship frame with tandem stepped cockpit and twin dust-filtered turboshaft intakes.",
	},
	"core_fennek_recon": {
		"name": "FNK-4 Fennek Low-Profile Recon Frame",
		"tags": ["Recon"],
		"desc": "Fennek LGS-derived low-profile recon frame with faceted radar-scattering hull and BAA retractable mast.",
	},
	"core_pantsir_s1": {
		"name": "96K6-M Pantsir Twin-Array AA Frame",
		"tags": ["Recon"],
		"desc": "Pantsir-S1-derived radar command cabin with twin phased-array faces and missile/gun engagement suite.",
	},
	"core_patriot_mpq65": {
		"name": "MPQ-65 Patriot Phased-Array Core",
		"tags": ["Recon"],
		"desc": "Patriot PAC-3-derived phased-array fire-control radar cabin with high-power search and guidance arrays.",
	},
	"core_krasukha_ew": {
		"name": "1RL257 Krasukha Heavy EW Cabin Frame",
		"tags": ["Recon"],
		"desc": "Krasukha-4-derived wideband electronic-warfare cabin with heavy jamming arrays and generator housing.",
	},
	"core_trieste_bathy": {
		"name": "DSV-11K Trieste Abyssal Pressure Hull",
		"desc": "Trieste / Limiting Factor-derived deep-sea pressure hull with conical viewport and syntactic buoyancy blocks.",
	},
	"core_abv_shredder": {
		"name": "M1150-B Assault Breacher Plow Frame",
		"desc": "M1150 ABV-derived breacher frame with stowed V-plow, lane-marking launchers and armored cab.",
	},
	"core_pionier_dach": {
		"name": "PIO-2A Dachs Armored Engineer Frame",
		"desc": "Pionierpanzer 2A1-derived engineer frame with folding box-beam crane, 35-ton winch and dozer blade.",
	},
	# ---- Chassis: Tread ----
	"legs_tread_light": {
		"name": "MT-2 Light High-Speed Treads",
		"desc": "High-speed rubber-padded recon tread chassis with Class 3 sloped glacis armor and strong off-road agility.",
	},
	"legs_tread": {
		"name": "SAXX-1 Medium-Heavy Armored Treads",
		"desc": "All-terrain battle tread chassis with bolted side skirts (+14% mitigation); engages Full-Torque Charge.",
	},
	"legs_tread_heavy": {
		"name": "KV-6 Heavy Siege Treads",
		"desc": "Breaching tread chassis with hydraulic V-dozer blade, heavy reactive armor blocks, acid-sealed tracks, and 92kg load.",
	},
	"legs_tread_siege": {
		"name": "DT-9 Superheavy Quad-Articulated Treads",
		"desc": "Four articulated track pods on an armored hull. Immune to acid and overload slowdown; +20% mitigation and Class 6 protection.",
	},
	# ---- Chassis: Biped ----
	"legs_biped_scout": {
		"name": "LN-3 Light Recon Biped",
		"desc": "Open-truss reverse-joint recon legs with twin solid booster pods; fastest speed and ergonomics among bipeds.",
	},
	"legs_biped": {
		"name": "ST-8 Standard Mobile Biped",
		"desc": "Compact, field-proven servo walker legs with integral hip vector thrusters for rapid evasive dashes.",
	},
	"legs_biped_assault": {
		"name": "VK-5 Medium-Heavy Assault Biped",
		"desc": "Heavy assault walker with hinged ballistic tassets, knee shields, calf thrusters, and Class 4 protection.",
	},
	"legs_titan": {
		"name": "TT-8 Titan Heavy Siege Biped",
		"desc": "Titan-class reverse-joint siege walker. Immune to acid and overload slowdown; 115kg load and Class 6 armor.",
	},
	# ---- Chassis: Quad ----
	"legs_quad_hound": {
		"name": "HD-4 Light Hound Quad",
		"desc": "Agile four-legged pursuit chassis with terrain-scanning lidar for rapid flanking across broken ruins.",
	},
	"legs_quad": {
		"name": "AR-4 Standard Multi-Terrain Quad",
		"desc": "Octagonal load-ring four-legged chassis rated for 80kg; performs Hydraulic Leap and deploys a snare web at takeoff.",
	},
	"legs_quad_crab": {
		"name": "CR-6 Heavy Bastion Quad",
		"desc": "Low-profile bunker hull on four armored crab legs with ERA bricks and acid-sealed actuators—a walking ballistic cover.",
	},
	"legs_quad_mammoth": {
		"name": "MM-10 Mammoth Outrigger Quad",
		"desc": "Box-girder platform on four dual-piston pile-driver legs; ignores overload penalty with 122kg load capacity.",
	},
	# ---- Chassis: Hex ----
	"legs_hex_ant": {
		"name": "AT-6 Light Engineer Hexapod",
		"desc": "Tubular space-frame hull on six hydraulic engineer limbs with alternating tripod gait; only 11kg weight for 72kg load.",
	},
	"legs_hex": {
		"name": "HX-6 Medium-Heavy Cruiser Hexapod",
		"desc": "Six-legged military cruiser chassis with triple-ground-contact stability, 90kg load, and Heavy Tremor Stomp.",
	},
	"legs_hex_beetle": {
		"name": "BT-9 Heavy Beetle Hexapod",
		"desc": "Broad NBC-sealed carapace shielding all six joints, dual ram horns, and positive-pressure acid immunity.",
	},
	"legs_hex_colossus": {
		"name": "CL-12 Colossus Siege Hexapod",
		"desc": "Three-section riveted siege hull on six dual-cylinder pile-driver legs; unmatched 140kg load and Class 6 armor.",
	},
	# ---- Back Mount ----
	"back_rack": {
		"name": "RK-4 External Cargo Rack",
		"desc": "Modular alloy quick-release external rack adding 18kg of salvage cargo capacity.",
	},
	"back_rocket": {
		"name": "RP-7 Rocket Pod",
		"caliber": "80mm S-8KOM HEAT-FRAG Rocket",
		"desc": "Twin 80mm aviation rocket pods firing an 8-rocket high-explosive fragmentation salvo over a wide area.",
	},
	"back_vls": {
		"name": "VLS-12 Vertical Launch Cell",
		"caliber": "120mm Top-Attack Loitering Munition",
		"desc": "12-cell cold-launch vertical silo firing mmWave top-attack munitions for saturation strikes against heavy armor.",
	},
	"back_cargo": {
		"name": "CG-10 Light Cargo Pack",
		"desc": "Shockproof waterproof salvage container weighing only 2kg and providing 12kg of extra cargo capacity.",
	},
	"back_missile": {
		"name": "MS-6 Medium Missile Rack",
		"caliber": "70mm IR-Guided Micromissile",
		"desc": "6-tube imaging-infrared micromissile rack with fast lock-on and short reload for medium-close cleanup.",
	},
	"back_shield": {
		"name": "SH-3 Medium Field Shield",
		"desc": "Active Defense Interceptor generating a 4s omnidirectional electromagnetic deflection screen and sealing 35% of limb damage with repair compound.",
	},
	# ---- Reactor ----
	"gen_diesel": {
		"name": "DS-6 Diesel Generator",
		"desc": "Rugged twin-turbo military diesel genset providing 240 Energy and 5% power efficiency.",
	},
	"gen_hfc": {
		"name": "HFC-3 Hydrogen Fuel Cell",
		"desc": "High-output PEM hydrogen-oxygen fuel stack—providing 340 Energy and reducing total power drain by 12%.",
	},
	"gen_turbine": {
		"name": "TB-5 Turbine Unit",
		"desc": "Aviation gas-turbine and flywheel hybrid unit delivering 400 Energy with 8% efficiency savings for heavy weapon rigs.",
	},
	"gen_cell": {
		"name": "B-40 Light Battery Pack",
		"desc": "Modular lithium-sulfur battery bank weighing only 5kg and supplying 200 Energy; ideal for light recon frames.",
	},
	"gen_crystal": {
		"name": "CR-8 Prototype Crystal Reactor",
		"desc": "Piezoelectric Abyss Crystal isotope reactor supplying 460 Energy and cutting total mech power drain by 20%.",
	},
	"gen_reactor": {
		"name": "RT-1 Prototype Fission Reactor",
		"desc": "Compact liquid-metal cooled fission reactor delivering 300 Energy and 10% power efficiency; standard medium core power.",
	},
	"gen_agt1500_turbine": {
		"name": "AGT-1500 Recuperated Gas Turbine",
		"desc": "Honeywell AGT1500-derived multi-fuel recuperated turbine with dust-filter intake and IR-suppressed exhaust louvers.",
	},
	"gen_mtu_mb873_v12": {
		"name": "MB-873 Twin-Turbo V12 Diesel",
		"desc": "MTU MB 873 Ka-501-derived 47.6L twin-turbo V12 diesel powerpack.",
	},
	"gen_twin_apu_gtcp": {
		"name": "GTCP-85 Twin-Rotor APU Turbogenerator",
		"desc": "Twin redundant Garrett GTCP85 auxiliary power turbine generators.",
	},
	"gen_naval_pwr_s9g": {
		"name": "S9G-PWR Submarine Pressurized Reactor",
		"desc": "GE S9G-derived natural-circulation pressurized water reactor primary loop.",
	},
	"gen_lfr_lead_bismuth": {
		"name": "SVBR-10 Lead-Bismuth Fast Reactor",
		"desc": "SVBR / BM-40A-derived lead-bismuth eutectic cooled fast reactor.",
	},
	"gen_stirling_aip": {
		"name": "MK3-AIP Stirling Air-Independent Generator",
		"desc": "Kockums V4-275R Stirling Mk.3-derived air-independent propulsion generator.",
	},
	"gen_pem_fuelcell": {
		"name": "PEM-600 Hydrogen Fuel-Cell Stack",
		"desc": "Siemens BZM / SINAVY 212A-derived solid-hydrogen PEM fuel-cell system.",
	},
	"gen_homopolar_pulse": {
		"name": "HPG-90 Homopolar Pulse Capacitor Plant",
		"desc": "General Atomics Blitzer-derived high-energy pulse capacitor bank for railgun-class loads.",
	},
	"gen_mhd_plasma_gen": {
		"name": "MHD-40 Magnetohydrodynamic Generator",
		"desc": "Pamir-3U-derived vehicular pulsed magnetohydrodynamic generator.",
	},
	"gen_hydrothermal_hx": {
		"name": "HTX-12 Abyssal Hydrothermal Heat Exchanger",
		"desc": "Sandia sCO2 closed Brayton cycle shell-and-tube heat exchanger generator.",
	},
	# ---- Arm Weapons ----
	"arm_hmg": {
		"name": "HMG-24 Heavy Machine Gun",
		"caliber": "14.5×114mm BS Tungsten-Core API",
		"desc": "14.5mm heavy mech MG firing tungsten-core API rounds (Class 4 pen, range 12) for strong suppression of medium carapaces.",
	},
	"arm_gatling": {
		"name": "GAU-6 Six-Barrel Gatling",
		"caliber": "20×102mm M53 Armor-Piercing",
		"desc": "Electric 6-barrel 20mm rotary cannon (range 10) pouring 900 RPM to shred unarmored and light swarms.",
	},
	"arm_ac30": {
		"name": "AC-30 Autocannon",
		"caliber": "30×165mm 3UBR8 APDS",
		"desc": "Long-barrel high-velocity 30mm autocannon firing sabot penetrators (Class 5 pen, range 14) to punch through heavy lords.",
	},
	"arm_slug": {
		"name": "SLG-12 Slug Shotgun",
		"caliber": "23×75mmR Steel-Core Slug",
		"desc": "23mm rifled heavy shotgun firing solid machined steel slugs (Class 4 pen, range 8) with brutal close-range impact.",
	},
	"arm_cannon": {
		"name": "CN-105 Short-Barrel Cannon",
		"caliber": "105mm M456 Shaped-Charge",
		"desc": "Low-recoil 105mm smoothbore assault gun whose shaped-charge jet (Class 5 pen, range 11) melts thick carapaces.",
	},
	"arm_rail": {
		"name": "RG-9 Railgun",
		"tags": ["Recon"],
		"caliber": "16mm Tungsten Fin-Stabilized Sabot",
		"desc": "Hyper-velocity electromagnetic rail sniper (range 16, Class 6 pen) launching long tungsten darts; RMB activates long-range optical scope.",
	},
	"arm_flamer": {
		"name": "FT-20 Incendiary Launcher",
		"caliber": "40mm Pressurized Thermite-Gel Shell",
		"desc": "High-rate close-range launcher (range 5) firing perforated steel thermite-gel shells that pierce and ignite dense packs.",
	},
	"arm_laser": {
		"name": "LZ-42 Coil Marksman Rifle",
		"caliber": "9×68mm Tungsten Flechette Sabot",
		"desc": "Multi-stage asynchronous coil DMR (Class 4 pen, range 13) propelling tungsten flechettes with flat trajectory and high ergonomics.",
	},
	"arm_mg": {
		"name": "G-36 Rotary Machine Gun",
		"caliber": "12.7×108mm B-32 API",
		"desc": "Standard 12.7mm 3-barrel rotary MG (Class 3 pen, range 10) with high ergonomics and reliable feed for routine patrols.",
	},
	"arm_shotgun": {
		"name": "SG-7 Heavy Shotgun",
		"caliber": "23×75mmR 8.5mm Buckshot (7 pellets)",
		"desc": "23mm military automatic shotgun (range 7) blasting 7 heavy buckshot pellets per shot (Class 1 pen), devastating soft targets.",
	},
	"arm_sniper": {
		"name": "M99 Precision Sniper Rifle",
		"tags": ["Recon"],
		"caliber": "12.7×99mm M33 Match AP",
		"desc": "High-precision heavy sniper rifle with optical scope (RMB black-mask long-range zoom), range 22, Class 5 AP penetration.",
	},
	"arm_amr": {
		"name": "NTW-20 Anti-Materiel Cannon",
		"tags": ["Recon"],
		"caliber": "20×110mm HEAP Anti-Materiel",
		"desc": "Heavy 20mm anti-materiel cannon with extreme long-range optical scope (RMB scope zoom) capable of punching through Class 6 armor.",
	},
	"arm_rh120": {
		"name": "L55-120 Rheinmetall 120mm Smoothbore Tank Cannon",
		"caliber": "120×570mm Rh-120 APFSDS",
		"desc": "Mech-scale Leopard 2A7 main gun with wedge composite mantlet, three-stage thermal sleeve, bore evacuator and MRS muzzle reference sight.",
	},
	"arm_2a46": {
		"name": "2A46-125 Breakthrough 125mm Autoloaded Smoothbore",
		"caliber": "125×575mm 2A46M APFSDS",
		"desc": "T-90M-pattern smoothbore with 4S23 ERA shield, five-band thermal sleeve and bustle ejection port.",
	},
	"arm_m68": {
		"name": "M68-105 Stryker 105mm Rifled Assault Gun",
		"caliber": "105×617mmR M68 HEAT",
		"desc": "M1128-pattern unmanned gun pod with bustle autoloader drum, accordion dust cover and pepperbox muzzle brake.",
	},
	"arm_ags152": {
		"name": "AGS-152 Stealth Naval 152mm Gun Cupola",
		"caliber": "152mm AGS Guided HE",
		"desc": "Zumwalt AGS-inspired faceted stealth cupola with copper water-cooling loops and twin-chamber brake.",
	},
	"arm_cg84": {
		"name": "CG84-X2 Twin 84mm Recoilless Rifle",
		"caliber": "84×246mmR Tandem HEAT",
		"desc": "Carl-Gustaf M4 twin-tube recoilless rifle on an Ontos-style cradle.",
	},
	"arm_gau8": {
		"name": "GAU-8/30 Avenger Seven-Barrel Gatling",
		"caliber": "30×173mm GAU-8 DU AP",
		"desc": "Hydraulic seven-barrel 30mm rotary cannon with magazine drum and feed chute.",
	},
	"arm_m242": {
		"name": "M242-25 Bushmaster Chain Gun",
		"caliber": "25×137mm M242 APDS",
		"desc": "Dual-feed 25mm chain gun with linked belt box and thermal shroud.",
	},
	"arm_2a72": {
		"name": "2A72-30 Trunnion-Stabilized Autocannon",
		"caliber": "30×165mm 2A72 AP",
		"desc": "Long-recoil 30mm autocannon with truss barrel brace and brass catcher.",
	},
	"arm_phalanx": {
		"name": "MK15-20 Phalanx Block 1B CIWS",
		"caliber": "20×102mm M61A1 APDS",
		"desc": "Radar-directed 20mm close-in weapon with white radome and gun-gas scavenging.",
	},
	"arm_bofors40": {
		"name": "L70-40 Bofors Top-Feed Autocannon",
		"caliber": "40×365mmR Bofors 3P",
		"desc": "40mm high-velocity AA cannon with top-mounted clip guide and muzzle brake.",
	},
	"arm_m82": {
		"name": "M82-35 Barrett 35mm Anti-Materiel Cannon",
		"tags": ["Recon"],
		"caliber": "12.7×99mm M33 AP",
		"desc": "Mech-scaled Barrett with muzzle brake, monopod and high-power optic.",
	},
	"arm_ntw57": {
		"name": "NTW-57 Denel 57mm Long-Range Anti-Armor Rifle",
		"tags": ["Recon"],
		"caliber": "20×110mm NTW HE-AP",
		"desc": "Side-insert box-magazine anti-materiel rifle with long recoil cradle and muzzle brake.",
	},
	"arm_m45": {
		"name": "M45-50X4 Quad Browning AA Mount",
		"caliber": "12.7×99mm M2HB API",
		"desc": "Maxson quadmount with four M2HB receivers, ammo cans and elevation gear.",
	},
	"arm_aa12": {
		"name": "AA12-40 Auto Frag Shotgun",
		"caliber": "FRAG-12 40mm Frag Shell (8 pellets)",
		"desc": "Constant-recoil drum-fed automatic shotgun throwing eight FRAG-12 pellets per shot.",
	},
	"arm_ks60": {
		"name": "KS-60 Flechette Riot Shotgun",
		"caliber": "23×75mmR Rifled Flechette",
		"desc": "Sawn-off heavy rifled shotgun firing a dense flechette load.",
	},
	"arm_tow2b": {
		"name": "TOW-2B Twin Heavy ATGM Launcher",
		"caliber": "BGM-71F TOW-2B Top-Attack",
		"desc": "Twin armored TOW launcher with optronic sight head and top-attack missiles.",
	},
	"arm_kornet": {
		"name": "9M133-X4 Kornet-EM Quad Launcher",
		"caliber": "9M133M-2 Kornet-EM",
		"desc": "Four-cell laser-beam-riding ATGM rack with elevation actuator and thermal sight.",
	},
	"arm_lau61": {
		"name": "LAU-61 Hydra 19-Tube Rocket Pod",
		"caliber": "70mm Hydra 70 HE",
		"desc": "Nineteen-tube 70mm rocket pod with blast deflector ring and intervalometer.",
	},
	"arm_m299": {
		"name": "M299-HF4 Hellfire Quad Rail Launcher",
		"caliber": "AGM-114L Longbow Hellfire",
		"desc": "M299 four-rail launcher with millimeter-wave radome and Hellfire missiles.",
	},
	"arm_ram116": {
		"name": "MK49-RAM Rolling Airframe Missile Box",
		"caliber": "RIM-116 Rolling Airframe Missile",
		"desc": "Eleven-cell RAM launcher with rolling-airframe interceptors for close defense.",
	},
	"arm_m777": {
		"name": "M777-155 Ultralight Towed Howitzer",
		"caliber": "155mm M777A2 Excalibur",
		"desc": "Titanium trail howitzer with muzzle brake and digital fire-control mast.",
	},
	"arm_tos220": {
		"name": "TOS-220 Solntsepek Thermobaric MLRS",
		"caliber": "220mm TOS-1A Thermobaric Rocket",
		"desc": "Six-cell 220mm thermobaric rocket launcher with blast shields and elevation cradle.",
	},
	"arm_rpo93": {
		"name": "RPO-93X4 Shmel Thermobaric Assault Pack",
		"caliber": "93mm RPO-M FAE",
		"desc": "Four-tube 93mm fuel-air explosive assault pack with ignition box.",
	},
	"arm_m10flm": {
		"name": "M10-FLM Zippo Napalm Projector",
		"caliber": "40mm Pressurized Napalm",
		"desc": "Armored high-pressure napalm projector with twin fuel tanks and ignition torch.",
	},
	"arm_mk108": {
		"name": "MK108-4X Short-Barrel HE Assault Pod",
		"caliber": "30×90mmR MK108 Mine Shell",
		"desc": "Quad 30mm short-barrel mine-shell pod with recoil springs and blast cone.",
	},
	"arm_pb09": {
		"name": "PB-09 Propellant Hydraulic Pile Driver",
		"caliber": "PB-09 Captive-Bolt Spike",
		"desc": "Captive-bolt propellant ram for siege breaching.",
	},
	"arm_hc40": {
		"name": "HC-40 Hydraulic Jaw Cutter",
		"caliber": "HC-40 Shear Jaw",
		"desc": "Genesis-grade hydraulic steel shear for cutting armor plate.",
	},
	"arm_cs88": {
		"name": "CS-88 Tungsten Carbide Trench Saw",
		"caliber": "CS-88 Carbide Chain Teeth",
		"desc": "Rock-trencher chain boom with carbide teeth for grinding armor.",
	},
	"arm_th60": {
		"name": "TH-60 Boxed Hydraulic Breaker",
		"caliber": "TH-60 Chisel Impact",
		"desc": "Krupp-pattern boxed hydraulic hammer for seismic armor crushing.",
	},
	"arm_miclic": {
		"name": "M58-CLC MICLIC Breacher Arm",
		"caliber": "M58 MICLIC Line Charge",
		"desc": "Assault-breacher arm with rocket line charge and spaced ERA siege shield.",
	},
}

const ITEMS_EN := {
	# ---- Food ----
	"can_food": {"name": "Canned Meat", "desc": "Hermetically sealed pre-war luncheon meat tin; staple ingredient for sortie rations."},
	"biscuit": {"name": "Compressed Biscuits", "desc": "High-calorie vacuum-packed military rations—dry and hard, practically eternal shelf life."},
	"water_tab": {"name": "Water Purification Tabs", "desc": "Chlorine-dioxide tablets capable of turning surface runoff into safe drinking water."},
	"coffee": {"name": "Old-World Coffee Beans", "desc": "Foil-sealed roasted coffee beans, prized by both airship crew and black-market traders."},
	# ---- Salvage ----
	"circuit": {"name": "Circuit Board", "desc": "Multi-layer PCB pulled from industrial terminals; key electronics for facility upgrades and research."},
	"wire": {"name": "Copper Wire Spool", "desc": "Oxygen-free copper winding wire used for power line repairs and actuator maintenance."},
	"bolts": {"name": "Alloy Bolts", "desc": "Standard high-tensile fasteners for riveting mech armor plates and repairing airship bulkheads."},
	"hdd": {"name": "Old-World Hard Drive", "desc": "Magnetic storage array holding pre-war schematics and research logs needed by the Lab."},
	"toy": {"name": "Wind-Up Toy", "desc": "A tin clockwork frog that still hops when wound—the kids aboard ship adore these."},
	"chitin": {"name": "Bug Chitin", "desc": "Hardened chitinous carapace plates shed or shattered off Abyssal hostiles, used in light composite armor."},
	"bug_crystal": {"name": "Abyss Crystal", "desc": "Dense bio-energetic crystal harvested from the Abyss, essential for high-tier power research and reactors."},
	# ---- Consumables ----
	"fuel_cell": {"name": "Fuel Cell", "desc": "Single-use portable power pack (Key 1). Instantly restores 50 Mech Energy in the field."},
	"repair_kit": {"name": "Repair Kit", "desc": "Nanite repair-gel canister (Key 2). Restores 45 HP and repairs 50% of damaged parts in the field."},
	"beacon": {"name": "Evac Beacon", "desc": "Encrypted HF nav beacon (Key T). Calls an emergency dropship extraction anywhere in the zone."},
	# ---- Currency ----
	"credit_s": {"name": "Credit Chip (S)", "desc": "Unregistered small-denomination credit chip; redeems for 100 Credits upon extraction or sale."},
	"credit_l": {"name": "Credit Chip (L)", "desc": "High-clearance settlement chip; redeems for 500 Credits upon extraction or sale."},
	"gold": {"name": "Old World Commemorative Bar", "desc": "A bullion bar struck by the old central bank. Long out of circulation—worth only a collector's price in the wastes."},
	# ---- Tactical Consumables ----
	"sonic_decoy": {"name": "Sonic Decoy Beacon", "desc": "Tactical acoustic emitter (Key 3). Lures bugs within 14m away from the mech and detonates after 2.2s."},
	"extract_flare": {"name": "Evac Guide Smoke", "desc": "Pressurized interference smoke canister (Key 4). Blinds/slows bugs within 10m and cuts evac timer by 50%."},
	"energy_rod": {"name": "High-Energy Cell Rod", "desc": "Mil-spec superconductor rod (Key 5). Instantly recharges 80 Energy and clears emergency blackout."},
	"coolant_pack": {"name": "Coolant Canister", "desc": "Liquid-nitrogen coolant pack (Key 6). Flushes reactor loops to halve mech power draw for 20s."},
	"extract_barrier": {"name": "Evac Barrier", "desc": "Portable field generator (Key 7). Projects a 6s shield dome that knocks back bugs within 5.5m."},
	"surge_cell": {"name": "Overclock Cell", "desc": "High-pulse cell (Key 8). Forces +85 Energy immediately, followed by 10s of elevated thermal drain."},
	# ---- Gifts ----
	"gift_watch": {"name": "Brass Pocket Watch"},
	"gift_wrench": {"name": "Tungsten Wrench"},
	"gift_cocoa": {"name": "Old-World Cocoa Powder"},
	"gift_chart": {"name": "Airway Atlas"},
	"gift_flask": {"name": "Silver Hip Flask"},
	# ---- Archives ----
	"arch_duty_log": {"name": "Duty Watch Log"},
	"arch_photo": {"name": "Yellowed Photograph"},
	"arch_letter": {"name": "Unsent Letter"},
	"arch_manifest": {"name": "Freight Manifest"},
	"arch_blueprint": {"name": "Hand-Drawn Blueprint"},
	"arch_tape": {"name": "Cassette Tape"},
	"arch_child_drawing": {"name": "Child's Crayon Drawing"},
	"arch_research_note": {"name": "Field Observation Notes"},
	"arch_observation": {"name": "Water Quality Log"},
	"arch_shift_log": {"name": "Shift Roster"},
	"arch_flight_log": {"name": "Flight Log Fragment"},
	"arch_deep_record": {"name": "Deep Borehole Drilling Log"},
}

const SKILLS_EN := {
	"biped": {"name": "Vector Thrust Dash", "desc": "Fires solid hip vector thrusters for a short, high-speed evasive burst in your move direction."},
	"tread": {"name": "Full-Torque Ram", "desc": "Disengages transmission limiters to charge at full torque, scattering foes and dealing 28 blunt damage."},
	"quad": {"name": "Hydraulic Vault", "desc": "Hydraulic launch over obstacles; drops a viscous snare net at takeoff and shocks the landing zone for 22 damage."},
	"hex": {"name": "Heavy Tremor Stomp", "desc": "Synchronized six-leg hydraulic slam releasing a shockwave that deals 34 damage within 4.8m."},
	"missile": {"name": "Guided Salvo", "desc": "Opens dorsal launch cells to fire guided rockets/micromissiles at visible targets."},
	"shield": {"name": "Active Defense Screen", "desc": "Activates an electromagnetic deflection barrier to intercept incoming attacks while sealing hull breaches."},
	"none": {"name": "No Active System", "desc": "External cargo assembly dedicated to haulage with no active fire-control or defense subsystem."},
}

const LOOT_TABLES_EN := {
	"supply": {"name": "Supply Crate"},
	"tool": {"name": "Toolbox"},
	"military": {"name": "Military Locker"},
	"safe": {"name": "Safe"},
	"bug": {"name": "Bug Carcass"},
	"nest": {"name": "Hive Remains"},
	"rover": {"name": "Rover Wreck"},
	"mantis": {"name": "Mantis Remains"},
	"crystal": {"name": "Crystalback Remains"},
	"scrap": {"name": "Scrapbug Remains"},
	"elite": {"name": "Elite Carcass"},
	"boss_brood": {"name": "Broodmother Remains"},
	"boss_king": {"name": "Beetle King Remains"},
	"boss_queen": {"name": "Abyss Queen Remains"},
	"boss_reaper": {"name": "Tide Reaper Remains"},
	"boss_colossus": {"name": "Slag Colossus Remains"},
	"boss_devourer": {"name": "Sand Devourer Remains"},
	"boss_archon": {"name": "Prism Archon Remains"},
	"boss_warden": {"name": "Terminus Warden Remains"},
	"boss_dreadnought": {"name": "Foundry Dreadnought Remains"},
	"boss_warhead": {"name": "Silo Warhead Remains"},
	"boss_leviathan": {"name": "Spillway Leviathan Remains"},
	"boss_titan": {"name": "Excavator Titan Remains"},
	"boss_overlord": {"name": "Core Overlord Remains"},
	"boss_behemoth": {"name": "Drydock Behemoth Remains"},
	"boss_citadel": {"name": "Landcruiser Wreckage"},
	"boss_carrier": {"name": "Sky Carrier Wreckage"},
}
