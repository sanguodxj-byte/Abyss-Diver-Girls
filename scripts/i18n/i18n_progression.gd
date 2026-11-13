extends RefCounted
## Growth, pilots, crew, chapters, quests, abilities, merchants, and emotions translations (zh <-> en).

const FACILITIES_EN := {
	"hangar": {
		"name": "Hangar Bay",
		"effect": [
			"HP +5 · Cargo +1",
			"HP +10 · Cargo +2",
			"HP +15 · Cargo +3",
			"HP +20 · Cargo +4",
			"HP +25 · Cargo +5",
		],
	},
	"workshop": {
		"name": "Workshop",
		"effect": [
			"Armor +2% · Load +2",
			"Armor +4% · Load +4",
			"Armor +6% · Load +6",
			"Armor +8% · Load +8",
			"Armor +10% · Load +10",
		],
	},
	"infirmary": {
		"name": "Infirmary",
		"effect": [
			"Drain -0.004 · 20% Loss Recovery",
			"Drain -0.008 · 40% Loss Recovery",
			"Drain -0.012 · 60% Loss Recovery",
			"Drain -0.016 · 80% Loss Recovery",
			"Drain -0.020 · 100% Loss Recovery",
		],
	},
	"lab": {
		"name": "Research Lab",
		"effect": [
			"Max Energy +5 · Lab Tier 1",
			"Max Energy +10 · Lab Tier 2",
			"Max Energy +15 · Lab Tier 3",
			"Max Energy +20 · Lab Tier 4",
			"Max Energy +25 · Lab Tier 5",
		],
	},
	"kitchen": {
		"name": "Kitchen",
		"effect": [
			"Meal: Energy +12 · HP +3",
			"Meal: Energy +16 · HP +6",
			"Meal: Energy +20 · HP +9",
			"Meal: Energy +24 · HP +12",
			"Meal: Energy +28 · HP +15",
		],
	},
}

const RESEARCH_EN := {
	"res_cell": {"name": "Crystal Cell Pack", "effect": "Max Energy +12"},
	"res_armor": {"name": "Composite Chitin Armor", "effect": "Armor +3% · Unlocks Shop: Field Shield"},
	"res_lens": {"name": "Multi-Stage Coil Driver", "effect": "Unlocks Shop: Coil Marksman Rifle"},
	"res_flame": {"name": "Pressurized Thermite Feed", "effect": "Unlocks Shop: Incendiary Launcher"},
	"res_quad": {"name": "Quadruped Gait Control", "effect": "Speed +0.2 · Load +2 · Unlocks Shop: Multi-Terrain & Bastion Quads"},
	"res_missile": {"name": "Swarm Missile Pod", "effect": "Unlocks Shop: Medium Missile Rack"},
	"res_hex": {"name": "Hexapod Gait Sync", "effect": "Load +6 · Speed +0.2 · Unlocks Shop: Cruiser & Beetle Hexapods"},
	"res_core": {"name": "Heavy Frame Prototype", "effect": "HP +10 · Unlocks Shop: Heavy Frame"},
	"res_recycle": {"name": "Eco-Cycle Water Recovery", "effect": "Drain -0.006"},
	"res_quiet": {"name": "Damped Acoustic Frame", "effect": "Drain -0.008"},
	"res_deep": {"name": "Abyssal Pressure Cockpit", "effect": "HP +20 · Max Energy +20 · Armor +2% · Unlocks Shop: Crystal Reactor"},
	"res_ration": {"name": "High-Calorie Combat Ration", "effect": "Sortie Meal: Energy +8 · HP +4"},
}

const PILOTS_EN := {
	"nao": {
		"name": "Nao",
		"talents": {
			"t_nao_rig": {"name": "Load-Bearing Truss", "effect": "Load +8"},
			"t_nao_cache": {"name": "Hidden Stash Compartments", "effect": "Cargo +4"},
			"t_nao_stride": {"name": "Light-Footed Stride", "effect": "Speed +0.35"},
			"t_nao_field": {"name": "Field Emergency Patch", "effect": "HP +18 · Drain -0.004"},
		},
	},
	"rei": {
		"name": "Rei",
		"talents": {
			"t_rei_cap": {"name": "Pulse Capacitor Bank", "effect": "Max Energy +15"},
			"t_rei_step": {"name": "Silent Step", "effect": "Speed +0.3"},
			"t_rei_cool": {"name": "Cryo Conduit", "effect": "Drain -0.008"},
			"t_rei_focus": {"name": "Long-Range Sighting", "effect": "Max Energy +20 · HP +10"},
		},
	},
	"kurumi": {
		"name": "Kurumi",
		"talents": {
			"t_kur_plate": {"name": "Reinforced Subframe", "effect": "HP +25"},
			"t_kur_heat": {"name": "Heat-Resistant Plating", "effect": "Armor +4%"},
			"t_kur_charge": {"name": "Breach Thrusters", "effect": "Speed +0.3"},
			"t_kur_hold": {"name": "Last Stand", "effect": "HP +30 · Armor +2%"},
		},
	},
}

const CREW_EN := {
	"lina": {"name": "Lina"},
	"mia": {"name": "Mia"},
	"ajin": {"name": "Ajin"},
	"xiaoman": {"name": "Xiaoman"},
}

const CHAPTERS_EN := {
	"ch1": {"title": "Ch. 1 · Peppermints Over Greyport"},
	"ch2": {"title": "Ch. 2 · Rust and Echoes"},
	"ch3": {"title": "Ch. 3 · Egret in the Dust"},
	"ch4": {"title": "Ch. 4 · Silence on Red Lake"},
	"ch5": {"title": "Ch. 5 · Ghost Signals of the Rift"},
	"ch6": {"title": "Ch. 6 · The Broken Wing's Black Box"},
	"ch7": {"title": "Finale · Into Abyss Well Zero"},
}

const MEAL_EN := {
	"text": [
		"Energy +12 · HP +3",
		"Energy +16 · HP +6",
		"Energy +20 · HP +9",
		"Energy +24 · HP +12",
		"Energy +28 · HP +15",
	],
	"ration": "Energy +8 · HP +4",
}

const ABILITIES_EN := {
	"ab_servo": {
		"name": "Endurance",
		"cat": "Mobility",
		"effect": "Move Speed +0.08 · Drain -0.0012",
		"elite": "Chassis maneuver cooldown -15%",
		"how": "Traverse combat zones · Activate SPACE chassis maneuvers",
	},
	"ab_rack": {
		"name": "Strength",
		"cat": "Physique",
		"effect": "Cargo +1.0 · Load +1.5",
		"elite": "Overload speed penalty -30%",
		"how": "March under heavy/overloaded weight · Extract heavy salvage",
	},
	"ab_frame": {
		"name": "Vitality",
		"cat": "Survival",
		"effect": "Max HP +5",
		"elite": "+25% hull & limb repair from Repair Kits",
		"how": "Endure hostile fire · Perform field repairs on damaged parts",
	},
	"ab_plating": {
		"name": "Heavy Armor",
		"cat": "Armor",
		"effect": "Armor Mitigation +0.8%",
		"elite": "20% less max-HP penalty from limb damage",
		"how": "Mitigate hits with armor · Intercept via shield · Destroy heavies",
	},
	"ab_firearm": {
		"name": "Firearms",
		"cat": "Combat",
		"effect": "Ergonomics +2.2 (tighter spread / faster reload)",
		"elite": "+15% reload speed on both arms",
		"how": "Fire ballistic weapons · Score hits and kills · Tactical reloads",
	},
	"ab_reactor": {
		"name": "Metabolism",
		"cat": "Energy",
		"effect": "Max Energy +5",
		"elite": "+20% energy gain from cells and rations",
		"how": "Expend reactor power · Fire back mounts · Use energy/food supplies",
	},
	"ab_search": {
		"name": "Attention",
		"cat": "Looting",
		"effect": "Search Speed +4% · View +0.25 · Cargo +0.5",
		"elite": "Instantly reveal first item when opening containers",
		"how": "Open containers · Scan hidden slots · Loot high-rarity gear",
	},
	"ab_covert": {
		"name": "Raid Ops",
		"cat": "Tactics",
		"effect": "Evac Timer -2% · Speed +0.04 · Ergo +1.0",
		"elite": "Ballistic gunshot alert radius -15%",
		"how": "Discover landmarks · Deploy tactical gear · Extract & slay bosses",
	},
}

const PODS_EN := {
	"rei": {
		"name": "Deploy Pod A · Rei",
		"role": "Long-Range Marksman · Electromagnetic AP Support",
		"tiers": ["Standard Frame · Electromagnetic Coil Rifle", "Reinforced Frame · HP & Armor Up", "Ace Frame · Full Enhancement"],
	},
	"kurumi": {
		"name": "Deploy Pod B · Kurumi",
		"role": "Close Breacher · Frontline Vanguard",
		"tiers": ["Standard Frame · Shotgun Assault", "Reinforced Frame · HP & Firepower Up", "Ace Frame · Full Enhancement"],
	},
}

const QUEST_NAMES_EN := {
	"ajin": "Ajin",
	"xiaoman": "Xiaoman",
	"shiori": "Shiori",
	"karasu": "Karasu",
	"nihong": "Neon",
	"gin": "Gin",
}

const QUEST_TITLES_EN := {
	"罐头补给": "Canned Stockpile",
	"清理货道": "Clear the Freight Lane",
	"净水配给": "Water Rationing",
	"赤湖踩点": "Redlake Recon",
	"罐头囤积": "Emergency Pantry",
	"线圈补货": "Copper Resupply",
	"甲壳回收": "Shell Recovery",
	"转管订单": "Rotary Gun Order",
	"工业带撤收": "Ironbelt Extraction",
	"壳质样本": "Chitin Samples",
	"喷吐取样": "Spitter Specimen",
	"冷却剂递送": "Coolant Delivery",
	"巢母解剖": "Broodmother Dissection",
	"螺栓清点": "Fastener Audit",
	"破盾作业": "Shieldbreaker Job",
	"盾板交付": "Field Shield Delivery",
	"王虫猎杀": "Beetle King Hunt",
	"电路订货": "PCB Procurement",
	"灰港撤收": "Greyport Exfil",
	"诱饵交付": "Decoy Delivery",
	"指挥链切断": "Sever the Link",
	"小额信用": "Small Chip Settlement",
	"清场作业": "Sweep Contract",
	"大额信用": "High-Value Chips",
	"裂谷撤收": "Quarry Exfil",
}

const WHO_EN := {
	"厨师阿堇": "Chef Ajin",
	"机械师米娅": "Mechanic Mia",
	"装甲工坊": "Armor Workshop",
	"艇上的孩子们": "Kids Aboard Ship",
	"轮机长": "Chief Engineer",
	"调度员莉娜": "Dispatcher Lina",
	"领航员小满": "Navigator Xiaoman",
}

const MERCHANTS_EN := {
	"ajin": {"name": "Ajin", "role": "Rations & Daily Supplies", "tag": "Food, Salvage & Field Supplies", "desc": "Warm, meticulous black-market quartermaster supplying hot rations, water tablets, and basic parts."},
	"xiaoman": {"name": "Xiaoman", "role": "Field Arms & Scrap Broker", "tag": "Firearms, Munitions & Chassis", "desc": "Sharp-tongued surplus broker dealing salvaged firearms, standard weapons, and light frames."},
	"shiori": {"name": "Shiori", "role": "Bio-Crystal & Specimen Broker", "tag": "Abyssal Bioluminescence & Reactors", "desc": "Surviving Abyss Institute scholar buying chitin and crystals for specialized bio-modifications."},
	"karasu": {"name": "Karasu", "role": "Heavy Armor & AP Smith", "tag": "Reactive Armor & Siegemaker Frames", "desc": "Underground forge veteran obsessed with maximum plating thickness and heavy armor-piercing ordnance."},
	"nihong": {"name": "Neon", "role": "Cyber-Salvage & Intel Dealer", "tag": "Coil Weapons, Sensors & Comms", "desc": "Shelter relay hacker decoding pre-war black boxes and dealing radar recon gear and tactical decoys."},
	"gin": {"name": "Gin", "role": "Ash Syndicate Vault Purser", "tag": "High-Risk Bounties & Bullion Exchange", "desc": "Young Ash Syndicate factor wearing a brass monocle, issuing dead-zone bounties and elite frame quotas."},
}

const CREW_ROLE_EN := {
	"nao": "Lead Mech Pilot",
	"rei": "Autonomous Wingmate",
	"kurumi": "Autonomous Wingmate",
	"lina": "Flight Dispatcher",
	"mia": "Chief Rig Mechanic",
	"ajin": "Galley Chef & Quartermaster",
	"xiaoman": "Airship Navigator",
	"shiori": "Bio-Specimen Researcher",
	"karasu": "Ordnance & Armor Artisan",
	"nihong": "Signals & Intel Analyst",
	"gin": "Syndicate Purser",
}

const CHAR_PROFILES_EN := {
	"nao": {"name": "Nao · Shiroishi Nao", "role": "Lead Mech Pilot (Player) · Age 16", "desc": "Silver-gray hair pinned with an old metal clip. Quiet, power-saving, and uncannily precise in combat with a strange fondness for tiny trinkets."},
	"rei": {"name": "Rei · Kuon Rei", "role": "Mech Pilot (Autonomous Wingmate) · Age 16", "desc": "Short silver hair covering her left eye behind a blue-lit monocular lens, carrying three fallen comrades' tags. Watches from behind optics and guards the squad."},
	"kurumi": {"name": "Kurumi · Momose Kurumi", "role": "Mech Pilot (Autonomous Wingmate) · Age 15–16", "desc": "Chestnut twintails tied with yellow zip-ties, bandaged nose, bright orange overalls. Raised on scrapyard routes—fiery, fiercely competitive, and fearless."},
	"lina": {"name": "Lina · Lina Krause", "role": "Dropship 'Griffin' Pilot · Age 17", "desc": "Trim blonde academy graduate flying logistics and extraction. By-the-book on deck, yet refuses to lift off under heavy fire until every pilot is aboard."},
	"mia": {"name": "Mia", "role": "Chief Rig Mechanic · Age 16", "desc": "Crimson bun under a riveted welding mask with heat-proof gloves in her pocket. Perpetually sleep-deprived master mechanic who treats every frame like her child."},
	"ajin": {"name": "Ajin · Su Jin", "role": "Rations & Daily Supplies Broker", "desc": "Gentle, precise quartermaster in an impossibly spotless cream sweater, commanding wide black-market routes for hot cans, purifiers, and field staples."},
	"xiaoman": {"name": "Xiaoman · Lin Xiaoman", "role": "Field Arms & Scrap Broker", "desc": "Amber-eyed bomber-jacket dealer who built her business pulling weapons out of ruins. Blunt, driven, and reliable for standard guns and light chassis."},
	"shiori": {"name": "Shiori · Amagi Shiori", "role": "Contraband Bio & Abyss Sample Broker", "desc": "Former Abyss Research Institute scholar with a bioluminescent beetle on her shoulder. Acquires chitin and crystals for exotic bio-coatings."},
	"karasu": {"name": "Karasu", "role": "Heavy Armor & AP Ordnance Smith", "desc": "Underground workshop craftsman draped in canvas armor and heavy casings, forging reactive plating and sabot ammunition."},
	"nihong": {"name": "Neon", "role": "Pre-War Electronics & Hacker Broker", "desc": "Relay-station cyber-broker wired with monitor headphones and glowing ribbons, cracking old hard drives for recon telemetry and decoys."},
	"gin": {"name": "Gin", "role": "Ash Syndicate Purser & Bounty Broker", "desc": "Young Ash Syndicate factor with a brass monocle and crimson vest, issuing high-stakes bounties and clearing precious bullion for rare mech quotas."},
}

const EMOTION_EN := {
	"沉着": "CALM",
	"冷静": "COOL",
	"凝重": "GRAVE",
	"警戒": "ALERT",
	"急促": "URGENT",
	"惊骇": "SHOCKED",
	"恼火": "IRKED",
	"欣喜": "GLAD",
	"振奋": "RALLIED",
	"自信": "POISED",
	"释然": "RELIEVED",
	"忧虑": "CONCERNED",
	"警觉": "VIGILANT",
	"柔和": "SOFT",
	"低语": "WHISPER",
	"好奇": "CURIOUS",
	"疲惫": "WEARY",
}
