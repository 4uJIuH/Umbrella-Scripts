local script = {}

local HERO_NAME = "npc_dota_hero_keeper_of_the_light"
local ILLUMINATE = "keeper_of_the_light_illuminate"
local ILLUMINATE_END = "keeper_of_the_light_illuminate_end"
local SF_ILLUMINATE = "keeper_of_the_light_spirit_form_illuminate"
local SF_ILLUMINATE_END = "keeper_of_the_light_spirit_form_illuminate_end"
local SPIRIT_FORM_MOD = "modifier_keeper_of_the_light_spirit_form"

local BLINDING_NAMES = {
	"keeper_of_the_light_blinding_light",
	"keeper_of_the_light_spirit_form_blinding_light",
}

local SOLAR_NAMES = {
	"keeper_of_the_light_solar_bind",
	"keeper_of_the_light_spirit_form_solar_bind",
	"keeper_of_the_light_radiant_bind",
}

local SOLAR_MOD = "modifier_keeper_of_the_light_solar_bind"
local SOLAR_SHRED = { 0.20, 0.30, 0.40, 0.50 }
local SOLAR_RANGE = 750.0
local SOLAR_LATENCY = 0.15

local MAX_CHANNEL = 3.0
local CHANNEL_GRACE = 0.5
local CHANNEL_HOLD = 6.0
local ORDER_GAP = 0.06
local ORDER_LOCK = 1.1
local BEAM_SPEED = 900.0
local BEAM_RADIUS = 400.0
local BEAM_RANGE = 1550.0
local RELEASE_LATENCY = 0.07

local ILL_DAMAGE = { 185.0, 290.0, 395.0, 500.0, 605.0 }

local BL_DAMAGE = { 90.0, 140.0, 190.0, 240.0, 290.0 }
local BL_RADIUS = { 425.0, 450.0, 475.0, 500.0, 525.0 }
local BL_CAST_RANGE = { 500.0, 575.0, 650.0, 725.0, 800.0 }
local BL_MIN_PUSH = 175.0
local BL_PUSH_TIME = 0.6
local BL_LATENCY = 0.25
local BL_LEAD = 0.05

local DAGON_DAMAGE = { 400.0, 500.0, 600.0, 700.0, 800.0 }
local DAGON_NAMES = { "item_dagon", "item_dagon_2", "item_dagon_3", "item_dagon_4", "item_dagon_5" }
local DAGON_RANGE = { 700.0, 730.0, 760.0, 790.0, 820.0 }
local DAGON_LATENCY = 0.15

local ETHEREAL_ITEM = "item_ethereal_blade"
local ETHEREAL_MOD = "modifier_item_ethereal_blade_ethereal"
local ETHEREAL_AMP = 0.40
local ETHEREAL_RANGE = 800.0
local ETHEREAL_SPEED = 1200.0
local ETHEREAL_LATENCY = 0.15

local VEIL_ITEM = "item_veil_of_discord"
local VEIL_MOD = "modifier_item_veil_of_discord_debuff"
local VEIL_SHRED = 0.20
local VEIL_RANGE = 1600.0
local VEIL_RADIUS = 600.0
local VEIL_LATENCY = 0.15

local VESSEL_ITEM = "item_spirit_vessel"
local VESSEL_MOD = "modifier_item_spirit_vessel_damage"
local VESSEL_DRAIN = 0.04
local VESSEL_RANGE = 600.0
local VESSEL_SPEED = 1000.0
local VESSEL_LATENCY = 0.15

local FINISH_WINDOW = 4.0

local TALENT_BONUS = 200.0
local ILL_TALENTS = {
	"special_bonus_unique_keeper_of_the_light_illuminate_damage",
	"special_bonus_unique_keeper_of_the_light_9",
	"special_bonus_unique_keeper_of_the_light_8",
	"special_bonus_unique_keeper_of_the_light_7",
	"special_bonus_unique_keeper_of_the_light_6",
	"special_bonus_unique_keeper_of_the_light",
}

local SOLAR_TALENTS = {
	"special_bonus_unique_keeper_of_the_light_solar_bind_resistance",
	"special_bonus_unique_keeper_of_the_light_solar_bind",
	"special_bonus_unique_keeper_of_the_light_12",
	"special_bonus_unique_keeper_of_the_light_11",
	"special_bonus_unique_keeper_of_the_light_10",
}

local BL_TALENTS = {
	"special_bonus_unique_keeper_of_the_light_blinding_light_damage",
	"special_bonus_unique_keeper_of_the_light_5",
	"special_bonus_unique_keeper_of_the_light_4",
	"special_bonus_unique_keeper_of_the_light_3",
}

local KAYA_ITEMS = {
	{ "item_kaya", 0.10 },
	{ "item_kaya_and_sange", 0.12 },
	{ "item_yasha_and_kaya", 0.12 },
}

local COLOR_KILL = Color(70, 255, 110, 255)
local COLOR_LOW = Color(255, 70, 70, 255)
local COLOR_SHADOW = Color(0, 0, 0, 200)

local TEXT = {
	grp_main = { "Illuminate", "\u{5149}\u{7167}", "\u{418}\u{43b}\u{43b}\u{44e}\u{43c}\u{438}\u{43d}\u{430}\u{442}" },
	grp_items = { "Combo items", "\u{8fde}\u{62db}\u{9053}\u{5177}", "\u{41f}\u{440}\u{435}\u{434}\u{43c}\u{435}\u{442}\u{44b} \u{43a}\u{43e}\u{43c}\u{431}\u{43e}" },
	grp_visuals = { "Visuals", "\u{89c6}\u{89c9}\u{6548}\u{679c}", "\u{412}\u{438}\u{437}\u{443}\u{430}\u{43b}" },
	grp_lang = { "Language", "\u{8bed}\u{8a00}", "\u{42f}\u{437}\u{44b}\u{43a}" },
	lang = { "Language", "\u{8bed}\u{8a00}", "\u{42f}\u{437}\u{44b}\u{43a}" },
	warn_top = { "WARNING", "\u{8b66}\u{544a}", "\u{41f}\u{420}\u{415}\u{414}\u{423}\u{41f}\u{420}\u{415}\u{416}\u{414}\u{415}\u{41d}\u{418}\u{415}" },
	warn_body = { "Script is not safe, use at your own risk", "\u{6b64}\u{811a}\u{672c}\u{4e0d}\u{5b89}\u{5168}\u{ff0c}\u{4f7f}\u{7528}\u{98ce}\u{9669}\u{81ea}\u{8d1f}", "\u{441}\u{43a}\u{440}\u{438}\u{43f}\u{442} \u{43d}\u{435}\u{431}\u{435}\u{437}\u{43e}\u{43f}\u{430}\u{441}\u{435}\u{43d}, \u{438}\u{441}\u{43f}\u{43e}\u{43b}\u{44c}\u{437}\u{43e}\u{432}\u{430}\u{442}\u{44c} \u{43d}\u{430} \u{441}\u{432}\u{43e}\u{439} \u{441}\u{442}\u{440}\u{430}\u{445} \u{438} \u{440}\u{438}\u{441}\u{43a}" },
	warn_bottom = { "WARNING", "\u{8b66}\u{544a}", "\u{41f}\u{420}\u{415}\u{414}\u{423}\u{41f}\u{420}\u{415}\u{416}\u{414}\u{415}\u{41d}\u{418}\u{415}" },
	enable = { "Enable auto Illuminate", "\u{542f}\u{7528}\u{81ea}\u{52a8}\u{5149}\u{7167}", "\u{412}\u{43a}\u{43b}\u{44e}\u{447}\u{438}\u{442}\u{44c} \u{430}\u{432}\u{442}\u{43e} Illuminate" },
	key = { "Illuminate key", "\u{5149}\u{7167}\u{6309}\u{952e}", "\u{41a}\u{43b}\u{430}\u{432}\u{438}\u{448}\u{430} Illuminate" },
	min_channel = { "Min channel", "\u{6700}\u{77ed}\u{5f15}\u{5bfc}\u{65f6}\u{95f4}", "\u{41c}\u{438}\u{43d}. \u{432}\u{440}\u{435}\u{43c}\u{44f} \u{43a}\u{430}\u{441}\u{442}\u{430}" },
	latency = { "Travel safety", "\u{5ef6}\u{8fdf}\u{8865}\u{507f}", "\u{417}\u{430}\u{43f}\u{430}\u{441} \u{43d}\u{430} \u{437}\u{430}\u{434}\u{435}\u{440}\u{436}\u{43a}\u{443}" },
	max_range = { "Max beam distance", "\u{6700}\u{5927}\u{5149}\u{675f}\u{8ddd}\u{79bb}", "\u{41c}\u{430}\u{43a}\u{441}. \u{434}\u{438}\u{441}\u{442}\u{430}\u{43d}\u{446}\u{438}\u{44f} \u{43b}\u{443}\u{447}\u{430}" },
	predict = { "Predict target movement", "\u{9884}\u{6d4b}\u{76ee}\u{6807}\u{79fb}\u{52a8}", "\u{41f}\u{440}\u{435}\u{434}\u{441}\u{43a}\u{430}\u{437}\u{430}\u{43d}\u{438}\u{435} \u{434}\u{432}\u{438}\u{436}\u{435}\u{43d}\u{438}\u{44f}" },
	blinding = { "Smart Blinding Light", "\u{667a}\u{80fd}\u{81f4}\u{76f2}\u{4e4b}\u{5149}", "\u{423}\u{43c}\u{43d}\u{44b}\u{439} Blinding Light" },
	blind_after = { "Blinding Light after release", "\u{91ca}\u{653e}\u{540e}\u{4f7f}\u{7528}\u{81f4}\u{76f2}\u{4e4b}\u{5149}", "Blinding Light \u{43f}\u{43e}\u{441}\u{43b}\u{435} \u{432}\u{44b}\u{441}\u{442}\u{440}\u{435}\u{43b}\u{430}" },
	blind_finish = { "Blinding Light as finisher", "\u{7528}\u{81f4}\u{76f2}\u{4e4b}\u{5149}\u{6536}\u{5c3e}\u{8fde}\u{62db}", "Blinding Light \u{432} \u{43a}\u{43e}\u{43d}\u{446}\u{435} \u{43a}\u{43e}\u{43c}\u{431}\u{43e}" },
	auto_lethal = { "Lethal damage is calculated automatically", "\u{81f4}\u{547d}\u{4f24}\u{5bb3}\u{7531}\u{811a}\u{672c}\u{81ea}\u{52a8}\u{8ba1}\u{7b97}", "\u{41b}\u{435}\u{442}\u{430}\u{43b}\u{44c}\u{43d}\u{44b}\u{439} \u{443}\u{440}\u{43e}\u{43d} \u{441}\u{447}\u{438}\u{442}\u{430}\u{435}\u{442}\u{441}\u{44f} \u{430}\u{432}\u{442}\u{43e}\u{43c}\u{430}\u{442}\u{438}\u{447}\u{435}\u{441}\u{43a}\u{438}" },
	solar = { "Combo Solar Bind", "\u{8fde}\u{62db} \u{592a}\u{9633}\u{675f}\u{7f1a}", "\u{41a}\u{43e}\u{43c}\u{431}\u{43e} Solar Bind" },
	dagon = { "Combo Dagon", "\u{8fde}\u{62db} \u{8fbe}\u{8d21}", "\u{41a}\u{43e}\u{43c}\u{431}\u{43e} Dagon" },
	ethereal = { "Combo Ethereal Blade", "\u{8fde}\u{62db} \u{5e7d}\u{9b42}\u{6743}\u{6756}", "\u{41a}\u{43e}\u{43c}\u{431}\u{43e} Ethereal Blade" },
	veil = { "Combo Veil of Discord", "\u{8fde}\u{62db} \u{7eb7}\u{4e89}\u{9762}\u{7eb1}", "\u{41a}\u{43e}\u{43c}\u{431}\u{43e} Veil of Discord" },
	vessel = { "Combo Spirit Vessel", "\u{8fde}\u{62db} \u{7075}\u{9b42}\u{4e4b}\u{5323}", "\u{41a}\u{43e}\u{43c}\u{431}\u{43e} Spirit Vessel" },
	mana = { "Mana reserve", "\u{4fdd}\u{7559}\u{9b54}\u{6cd5}\u{503c}", "\u{420}\u{435}\u{437}\u{435}\u{440}\u{432} \u{43c}\u{430}\u{43d}\u{44b}" },
	finish = { "Auto finish after shot", "\u{5c04}\u{51fb}\u{540e}\u{81ea}\u{52a8}\u{8865}\u{5200}", "\u{410}\u{432}\u{442}\u{43e}\u{434}\u{43e}\u{431}\u{438}\u{432}\u{430}\u{43d}\u{438}\u{435}" },
	esp = { "Damage ESP", "\u{4f24}\u{5bb3}\u{663e}\u{793a}", "\u{41e}\u{442}\u{43e}\u{431}\u{440}\u{430}\u{436}\u{435}\u{43d}\u{438}\u{435} \u{443}\u{440}\u{43e}\u{43d}\u{430}" },
	esp_size = { "Text size", "\u{5b57}\u{4f53}\u{5927}\u{5c0f}", "\u{420}\u{430}\u{437}\u{43c}\u{435}\u{440} \u{442}\u{435}\u{43a}\u{441}\u{442}\u{430}" },
	esp_need = { "Need", "\u{8fd8}\u{9700}", "\u{41d}\u{443}\u{436}\u{43d}\u{43e}" },
	esp_nokill = { "no kill", "\u{65e0}\u{6cd5}\u{51fb}\u{6740}", "\u{43d}\u{435} \u{443}\u{431}\u{438}\u{442}\u{44c}" },
}

local TIP = {
	enable = {
		"Master switch of the whole auto Illuminate logic. When it is off the script only draws the damage text and never releases the beam.",
		"\u{81ea}\u{52a8}\u{5149}\u{7167}\u{903b}\u{8f91}\u{7684}\u{603b}\u{5f00}\u{5173}\u{3002}\u{5173}\u{95ed}\u{65f6}\u{811a}\u{672c}\u{53ea}\u{7ed8}\u{5236}\u{4f24}\u{5bb3}\u{6587}\u{5b57}\u{ff0c}\u{4e0d}\u{4f1a}\u{91ca}\u{653e}\u{5149}\u{675f}\u{3002}",
		"\u{413}\u{43b}\u{430}\u{432}\u{43d}\u{44b}\u{439} \u{43f}\u{435}\u{440}\u{435}\u{43a}\u{43b}\u{44e}\u{447}\u{430}\u{442}\u{435}\u{43b}\u{44c} \u{432}\u{441}\u{435}\u{439} \u{43b}\u{43e}\u{433}\u{438}\u{43a}\u{438} \u{430}\u{432}\u{442}\u{43e} Illuminate. \u{41a}\u{43e}\u{433}\u{434}\u{430} \u{432}\u{44b}\u{43a}\u{43b}\u{44e}\u{447}\u{435}\u{43d}, \u{441}\u{43a}\u{440}\u{438}\u{43f}\u{442} \u{442}\u{43e}\u{43b}\u{44c}\u{43a}\u{43e} \u{440}\u{438}\u{441}\u{443}\u{435}\u{442} \u{443}\u{440}\u{43e}\u{43d} \u{438} \u{43d}\u{438}\u{43a}\u{43e}\u{433}\u{434}\u{430} \u{43d}\u{435} \u{43e}\u{442}\u{43f}\u{443}\u{441}\u{43a}\u{430}\u{435}\u{442} \u{43b}\u{443}\u{447}.",
	},
	key = {
		"The key you use for Illuminate. The script watches this key to understand that you started charging the beam.",
		"\u{4f60}\u{7528}\u{4e8e}\u{5149}\u{7167}\u{7684}\u{6309}\u{952e}\u{3002}\u{811a}\u{672c}\u{76d1}\u{542c}\u{8be5}\u{6309}\u{952e}\u{ff0c}\u{4ee5}\u{4e86}\u{89e3}\u{4f60}\u{5f00}\u{59cb}\u{84c4}\u{529b}\u{3002}",
		"\u{41a}\u{43b}\u{430}\u{432}\u{438}\u{448}\u{430}, \u{43d}\u{430} \u{43a}\u{43e}\u{442}\u{43e}\u{440}\u{443}\u{44e} \u{443} \u{442}\u{435}\u{431}\u{44f} \u{43f}\u{43e}\u{432}\u{435}\u{448}\u{435}\u{43d} Illuminate. \u{421}\u{43a}\u{440}\u{438}\u{43f}\u{442} \u{441}\u{43b}\u{435}\u{434}\u{438}\u{442} \u{437}\u{430} \u{43d}\u{435}\u{439}, \u{447}\u{442}\u{43e}\u{431}\u{44b} \u{43f}\u{43e}\u{43d}\u{44f}\u{442}\u{44c}, \u{447}\u{442}\u{43e} \u{442}\u{44b} \u{43d}\u{430}\u{447}\u{430}\u{43b} \u{43a}\u{43e}\u{43f}\u{438}\u{442}\u{44c} \u{43b}\u{443}\u{447}.",
	},
	min_channel = {
		"Minimum charge time before the script is allowed to release. Useful when you want at least some beam damage instead of an instant tap.",
		"\u{811a}\u{672c}\u{5141}\u{8bb8}\u{91ca}\u{653e}\u{524d}\u{7684}\u{6700}\u{77ed}\u{84c4}\u{529b}\u{65f6}\u{95f4}\u{3002}\u{5f53}\u{4f60}\u{5e0c}\u{671b}\u{81f3}\u{5c11}\u{79ef}\u{7d2f}\u{4e00}\u{4e9b}\u{5149}\u{675f}\u{4f24}\u{5bb3}\u{800c}\u{4e0d}\u{662f}\u{77ac}\u{53d1}\u{65f6}\u{5f88}\u{6709}\u{7528}\u{3002}",
		"\u{41c}\u{438}\u{43d}\u{438}\u{43c}\u{430}\u{43b}\u{44c}\u{43d}\u{43e}\u{435} \u{432}\u{440}\u{435}\u{43c}\u{44f} \u{43d}\u{430}\u{43a}\u{43e}\u{43f}\u{43b}\u{435}\u{43d}\u{438}\u{44f}, \u{434}\u{43e} \u{43a}\u{43e}\u{442}\u{43e}\u{440}\u{43e}\u{433}\u{43e} \u{441}\u{43a}\u{440}\u{438}\u{43f}\u{442}\u{443} \u{43d}\u{435}\u{43b}\u{44c}\u{437}\u{44f} \u{43e}\u{442}\u{43f}\u{443}\u{441}\u{43a}\u{430}\u{442}\u{44c} \u{43b}\u{443}\u{447}. \u{41f}\u{43e}\u{43b}\u{435}\u{437}\u{43d}\u{43e}, \u{435}\u{441}\u{43b}\u{438} \u{445}\u{43e}\u{447}\u{435}\u{448}\u{44c} \u{445}\u{43e}\u{442}\u{44f} \u{431}\u{44b} \u{43d}\u{435}\u{43c}\u{43d}\u{43e}\u{433}\u{43e} \u{443}\u{440}\u{43e}\u{43d}\u{430} \u{43b}\u{443}\u{447}\u{430}, \u{430} \u{43d}\u{435} \u{43c}\u{433}\u{43d}\u{43e}\u{432}\u{435}\u{43d}\u{43d}\u{44b}\u{439} \u{442}\u{44b}\u{43a}.",
	},
	latency = {
		"Ping and reaction compensation in milliseconds. The script adds this time to the charge it expects to have at the moment the server receives the release.",
		"\u{4ee5}\u{6beb}\u{79d2}\u{8ba1}\u{7684}\u{5ef6}\u{8fdf}\u{4e0e}\u{53cd}\u{5e94}\u{8865}\u{507f}\u{3002}\u{811a}\u{672c}\u{4f1a}\u{628a}\u{8fd9}\u{6bb5}\u{65f6}\u{95f4}\u{52a0}\u{5230}\u{670d}\u{52a1}\u{5668}\u{6536}\u{5230}\u{91ca}\u{653e}\u{547d}\u{4ee4}\u{65f6}\u{9884}\u{671f}\u{7684}\u{84c4}\u{529b}\u{4e0a}\u{3002}",
		"\u{41a}\u{43e}\u{43c}\u{43f}\u{435}\u{43d}\u{441}\u{430}\u{446}\u{438}\u{44f} \u{43f}\u{438}\u{43d}\u{433}\u{430} \u{438} \u{440}\u{435}\u{430}\u{43a}\u{446}\u{438}\u{438} \u{432} \u{43c}\u{438}\u{43b}\u{43b}\u{438}\u{441}\u{435}\u{43a}\u{443}\u{43d}\u{434}\u{430}\u{445}. \u{421}\u{43a}\u{440}\u{438}\u{43f}\u{442} \u{434}\u{43e}\u{431}\u{430}\u{432}\u{43b}\u{44f}\u{435}\u{442} \u{44d}\u{442}\u{43e} \u{432}\u{440}\u{435}\u{43c}\u{44f} \u{43a} \u{43d}\u{430}\u{43a}\u{43e}\u{43f}\u{43b}\u{435}\u{43d}\u{438}\u{44e}, \u{43a}\u{43e}\u{442}\u{43e}\u{440}\u{43e}\u{435} \u{431}\u{443}\u{434}\u{435}\u{442} \u{43d}\u{430} \u{43c}\u{43e}\u{43c}\u{435}\u{43d}\u{442}, \u{43a}\u{43e}\u{433}\u{434}\u{430} \u{441}\u{435}\u{440}\u{432}\u{435}\u{440} \u{43f}\u{43e}\u{43b}\u{443}\u{447}\u{438}\u{442} \u{43e}\u{442}\u{43f}\u{443}\u{441}\u{43a}\u{430}\u{43d}\u{438}\u{435}.",
	},
	max_range = {
		"Maximum beam distance the script works with. Lower it if you want the script to ignore enemies that are far away at the edge of the beam.",
		"\u{811a}\u{672c}\u{4f7f}\u{7528}\u{7684}\u{6700}\u{5927}\u{5149}\u{675f}\u{8ddd}\u{79bb}\u{3002}\u{5982}\u{679c}\u{4f60}\u{5e0c}\u{671b}\u{5ffd}\u{7565}\u{5149}\u{675f}\u{8fb9}\u{7f18}\u{7684}\u{8fdc}\u{65b9}\u{654c}\u{4eba}\u{ff0c}\u{5c31}\u{8c03}\u{4f4e}\u{5b83}\u{3002}",
		"\u{41c}\u{430}\u{43a}\u{441}\u{438}\u{43c}\u{430}\u{43b}\u{44c}\u{43d}\u{430}\u{44f} \u{434}\u{438}\u{441}\u{442}\u{430}\u{43d}\u{446}\u{438}\u{44f} \u{43b}\u{443}\u{447}\u{430}, \u{441} \u{43a}\u{43e}\u{442}\u{43e}\u{440}\u{43e}\u{439} \u{440}\u{430}\u{431}\u{43e}\u{442}\u{430}\u{435}\u{442} \u{441}\u{43a}\u{440}\u{438}\u{43f}\u{442}. \u{421}\u{43d}\u{438}\u{437}\u{44c} \u{435}\u{451}, \u{435}\u{441}\u{43b}\u{438} \u{445}\u{43e}\u{447}\u{435}\u{448}\u{44c} \u{438}\u{433}\u{43d}\u{43e}\u{440}\u{438}\u{440}\u{43e}\u{432}\u{430}\u{442}\u{44c} \u{434}\u{430}\u{43b}\u{451}\u{43a}\u{438}\u{445} \u{432}\u{440}\u{430}\u{433}\u{43e}\u{432} \u{43d}\u{430} \u{43a}\u{440}\u{430}\u{44e} \u{43b}\u{443}\u{447}\u{430}.",
	},
	predict = {
		"Predicts where the target will be while the beam is flying and counts the hit by that predicted position instead of the current one.",
		"\u{9884}\u{6d4b}\u{5149}\u{675f}\u{98de}\u{884c}\u{671f}\u{95f4}\u{76ee}\u{6807}\u{7684}\u{4f4d}\u{7f6e}\u{ff0c}\u{5e76}\u{6309}\u{9884}\u{6d4b}\u{4f4d}\u{7f6e}\u{800c}\u{4e0d}\u{662f}\u{5f53}\u{524d}\u{4f4d}\u{7f6e}\u{8ba1}\u{7b97}\u{547d}\u{4e2d}\u{3002}",
		"\u{41f}\u{440}\u{435}\u{434}\u{441}\u{43a}\u{430}\u{437}\u{44b}\u{432}\u{430}\u{435}\u{442}, \u{433}\u{434}\u{435} \u{431}\u{443}\u{434}\u{435}\u{442} \u{446}\u{435}\u{43b}\u{44c} \u{43f}\u{43e}\u{43a}\u{430} \u{43b}\u{435}\u{442}\u{438}\u{442} \u{43b}\u{443}\u{447}, \u{438} \u{441}\u{447}\u{438}\u{442}\u{430}\u{435}\u{442} \u{43f}\u{43e}\u{43f}\u{430}\u{434}\u{430}\u{43d}\u{438}\u{435} \u{43f}\u{43e} \u{44d}\u{442}\u{43e}\u{439} \u{442}\u{43e}\u{447}\u{43a}\u{435}, \u{430} \u{43d}\u{435} \u{43f}\u{43e} \u{442}\u{435}\u{43a}\u{443}\u{449}\u{435}\u{439}.",
	},
	blinding = {
		"Smart Blinding Light. If the enemy stands outside the beam, the script finds a cast point so the knockback pushes the enemy right under the beam. It no longer presses the spell as soon as the charge starts, it waits and casts right before the release, so the enemy has no time to react, and it only does that when the total damage is still lethal.",
		"\u{667a}\u{80fd}\u{81f4}\u{76f2}\u{4e4b}\u{5149}\u{3002}\u{5982}\u{679c}\u{654c}\u{4eba}\u{7ad9}\u{5728}\u{5149}\u{675f}\u{5916}\u{ff0c}\u{811a}\u{672c}\u{4f1a}\u{8ba1}\u{7b97}\u{4e00}\u{4e2a}\u{65bd}\u{6cd5}\u{70b9}\u{ff0c}\u{8ba9}\u{51fb}\u{9000}\u{628a}\u{654c}\u{4eba}\u{63a8}\u{5230}\u{5149}\u{675f}\u{4e0b}\u{65b9}\u{3002}\u{5b83}\u{4e0d}\u{4f1a}\u{5728}\u{84c4}\u{529b}\u{4e00}\u{5f00}\u{59cb}\u{5c31}\u{6309}\u{4e0b}\u{ff0c}\u{800c}\u{662f}\u{7b49}\u{5230}\u{91ca}\u{653e}\u{524d}\u{7684}\u{4e00}\u{77ac}\u{624d}\u{65bd}\u{653e}\u{ff0c}\u{8ba9}\u{654c}\u{4eba}\u{6765}\u{4e0d}\u{53ca}\u{53cd}\u{5e94}\u{ff0c}\u{5e76}\u{4e14}\u{53ea}\u{6709}\u{5728}\u{603b}\u{4f24}\u{5bb3}\u{4ecd}\u{80fd}\u{81f4}\u{6b7b}\u{65f6}\u{624d}\u{4f1a}\u{8fd9}\u{4e48}\u{505a}\u{3002}",
		"\u{423}\u{43c}\u{43d}\u{44b}\u{439} Blinding Light. \u{415}\u{441}\u{43b}\u{438} \u{432}\u{440}\u{430}\u{433} \u{432}\u{43d}\u{435} \u{437}\u{43e}\u{43d}\u{44b} \u{43b}\u{443}\u{447}\u{430}, \u{441}\u{43a}\u{440}\u{438}\u{43f}\u{442} \u{441}\u{447}\u{438}\u{442}\u{430}\u{435}\u{442} \u{442}\u{43e}\u{447}\u{43a}\u{443} \u{43a}\u{430}\u{441}\u{442}\u{430} \u{442}\u{430}\u{43a}, \u{447}\u{442}\u{43e}\u{431}\u{44b} \u{43e}\u{442}\u{431}\u{440}\u{430}\u{441}\u{44b}\u{432}\u{430}\u{43d}\u{438}\u{435} \u{437}\u{430}\u{433}\u{43d}\u{430}\u{43b}\u{43e} \u{435}\u{433}\u{43e} \u{43f}\u{43e}\u{434} \u{43b}\u{443}\u{447}. \u{422}\u{435}\u{43f}\u{435}\u{440}\u{44c} \u{43e}\u{43d} \u{43d}\u{435} \u{436}\u{43c}\u{451}\u{442} \u{441}\u{43a}\u{438}\u{43b}\u{43b} \u{441}\u{440}\u{430}\u{437}\u{443} \u{43d}\u{430} \u{441}\u{442}\u{430}\u{440}\u{442}\u{435} \u{43d}\u{430}\u{43a}\u{43e}\u{43f}\u{43b}\u{435}\u{43d}\u{438}\u{44f}, \u{430} \u{43a}\u{430}\u{441}\u{442}\u{443}\u{435}\u{442} \u{43f}\u{440}\u{44f}\u{43c}\u{43e} \u{43f}\u{435}\u{440}\u{435}\u{434} \u{432}\u{44b}\u{441}\u{442}\u{440}\u{435}\u{43b}\u{43e}\u{43c}, \u{447}\u{442}\u{43e}\u{431}\u{44b} \u{432}\u{440}\u{430}\u{433} \u{43d}\u{435} \u{443}\u{441}\u{43f}\u{435}\u{43b} \u{441}\u{440}\u{435}\u{430}\u{433}\u{438}\u{440}\u{43e}\u{432}\u{430}\u{442}\u{44c}, \u{438} \u{442}\u{43e}\u{43b}\u{44c}\u{43a}\u{43e} \u{435}\u{441}\u{43b}\u{438} \u{441}\u{443}\u{43c}\u{43c}\u{430}\u{440}\u{43d}\u{43e}\u{433}\u{43e} \u{443}\u{440}\u{43e}\u{43d}\u{430} \u{432}\u{441}\u{451} \u{440}\u{430}\u{432}\u{43d}\u{43e} \u{445}\u{432}\u{430}\u{442}\u{430}\u{435}\u{442} \u{43d}\u{430} \u{443}\u{431}\u{438}\u{439}\u{441}\u{442}\u{432}\u{43e}.",
	},
	blind_after = {
		"Allows Blinding Light right after the release, while the beam is still flying. It pushes the enemy into the beam path when there was no time to do it during the charge.",
		"\u{5141}\u{8bb8}\u{5728}\u{91ca}\u{653e}\u{4e4b}\u{540e}\u{3001}\u{5149}\u{675f}\u{8fd8}\u{5728}\u{98de}\u{884c}\u{65f6}\u{4f7f}\u{7528}\u{81f4}\u{76f2}\u{4e4b}\u{5149}\u{3002}\u{5f53}\u{84c4}\u{529b}\u{671f}\u{95f4}\u{6765}\u{4e0d}\u{53ca}\u{65f6}\u{ff0c}\u{5b83}\u{4f1a}\u{628a}\u{654c}\u{4eba}\u{63a8}\u{8fdb}\u{5149}\u{675f}\u{8def}\u{5f84}\u{3002}",
		"\u{420}\u{430}\u{437}\u{440}\u{435}\u{448}\u{430}\u{435}\u{442} Blinding Light \u{441}\u{440}\u{430}\u{437}\u{443} \u{43f}\u{43e}\u{441}\u{43b}\u{435} \u{432}\u{44b}\u{441}\u{442}\u{440}\u{435}\u{43b}\u{430}, \u{43f}\u{43e}\u{43a}\u{430} \u{43b}\u{443}\u{447} \u{435}\u{449}\u{451} \u{43b}\u{435}\u{442}\u{438}\u{442}. \u{417}\u{430}\u{433}\u{43e}\u{43d}\u{44f}\u{435}\u{442} \u{432}\u{440}\u{430}\u{433}\u{430} \u{43f}\u{43e}\u{434} \u{43b}\u{443}\u{447}, \u{43a}\u{43e}\u{433}\u{434}\u{430} \u{441}\u{434}\u{435}\u{43b}\u{430}\u{442}\u{44c} \u{44d}\u{442}\u{43e} \u{432}\u{43e} \u{432}\u{440}\u{435}\u{43c}\u{44f} \u{43d}\u{430}\u{43a}\u{43e}\u{43f}\u{43b}\u{435}\u{43d}\u{438}\u{44f} \u{443}\u{436}\u{435} \u{43d}\u{435} \u{443}\u{441}\u{43f}\u{435}\u{432}\u{430}\u{43b}\u{43e}\u{441}\u{44c}.",
	},
	blind_finish = {
		"Always casts Blinding Light at the very end of the combo, right after Dagon, Ethereal Blade or Spirit Vessel, even when the target stands still. The cast point is chosen so the knockback pushes the enemy along the beam and never out of it.",
		"\u{603b}\u{662f}\u{5728}\u{8fde}\u{62db}\u{7684}\u{6700}\u{540e}\u{91ca}\u{653e}\u{81f4}\u{76f2}\u{4e4b}\u{5149}\u{ff0c}\u{7d27}\u{8ddf}\u{5728}\u{8fbe}\u{8d21}\u{3001}\u{5e7d}\u{9b42}\u{6743}\u{6756}\u{6216}\u{7075}\u{9b42}\u{4e4b}\u{5323}\u{4e4b}\u{540e}\u{ff0c}\u{5373}\u{4f7f}\u{76ee}\u{6807}\u{7ad9}\u{7740}\u{4e0d}\u{52a8}\u{4e5f}\u{4f1a}\u{91ca}\u{653e}\u{3002}\u{65bd}\u{6cd5}\u{70b9}\u{7ecf}\u{8fc7}\u{8ba1}\u{7b97}\u{ff0c}\u{4f7f}\u{51fb}\u{9000}\u{6cbf}\u{7740}\u{5149}\u{675f}\u{65b9}\u{5411}\u{63a8}\u{52a8}\u{654c}\u{4eba}\u{ff0c}\u{800c}\u{4e0d}\u{4f1a}\u{628a}\u{4ed6}\u{63a8}\u{51fa}\u{5149}\u{675f}\u{3002}",
		"\u{412}\u{441}\u{435}\u{433}\u{434}\u{430} \u{43a}\u{430}\u{441}\u{442}\u{443}\u{435}\u{442} Blinding Light \u{432} \u{441}\u{430}\u{43c}\u{43e}\u{43c} \u{43a}\u{43e}\u{43d}\u{446}\u{435} \u{43a}\u{43e}\u{43c}\u{431}\u{43e}, \u{441}\u{440}\u{430}\u{437}\u{443} \u{43f}\u{43e}\u{441}\u{43b}\u{435} Dagon, Ethereal Blade \u{438}\u{43b}\u{438} Spirit Vessel, \u{434}\u{430}\u{436}\u{435} \u{435}\u{441}\u{43b}\u{438} \u{446}\u{435}\u{43b}\u{44c} \u{441}\u{442}\u{43e}\u{438}\u{442} \u{43d}\u{430} \u{43c}\u{435}\u{441}\u{442}\u{435}. \u{422}\u{43e}\u{447}\u{43a}\u{430} \u{43a}\u{430}\u{441}\u{442}\u{430} \u{43f}\u{43e}\u{434}\u{431}\u{438}\u{440}\u{430}\u{435}\u{442}\u{441}\u{44f} \u{442}\u{430}\u{43a}, \u{447}\u{442}\u{43e}\u{431}\u{44b} \u{43e}\u{442}\u{442}\u{430}\u{43b}\u{43a}\u{438}\u{432}\u{430}\u{43d}\u{438}\u{435} \u{442}\u{43e}\u{43b}\u{43a}\u{430}\u{43b}\u{43e} \u{432}\u{440}\u{430}\u{433}\u{430} \u{432}\u{434}\u{43e}\u{43b}\u{44c} \u{43b}\u{443}\u{447}\u{430}, \u{430} \u{43d}\u{435} \u{438}\u{437} \u{43d}\u{435}\u{433}\u{43e}.",
	},
	auto_lethal = {
		"The kill threshold is computed by the script itself. It includes magic resistance, Veil, Solar Bind and Ethereal amplification, health regeneration during the beam flight, magic barriers and a ping cushion, so the combo of spells and items is lethal on its own and you never finish by hand.",
		"\u{51fb}\u{6740}\u{9608}\u{503c}\u{7531}\u{811a}\u{672c}\u{81ea}\u{884c}\u{8ba1}\u{7b97}\u{ff0c}\u{5305}\u{542b}\u{9b54}\u{6cd5}\u{62b5}\u{6297}\u{3001}\u{7eb7}\u{4e89}\u{9762}\u{7eb1}\u{3001}\u{592a}\u{9633}\u{675f}\u{7f1a}\u{548c}\u{5e7d}\u{9b42}\u{6743}\u{6756}\u{7684}\u{589e}\u{4f24}\u{3001}\u{5149}\u{675f}\u{98de}\u{884c}\u{671f}\u{95f4}\u{7684}\u{751f}\u{547d}\u{56de}\u{590d}\u{3001}\u{9b54}\u{6cd5}\u{62a4}\u{76fe}\u{4ee5}\u{53ca}\u{5ef6}\u{8fdf}\u{4f59}\u{91cf}\u{ff0c}\u{56e0}\u{6b64}\u{4ec5}\u{9760}\u{6280}\u{80fd}\u{548c}\u{9053}\u{5177}\u{7684}\u{8fde}\u{62db}\u{5c31}\u{8db3}\u{4ee5}\u{81f4}\u{547d}\u{ff0c}\u{65e0}\u{9700}\u{624b}\u{52a8}\u{8865}\u{5200}\u{3002}",
		"\u{41f}\u{43e}\u{440}\u{43e}\u{433} \u{443}\u{431}\u{438}\u{439}\u{441}\u{442}\u{432}\u{430} \u{441}\u{43a}\u{440}\u{438}\u{43f}\u{442} \u{441}\u{447}\u{438}\u{442}\u{430}\u{435}\u{442} \u{441}\u{430}\u{43c}. \u{41e}\u{43d} \u{443}\u{447}\u{438}\u{442}\u{44b}\u{432}\u{430}\u{435}\u{442} \u{43c}\u{430}\u{433}\u{438}\u{447}\u{435}\u{441}\u{43a}\u{43e}\u{435} \u{441}\u{43e}\u{43f}\u{440}\u{43e}\u{442}\u{438}\u{432}\u{43b}\u{435}\u{43d}\u{438}\u{435}, Veil, Solar Bind \u{438} \u{443}\u{441}\u{438}\u{43b}\u{435}\u{43d}\u{438}\u{435} \u{43e}\u{442} Ethereal, \u{440}\u{435}\u{433}\u{435}\u{43d} \u{446}\u{435}\u{43b}\u{438} \u{437}\u{430} \u{432}\u{440}\u{435}\u{43c}\u{44f} \u{43f}\u{43e}\u{43b}\u{451}\u{442}\u{430} \u{43b}\u{443}\u{447}\u{430}, \u{43c}\u{430}\u{433}\u{438}\u{447}\u{435}\u{441}\u{43a}\u{438}\u{435} \u{431}\u{430}\u{440}\u{44c}\u{435}\u{440}\u{44b} \u{438} \u{437}\u{430}\u{43f}\u{430}\u{441} \u{43d}\u{430} \u{43f}\u{438}\u{43d}\u{433}, \u{43f}\u{43e}\u{44d}\u{442}\u{43e}\u{43c}\u{443} \u{43a}\u{43e}\u{43c}\u{431}\u{43e} \u{438}\u{437} \u{441}\u{43f}\u{43e}\u{441}\u{43e}\u{431}\u{43d}\u{43e}\u{441}\u{442}\u{435}\u{439} \u{438} \u{43f}\u{440}\u{435}\u{434}\u{43c}\u{435}\u{442}\u{43e}\u{432} \u{443}\u{431}\u{438}\u{432}\u{430}\u{435}\u{442} \u{441}\u{430}\u{43c}\u{43e} \u{43f}\u{43e} \u{441}\u{435}\u{431}\u{435} \u{438} \u{434}\u{43e}\u{431}\u{438}\u{432}\u{430}\u{442}\u{44c} \u{440}\u{443}\u{43a}\u{430}\u{43c}\u{438} \u{43d}\u{435} \u{43d}\u{443}\u{436}\u{43d}\u{43e}.",
	},
	solar = {
		"Uses Solar Bind at the very start of the combo, before the beam is released and before Dagon, so the target is locked down and cannot teleport away. It also cuts the magic resistance of the target, so the beam and Dagon hit noticeably harder.",
		"\u{5728}\u{8fde}\u{62db}\u{6700}\u{5f00}\u{59cb}\u{5c31}\u{4f7f}\u{7528}\u{592a}\u{9633}\u{675f}\u{7f1a}\u{ff0c}\u{5728}\u{5149}\u{675f}\u{91ca}\u{653e}\u{4e4b}\u{524d}\u{3001}\u{5728}\u{8fbe}\u{8d21}\u{4e4b}\u{524d}\u{ff0c}\u{8ba9}\u{76ee}\u{6807}\u{88ab}\u{9501}\u{4f4f}\u{65e0}\u{6cd5}\u{4f20}\u{9001}\u{9003}\u{8dd1}\u{3002}\u{5b83}\u{8fd8}\u{4f1a}\u{964d}\u{4f4e}\u{76ee}\u{6807}\u{7684}\u{9b54}\u{6cd5}\u{62b5}\u{6297}\u{ff0c}\u{4f7f}\u{5149}\u{675f}\u{548c}\u{8fbe}\u{8d21}\u{7684}\u{4f24}\u{5bb3}\u{660e}\u{663e}\u{66f4}\u{9ad8}\u{3002}",
		"\u{41a}\u{430}\u{441}\u{442}\u{443}\u{435}\u{442} Solar Bind \u{432} \u{441}\u{430}\u{43c}\u{43e}\u{43c} \u{43d}\u{430}\u{447}\u{430}\u{43b}\u{435} \u{43a}\u{43e}\u{43c}\u{431}\u{43e}, \u{434}\u{43e} \u{432}\u{44b}\u{441}\u{442}\u{440}\u{435}\u{43b}\u{430} \u{43b}\u{443}\u{447}\u{43e}\u{43c} \u{438} \u{434}\u{43e} Dagon, \u{447}\u{442}\u{43e}\u{431}\u{44b} \u{446}\u{435}\u{43b}\u{44c} \u{43d}\u{435} \u{443}\u{441}\u{43f}\u{435}\u{43b}\u{430} \u{443}\u{439}\u{442}\u{438} \u{442}\u{435}\u{43b}\u{435}\u{43f}\u{43e}\u{440}\u{442}\u{43e}\u{43c}. \u{41e}\u{43d} \u{435}\u{449}\u{451} \u{438} \u{440}\u{435}\u{436}\u{435}\u{442} \u{43c}\u{430}\u{433}\u{438}\u{447}\u{435}\u{441}\u{43a}\u{43e}\u{435} \u{441}\u{43e}\u{43f}\u{440}\u{43e}\u{442}\u{438}\u{432}\u{43b}\u{435}\u{43d}\u{438}\u{435} \u{446}\u{435}\u{43b}\u{438}, \u{43f}\u{43e}\u{44d}\u{442}\u{43e}\u{43c}\u{443} \u{43b}\u{443}\u{447} \u{438} Dagon \u{431}\u{44c}\u{44e}\u{442} \u{437}\u{430}\u{43c}\u{435}\u{442}\u{43d}\u{43e} \u{441}\u{438}\u{43b}\u{44c}\u{43d}\u{435}\u{435}.",
	},
	dagon = {
		"Uses Dagon of any level right after the beam is released, so the two damage instances land almost together.",
		"\u{5728}\u{5149}\u{675f}\u{91ca}\u{653e}\u{540e}\u{7acb}\u{5373}\u{4f7f}\u{7528}\u{4efb}\u{610f}\u{7b49}\u{7ea7}\u{7684}\u{8fbe}\u{8d21}\u{ff0c}\u{4f7f}\u{4e24}\u{6bb5}\u{4f24}\u{5bb3}\u{51e0}\u{4e4e}\u{540c}\u{65f6}\u{547d}\u{4e2d}\u{3002}",
		"\u{418}\u{441}\u{43f}\u{43e}\u{43b}\u{44c}\u{437}\u{443}\u{435}\u{442} Dagon \u{43b}\u{44e}\u{431}\u{43e}\u{433}\u{43e} \u{443}\u{440}\u{43e}\u{432}\u{43d}\u{44f} \u{441}\u{440}\u{430}\u{437}\u{443} \u{43f}\u{43e}\u{441}\u{43b}\u{435} \u{432}\u{44b}\u{441}\u{442}\u{440}\u{435}\u{43b}\u{430}, \u{447}\u{442}\u{43e}\u{431}\u{44b} \u{434}\u{432}\u{430} \u{443}\u{440}\u{43e}\u{43d}\u{430} \u{43f}\u{440}\u{438}\u{448}\u{43b}\u{438} \u{43f}\u{43e}\u{447}\u{442}\u{438} \u{43e}\u{434}\u{43d}\u{43e}\u{432}\u{440}\u{435}\u{43c}\u{435}\u{43d}\u{43d}\u{43e}.",
	},
	ethereal = {
		"Uses Ethereal Blade before the release. Its own damage is counted and the magic amplification on the target is included in the calculation.",
		"\u{5728}\u{91ca}\u{653e}\u{524d}\u{4f7f}\u{7528}\u{5e7d}\u{9b42}\u{6743}\u{6756}\u{3002}\u{5b83}\u{81ea}\u{8eab}\u{7684}\u{4f24}\u{5bb3}\u{4f1a}\u{88ab}\u{8ba1}\u{5165}\u{ff0c}\u{76ee}\u{6807}\u{53d7}\u{5230}\u{7684}\u{9b54}\u{6cd5}\u{4f24}\u{5bb3}\u{653e}\u{5927}\u{4e5f}\u{4f1a}\u{7eb3}\u{5165}\u{8ba1}\u{7b97}\u{3002}",
		"\u{418}\u{441}\u{43f}\u{43e}\u{43b}\u{44c}\u{437}\u{443}\u{435}\u{442} Ethereal Blade \u{43f}\u{435}\u{440}\u{435}\u{434} \u{432}\u{44b}\u{441}\u{442}\u{440}\u{435}\u{43b}\u{43e}\u{43c}. \u{415}\u{433}\u{43e} \u{441}\u{43e}\u{431}\u{441}\u{442}\u{432}\u{435}\u{43d}\u{43d}\u{44b}\u{439} \u{443}\u{440}\u{43e}\u{43d} \u{443}\u{447}\u{442}\u{451}\u{43d}, \u{430} \u{443}\u{441}\u{438}\u{43b}\u{435}\u{43d}\u{438}\u{435} \u{43c}\u{430}\u{433}\u{438}\u{447}\u{435}\u{441}\u{43a}\u{43e}\u{433}\u{43e} \u{443}\u{440}\u{43e}\u{43d}\u{430} \u{43f}\u{43e} \u{446}\u{435}\u{43b}\u{438} \u{432}\u{445}\u{43e}\u{434}\u{438}\u{442} \u{432} \u{440}\u{430}\u{441}\u{447}\u{451}\u{442}.",
	},
	veil = {
		"Uses Veil of Discord on the impact point before the release. The magic resistance debuff is included in the damage calculation.",
		"\u{5728}\u{91ca}\u{653e}\u{524d}\u{5c06}\u{7eb7}\u{4e89}\u{9762}\u{7eb1}\u{65bd}\u{653e}\u{5728}\u{547d}\u{4e2d}\u{70b9}\u{3002}\u{9b54}\u{6297}\u{964d}\u{4f4e}\u{7684}\u{6548}\u{679c}\u{4f1a}\u{8ba1}\u{5165}\u{4f24}\u{5bb3}\u{8ba1}\u{7b97}\u{3002}",
		"\u{418}\u{441}\u{43f}\u{43e}\u{43b}\u{44c}\u{437}\u{443}\u{435}\u{442} Veil of Discord \u{432} \u{442}\u{43e}\u{447}\u{43a}\u{443} \u{43f}\u{43e}\u{43f}\u{430}\u{434}\u{430}\u{43d}\u{438}\u{44f} \u{43f}\u{435}\u{440}\u{435}\u{434} \u{432}\u{44b}\u{441}\u{442}\u{440}\u{435}\u{43b}\u{43e}\u{43c}. \u{421}\u{43d}\u{438}\u{436}\u{435}\u{43d}\u{438}\u{435} \u{43c}\u{430}\u{433}\u{438}\u{447}\u{435}\u{441}\u{43a}\u{43e}\u{433}\u{43e} \u{441}\u{43e}\u{43f}\u{440}\u{43e}\u{442}\u{438}\u{432}\u{43b}\u{435}\u{43d}\u{438}\u{44f} \u{432}\u{445}\u{43e}\u{434}\u{438}\u{442} \u{432} \u{440}\u{430}\u{441}\u{447}\u{451}\u{442} \u{443}\u{440}\u{43e}\u{43d}\u{430}.",
	},
	vessel = {
		"Uses Spirit Vessel before the release. Besides its own damage it blocks the health regeneration of the target, and the script counts that too.",
		"\u{5728}\u{91ca}\u{653e}\u{524d}\u{4f7f}\u{7528}\u{7075}\u{9b42}\u{4e4b}\u{5323}\u{3002}\u{9664}\u{4e86}\u{81ea}\u{8eab}\u{4f24}\u{5bb3}\u{ff0c}\u{5b83}\u{8fd8}\u{4f1a}\u{963b}\u{6b62}\u{76ee}\u{6807}\u{7684}\u{751f}\u{547d}\u{56de}\u{590d}\u{ff0c}\u{811a}\u{672c}\u{4e5f}\u{4f1a}\u{628a}\u{8fd9}\u{4e00}\u{70b9}\u{8ba1}\u{5165}\u{3002}",
		"\u{418}\u{441}\u{43f}\u{43e}\u{43b}\u{44c}\u{437}\u{443}\u{435}\u{442} Spirit Vessel \u{43f}\u{435}\u{440}\u{435}\u{434} \u{432}\u{44b}\u{441}\u{442}\u{440}\u{435}\u{43b}\u{43e}\u{43c}. \u{41a}\u{440}\u{43e}\u{43c}\u{435} \u{441}\u{432}\u{43e}\u{435}\u{433}\u{43e} \u{443}\u{440}\u{43e}\u{43d}\u{430} \u{43e}\u{43d} \u{431}\u{43b}\u{43e}\u{43a}\u{438}\u{440}\u{443}\u{435}\u{442} \u{440}\u{435}\u{433}\u{435}\u{43d}\u{435}\u{440}\u{430}\u{446}\u{438}\u{44e} \u{446}\u{435}\u{43b}\u{438}, \u{438} \u{441}\u{43a}\u{440}\u{438}\u{43f}\u{442} \u{44d}\u{442}\u{43e} \u{442}\u{43e}\u{436}\u{435} \u{443}\u{447}\u{438}\u{442}\u{44b}\u{432}\u{430}\u{435}\u{442}.",
	},
	mana = {
		"Mana that the script never spends. Items and spells of the combo are skipped if casting them would drop your mana below this value.",
		"\u{811a}\u{672c}\u{6c38}\u{8fdc}\u{4e0d}\u{4f1a}\u{82b1}\u{6389}\u{7684}\u{9b54}\u{6cd5}\u{503c}\u{3002}\u{5982}\u{679c}\u{65bd}\u{653e}\u{4f1a}\u{4f7f}\u{9b54}\u{6cd5}\u{4f4e}\u{4e8e}\u{8be5}\u{6570}\u{503c}\u{ff0c}\u{5219}\u{8df3}\u{8fc7}\u{5bf9}\u{5e94}\u{7684}\u{9053}\u{5177}\u{548c}\u{6280}\u{80fd}\u{3002}",
		"\u{41c}\u{430}\u{43d}\u{430}, \u{43a}\u{43e}\u{442}\u{43e}\u{440}\u{443}\u{44e} \u{441}\u{43a}\u{440}\u{438}\u{43f}\u{442} \u{43d}\u{438}\u{43a}\u{43e}\u{433}\u{434}\u{430} \u{43d}\u{435} \u{442}\u{440}\u{430}\u{442}\u{438}\u{442}. \u{41f}\u{440}\u{435}\u{434}\u{43c}\u{435}\u{442}\u{44b} \u{438} \u{441}\u{43f}\u{43e}\u{441}\u{43e}\u{431}\u{43d}\u{43e}\u{441}\u{442}\u{438} \u{43a}\u{43e}\u{43c}\u{431}\u{43e} \u{43f}\u{440}\u{43e}\u{43f}\u{443}\u{441}\u{43a}\u{430}\u{44e}\u{442}\u{441}\u{44f}, \u{435}\u{441}\u{43b}\u{438} \u{43f}\u{43e}\u{441}\u{43b}\u{435} \u{43a}\u{430}\u{441}\u{442}\u{430} \u{43c}\u{430}\u{43d}\u{44b} \u{441}\u{442}\u{430}\u{43d}\u{435}\u{442} \u{43c}\u{435}\u{43d}\u{44c}\u{448}\u{435} \u{44d}\u{442}\u{43e}\u{433}\u{43e} \u{437}\u{43d}\u{430}\u{447}\u{435}\u{43d}\u{438}\u{44f}.",
	},
	finish = {
		"If the target somehow survives the beam, the script instantly finishes it with whatever is still ready, Dagon, Solar Bind, Ethereal Blade or Spirit Vessel.",
		"\u{5982}\u{679c}\u{76ee}\u{6807}\u{7adf}\u{7136}\u{5728}\u{5149}\u{675f}\u{4e0b}\u{5b58}\u{6d3b}\u{ff0c}\u{811a}\u{672c}\u{4f1a}\u{7acb}\u{5373}\u{7528}\u{4ecd}\u{7136}\u{53ef}\u{7528}\u{7684}\u{8fbe}\u{8d21}\u{3001}\u{592a}\u{9633}\u{675f}\u{7f1a}\u{3001}\u{5e7d}\u{9b42}\u{6743}\u{6756}\u{6216}\u{7075}\u{9b42}\u{4e4b}\u{5323}\u{8865}\u{5200}\u{3002}",
		"\u{415}\u{441}\u{43b}\u{438} \u{446}\u{435}\u{43b}\u{44c} \u{432}\u{441}\u{451} \u{436}\u{435} \u{432}\u{44b}\u{436}\u{438}\u{43b}\u{430} \u{43f}\u{43e}\u{441}\u{43b}\u{435} \u{43b}\u{443}\u{447}\u{430}, \u{441}\u{43a}\u{440}\u{438}\u{43f}\u{442} \u{43c}\u{433}\u{43d}\u{43e}\u{432}\u{435}\u{43d}\u{43d}\u{43e} \u{434}\u{43e}\u{431}\u{438}\u{432}\u{430}\u{435}\u{442} \u{435}\u{451} \u{432}\u{441}\u{435}\u{43c}, \u{447}\u{442}\u{43e} \u{433}\u{43e}\u{442}\u{43e}\u{432}\u{43e}, \u{44d}\u{442}\u{43e} Dagon, Solar Bind, Ethereal Blade \u{438}\u{43b}\u{438} Spirit Vessel.",
	},
	esp = {
		"Damage text over enemy heroes. The first line shows the damage of your current combo and the enemy health, the second line shows how many seconds of charge are still needed. Green means the kill is guaranteed, red means it is not.",
		"\u{654c}\u{65b9}\u{82f1}\u{96c4}\u{5934}\u{9876}\u{7684}\u{4f24}\u{5bb3}\u{6587}\u{5b57}\u{3002}\u{7b2c}\u{4e00}\u{884c}\u{663e}\u{793a}\u{5f53}\u{524d}\u{8fde}\u{62db}\u{7684}\u{4f24}\u{5bb3}\u{4e0e}\u{654c}\u{4eba}\u{8840}\u{91cf}\u{ff0c}\u{7b2c}\u{4e8c}\u{884c}\u{663e}\u{793a}\u{8fd8}\u{9700}\u{591a}\u{5c11}\u{79d2}\u{84c4}\u{529b}\u{3002}\u{7eff}\u{8272}\u{8868}\u{793a}\u{80fd}\u{7a33}\u{6740}\u{ff0c}\u{7ea2}\u{8272}\u{8868}\u{793a}\u{4e0d}\u{591f}\u{3002}",
		"\u{422}\u{435}\u{43a}\u{441}\u{442} \u{443}\u{440}\u{43e}\u{43d}\u{430} \u{43d}\u{430}\u{434} \u{432}\u{440}\u{430}\u{436}\u{435}\u{441}\u{43a}\u{438}\u{43c}\u{438} \u{433}\u{435}\u{440}\u{43e}\u{44f}\u{43c}\u{438}. \u{41f}\u{435}\u{440}\u{432}\u{430}\u{44f} \u{441}\u{442}\u{440}\u{43e}\u{43a}\u{430} \u{43f}\u{43e}\u{43a}\u{430}\u{437}\u{44b}\u{432}\u{430}\u{435}\u{442} \u{443}\u{440}\u{43e}\u{43d} \u{442}\u{435}\u{43a}\u{443}\u{449}\u{435}\u{433}\u{43e} \u{43a}\u{43e}\u{43c}\u{431}\u{43e} \u{438} \u{445}\u{43f} \u{432}\u{440}\u{430}\u{433}\u{430}, \u{432}\u{442}\u{43e}\u{440}\u{430}\u{44f} \u{441}\u{43a}\u{43e}\u{43b}\u{44c}\u{43a}\u{43e} \u{441}\u{435}\u{43a}\u{443}\u{43d}\u{434} \u{43d}\u{430}\u{43a}\u{43e}\u{43f}\u{43b}\u{435}\u{43d}\u{438}\u{44f} \u{435}\u{449}\u{451} \u{43d}\u{443}\u{436}\u{43d}\u{43e}. \u{417}\u{435}\u{43b}\u{451}\u{43d}\u{44b}\u{439} \u{437}\u{43d}\u{430}\u{447}\u{438}\u{442} \u{443}\u{431}\u{438}\u{439}\u{441}\u{442}\u{432}\u{43e} \u{433}\u{430}\u{440}\u{430}\u{43d}\u{442}\u{438}\u{440}\u{43e}\u{432}\u{430}\u{43d}\u{43e}, \u{43a}\u{440}\u{430}\u{441}\u{43d}\u{44b}\u{439} \u{447}\u{442}\u{43e} \u{43d}\u{435}\u{442}.",
	},
	esp_size = {
		"Font size of the damage text above enemies.",
		"\u{654c}\u{4eba}\u{4e0a}\u{65b9}\u{4f24}\u{5bb3}\u{6587}\u{5b57}\u{7684}\u{5b57}\u{53f7}\u{3002}",
		"\u{420}\u{430}\u{437}\u{43c}\u{435}\u{440} \u{448}\u{440}\u{438}\u{444}\u{442}\u{430} \u{442}\u{435}\u{43a}\u{441}\u{442}\u{430} \u{443}\u{440}\u{43e}\u{43d}\u{430} \u{43d}\u{430}\u{434} \u{432}\u{440}\u{430}\u{433}\u{430}\u{43c}\u{438}.",
	},
	lang = {
		"Interface language of this script. It changes the setting names and these explanations.",
		"\u{672c}\u{811a}\u{672c}\u{7684}\u{754c}\u{9762}\u{8bed}\u{8a00}\u{3002}\u{5b83}\u{4f1a}\u{6539}\u{53d8}\u{8bbe}\u{7f6e}\u{540d}\u{79f0}\u{548c}\u{8fd9}\u{4e9b}\u{8bf4}\u{660e}\u{3002}",
		"\u{42f}\u{437}\u{44b}\u{43a} \u{438}\u{43d}\u{442}\u{435}\u{440}\u{444}\u{435}\u{439}\u{441}\u{430} \u{44d}\u{442}\u{43e}\u{433}\u{43e} \u{441}\u{43a}\u{440}\u{438}\u{43f}\u{442}\u{430}. \u{41c}\u{435}\u{43d}\u{44f}\u{435}\u{442} \u{43d}\u{430}\u{437}\u{432}\u{430}\u{43d}\u{438}\u{44f} \u{43d}\u{430}\u{441}\u{442}\u{440}\u{43e}\u{435}\u{43a} \u{438} \u{44d}\u{442}\u{438} \u{43f}\u{43e}\u{44f}\u{441}\u{43d}\u{435}\u{43d}\u{438}\u{44f}.",
	},
}

local font = Render.LoadFont("Arial", 0, 700)

local HERO_TAB = { "Heroes", "Hero List", "Keeper Of The Light", "Individual settings" }
local BACKUP_TAB = { "General", "Utility", "KOTL Illuminate", "Main" }

local function make_group(name)
	local ok, created = pcall(Menu.Create, HERO_TAB[1], HERO_TAB[2], HERO_TAB[3], HERO_TAB[4], name)
	if ok and created then return created end
	return Menu.Create(BACKUP_TAB[1], BACKUP_TAB[2], BACKUP_TAB[3], BACKUP_TAB[4], name)
end

local group = make_group("Illuminate")
local items = make_group("Combo items")
local visuals = make_group("Visuals")
local lang_group = make_group("Language")

local labels = {}
local function tag(widget, key, tip)
	labels[#labels + 1] = { widget, key, tip }
	return widget
end

local ui = {}
tag(group:Label("WARNING", "\u{f071}"), "warn_top")
tag(group:Label("Script is not safe, use at your own risk"), "warn_body")
tag(group:Label("WARNING", "\u{f071}"), "warn_bottom")
ui.enable = tag(group:Switch("Enable auto Illuminate", true, "\u{f0eb}"), "enable", "enable")
ui.key = tag(group:Bind("Illuminate key", Enum.ButtonCode.KEY_Q), "key", "key")
tag(group:Label("Lethal damage is calculated automatically", "\u{f0d0}"), "auto_lethal", "auto_lethal")
ui.min_channel = tag(group:Slider("Min channel", 0, 2000, 200, "%d ms"), "min_channel", "min_channel")
ui.latency = tag(group:Slider("Travel safety", 0, 500, 120, "%d ms"), "latency", "latency")
ui.max_range = tag(group:Slider("Max beam distance", 400, 1550, 1550, "%d"), "max_range", "max_range")
ui.predict = tag(group:Switch("Predict target movement", true), "predict", "predict")
ui.blinding = tag(group:Switch("Smart Blinding Light", true), "blinding", "blinding")
ui.blind_after = tag(group:Switch("Blinding Light after release", true), "blind_after", "blind_after")
ui.blind_finish = tag(group:Switch("Blinding Light as finisher", true), "blind_finish", "blind_finish")
ui.solar = tag(group:Switch("Combo Solar Bind", true), "solar", "solar")
ui.dagon = tag(items:Switch("Combo Dagon", true), "dagon", "dagon")
ui.ethereal = tag(items:Switch("Combo Ethereal Blade", true), "ethereal", "ethereal")
ui.veil = tag(items:Switch("Combo Veil of Discord", true), "veil", "veil")
ui.vessel = tag(items:Switch("Combo Spirit Vessel", true), "vessel", "vessel")
ui.mana_reserve = tag(items:Slider("Mana reserve", 0, 400, 0, "%d"), "mana", "mana")
ui.finish = tag(items:Switch("Auto finish after shot", true), "finish", "finish")
ui.esp = tag(visuals:Switch("Damage ESP", true, "\u{f06e}"), "esp", "esp")
ui.esp_size = tag(visuals:Slider("Text size", 10, 26, 16, "%d"), "esp_size", "esp_size")
ui.lang = tag(lang_group:Combo("Language", { "English", "\u{4e2d}\u{6587}", "\u{420}\u{443}\u{441}\u{441}\u{43a}\u{438}\u{439}" }, 0), "lang", "lang")

tag(group, "grp_main")
tag(items, "grp_items")
tag(visuals, "grp_visuals")
tag(lang_group, "grp_lang")

local state = {
	channeling = false,
	channel_start = nil,
	last_release = -10.0,
	last_blind = -10.0,
	last_solar = -10.0,
	solar_pending = nil,
	solar_break = 0,
	solar_early_off = false,
	last_finish = -10.0,
	finish_damage = 0.0,
	language = 0,
	finish_target = nil,
	finish_expire = 0.0,
	beam = nil,
	channel_origin = nil,
	channel_dir = nil,
	channel_seen = -10.0,
	channel_real = false,
	queue = {},
	queue_head = 1,
	queue_at = 0.0,
	locks = {},
	axis_origin = nil,
	axis_dir = nil,
}

local function call(fn, ...)
	if type(fn) == "function" then return fn(...) end
	return nil
end

local function clamp(value, low, high)
	if value < low then return low end
	if value > high then return high end
	return value
end

local function switch_on(widget)
	if not widget then return true end
	local ok, value = pcall(function() return widget:Get() end)
	if not ok then return true end
	if value == nil then return true end
	if value == 0 then return false end
	return value ~= false
end

local function slider_value(widget, fallback)
	if not widget then return fallback end
	local ok, value = pcall(function() return widget:Get() end)
	if not ok or type(value) ~= "number" then return fallback end
	return value
end

local function locked(item, now)
	if not item then return false end
	local at = state.locks[item]
	if at and now - at < ORDER_LOCK then return true end
	return false
end

local function language_index()
	local index = 1
	local value = ui.lang:Get()
	if type(value) == "number" then index = value + 1 end
	if index < 1 or index > 3 then index = 1 end
	return index
end

local function tr(key)
	local row = TEXT[key]
	if not row then return key end
	return row[language_index()] or row[1]
end

local function tip_text(key)
	if not key then return nil end
	local row = TIP[key]
	if not row then return nil end
	return row[language_index()] or row[1]
end

local function localize(widget, text)
	if not widget then return end
	pcall(function()
		widget:ForceLocalization(text)
	end)
end

local function set_tooltip(widget, text)
	if not widget or not text then return end
	if pcall(function() widget:ToolTip(text) end) then return end
	if pcall(function() widget:Tooltip(text) end) then return end
	pcall(function() widget:SetToolTip(text) end)
end

local function apply_language(force)
	local index = language_index()
	if not force and index == state.language then return end
	state.language = index
	for i = 1, #labels do
		localize(labels[i][1], tr(labels[i][2]))
		set_tooltip(labels[i][1], tip_text(labels[i][3]))
	end
end

local function special_value(ability, names)
	if not ability then return nil end
	for i = 1, #names do
		local value = Ability.GetLevelSpecialValueFor(ability, names[i])
		if value and value ~= 0 then return value end
	end
	return nil
end

local function special(ability, names, fallback, level)
	local value = special_value(ability, names)
	if value and value > 0 then return value end
	if fallback then
		return fallback[math.floor(clamp(level or 1, 1, #fallback))]
	end
	return 0.0
end

local function percent(value)
	if not value then return nil end
	if value < 0.0 then value = -value end
	if value > 1.0 then value = value / 100.0 end
	return value
end

local function talent_value(hero, names, low, high, fallback)
	for i = 1, #names do
		local talent = NPC.GetAbility(hero, names[i])
		if talent and Ability.GetLevel(talent) > 0 then
			local value = special_value(talent, { "value", "bonus" })
			if value then
				if value < 0.0 then value = -value end
				if value >= low and value <= high then return value end
			end
			return fallback
		end
	end
	return 0.0
end

local function find_ability(hero, names)
	for i = 1, #names do
		local ability = NPC.GetAbility(hero, names[i])
		if ability and Ability.GetLevel(ability) > 0 and not Ability.IsHidden(ability) then return ability end
	end
	for i = 1, #names do
		local ability = NPC.GetAbility(hero, names[i])
		if ability and Ability.GetLevel(ability) > 0 then return ability end
	end
	return nil
end

local function cast_range(hero, ability, fallback)
	local range = Ability.GetCastRange(ability)
	if not range or range <= 0 then range = fallback end
	local bonus = call(NPC.GetCastRangeBonus, hero) or 0.0
	return range + bonus
end

local function distance(a, b)
	return (a - b):Length2D()
end

local function latency()
	return RELEASE_LATENCY + slider_value(ui.latency, 120.0) / 1000.0
end

local function predicted_pos(target, time)
	local pos = Entity.GetAbsOrigin(target)
	if not pos then return nil end
	if not switch_on(ui.predict) or time <= 0.0 then return pos end
	if not call(NPC.IsRunning, target) then return pos end
	local speed = call(NPC.GetMoveSpeed, target) or 0.0
	if speed <= 0.0 then return pos end
	local forward = call(Entity.GetForwardPosition, target, speed * time)
	if not forward then return pos end
	return forward
end

local function get_illuminate(hero)
	local sf = NPC.GetAbility(hero, SF_ILLUMINATE)
	if sf and not Ability.IsHidden(sf) and NPC.HasModifier(hero, SPIRIT_FORM_MOD) then
		return sf, NPC.GetAbility(hero, SF_ILLUMINATE_END)
	end
	local base = NPC.GetAbility(hero, ILLUMINATE)
	if base and Ability.IsHidden(base) and sf then
		return sf, NPC.GetAbility(hero, SF_ILLUMINATE_END)
	end
	return base, NPC.GetAbility(hero, ILLUMINATE_END)
end

local function illuminate_level(hero)
	local best = 0
	local base = NPC.GetAbility(hero, ILLUMINATE)
	if base then
		local level = Ability.GetLevel(base) or 0
		if level > best then best = level end
	end
	local sf = NPC.GetAbility(hero, SF_ILLUMINATE)
	if sf then
		local level = Ability.GetLevel(sf) or 0
		if level > best then best = level end
	end
	return best
end

local function kaya_amp(hero)
	local best = 0.0
	for i = 1, #KAYA_ITEMS do
		if NPC.GetItem(hero, KAYA_ITEMS[i][1], true) and KAYA_ITEMS[i][2] > best then
			best = KAYA_ITEMS[i][2]
		end
	end
	return best
end

local function spell_amp(hero)
	local base = percent(call(NPC.GetBaseSpellAmp, hero)) or 0.0
	local kaya = kaya_amp(hero)
	if base >= kaya then return 1.0 + base end
	return 1.0 + kaya
end

local function primary_attribute(hero)
	local strength = call(Hero.GetStrengthTotal, hero) or 0.0
	local agility = call(Hero.GetAgilityTotal, hero) or 0.0
	local intellect = call(Hero.GetIntellectTotal, hero) or 0.0
	local attribute = call(Hero.GetPrimaryAttribute, hero)
	local list = Enum.Attributes or {}
	if attribute ~= nil then
		if attribute == list.DOTA_ATTRIBUTE_STRENGTH then return strength end
		if attribute == list.DOTA_ATTRIBUTE_AGILITY then return agility end
		if attribute == list.DOTA_ATTRIBUTE_INTELLECT then return intellect end
		if attribute == list.DOTA_ATTRIBUTE_ALL then return math.min(strength, agility, intellect) end
	end
	return intellect
end

local function magic_take(target)
	local multiplier = call(NPC.GetMagicalArmorDamageMultiplier, target)
	if multiplier and multiplier > 0.0 and multiplier <= 2.0 then return multiplier end
	local resist = percent(call(NPC.GetMagicalArmorValue, target))
	if not resist then resist = 0.25 end
	return clamp(1.0 - resist, 0.0, 2.0)
end

local function veil_shred(hero)
	local item = NPC.GetItem(hero, VEIL_ITEM, true)
	local value = percent(special_value(item, { "debuff_magic_resistance", "magic_resistance", "bonus_spell_resist", "spell_amp" }))
	if value and value > 0.0 and value < 0.6 then return value end
	return VEIL_SHRED
end

local function ethereal_amp(hero)
	local item = NPC.GetItem(hero, ETHEREAL_ITEM, true)
	local value = percent(special_value(item, { "blast_spell_amp", "ethereal_damage_bonus", "bonus_spell_damage", "damage_amp" }))
	if value and value > 0.0 and value < 1.0 then return value end
	return ETHEREAL_AMP
end

local function solar_shred(hero, ability)
	if not ability then return 0.0 end
	local level = Ability.GetLevel(ability)
	local value = percent(special(ability, { "magic_resistance_reduction", "bonus_magic_resistance", "magic_resistance" }, SOLAR_SHRED, level))
	if not value or value <= 0.0 or value >= 0.9 then value = SOLAR_SHRED[math.floor(clamp(level, 1, #SOLAR_SHRED))] end
	local bonus = percent(talent_value(hero, SOLAR_TALENTS, 5.0, 20.0, 10.0)) or 0.0
	return value + bonus
end

local function magic_multiplier(hero, target, extra_shred, ethereal)
	local multiplier = magic_take(target)
	multiplier = multiplier + (extra_shred or 0.0)
	if multiplier < 0.0 then multiplier = 0.0 end
	if ethereal then multiplier = multiplier * (1.0 + ethereal_amp(hero)) end
	return multiplier
end

local function effective_hp(target, window, vessel)
	local hp = Entity.GetHealth(target)
	local regen = call(NPC.GetHealthRegen, target) or 0.0
	if regen < 0.0 then regen = 0.0 end
	local result = hp + regen * window
	if vessel or NPC.HasModifier(target, VESSEL_MOD) then
		result = result - hp * VESSEL_DRAIN * window
	end
	local barriers = call(NPC.GetBarriers, target)
	if barriers and barriers.magic and barriers.magic.current then
		result = result + barriers.magic.current
	end
	if result < 1.0 then result = 1.0 end
	return result
end

local function illuminate_damage(hero, ability)
	local level = illuminate_level(hero)
	if level < 1 then return 0.0 end
	local total = ILL_DAMAGE[math.floor(clamp(level, 1, #ILL_DAMAGE))]
	local sources = {}
	if ability then sources[#sources + 1] = ability end
	local base = NPC.GetAbility(hero, ILLUMINATE)
	if base then sources[#sources + 1] = base end
	local sf = NPC.GetAbility(hero, SF_ILLUMINATE)
	if sf then sources[#sources + 1] = sf end
	for i = 1, #sources do
		local value = special_value(sources[i], { "total_damage", "damage" })
		if value and value > total then total = value end
	end
	local bonus = talent_value(hero, ILL_TALENTS, 50.0, 400.0, TALENT_BONUS)
	return total + bonus
end

local function ready_item(hero, name, mana_left)
	local item = NPC.GetItem(hero, name, true)
	if not item then return nil, mana_left end
	if Ability.IsHidden(item) then return nil, mana_left end
	if not Ability.IsCastable(item, mana_left) then return nil, mana_left end
	if locked(item, GameRules.GetGameTime()) then return nil, mana_left end
	local cost = Ability.GetManaCost(item) or 0.0
	return item, mana_left - cost
end

local function beam_direction(hero)
	local pos = Entity.GetAbsOrigin(hero)
	local forward = call(Entity.GetForwardPosition, hero, 100.0)
	if pos and forward then
		local dir = forward - pos
		if dir:Length2D() > 0.01 then return dir:Normalized() end
	end
	local rotation = call(Entity.GetRotation, hero)
	local yaw = 0.0
	if rotation then yaw = rotation.y or 0.0 end
	local rad = yaw * math.pi / 180.0
	return Vector(math.cos(rad), math.sin(rad), 0.0)
end

local function beam_source(hero)
	local origin = state.channel_origin
	local dir = state.channel_dir
	if not state.channeling or not origin or not dir then
		origin = Entity.GetAbsOrigin(hero)
		dir = beam_direction(hero)
	end
	state.axis_origin = origin
	state.axis_dir = dir
	return origin, dir
end

local function project(origin, dir, pos)
	local delta = pos - origin
	local forward = delta.x * dir.x + delta.y * dir.y
	local side = delta.x * dir.y - delta.y * dir.x
	if side < 0.0 then side = -side end
	return forward, side
end

local function hull(target)
	return call(NPC.GetHullRadius, target) or 24.0
end

local function beam_limit()
	return math.min(BEAM_RANGE, slider_value(ui.max_range, 1550.0))
end

local function beam_hit(origin, dir, target, pos)
	if not pos then return false, 0.0 end
	local forward, side = project(origin, dir, pos)
	if forward < 0.0 or forward > beam_limit() then return false, forward end
	return side <= BEAM_RADIUS - hull(target) * 0.5, forward
end

local function impact_info(origin, dir, target)
	local pos = Entity.GetAbsOrigin(target)
	if not pos then return false, 0.0, nil, latency() end
	local forward = project(origin, dir, pos)
	local travel = clamp(forward, 0.0, BEAM_RANGE) / BEAM_SPEED + latency()
	local future = predicted_pos(target, travel)
	local hit_now, forward_now = beam_hit(origin, dir, target, pos)
	local hit_future, forward_future = beam_hit(origin, dir, target, future)
	local impact_forward = math.max(forward_now, forward_future)
	local window = clamp(impact_forward, 0.0, BEAM_RANGE) / BEAM_SPEED + latency()
	return hit_now and hit_future, impact_forward, future or pos, window
end

local function build_plan(hero, target, impact_pos, beam_window, skip_blind)
	local plan = {
		pre = {},
		post = {},
		core = 0.0,
		flat = 0.0,
		burst = 0.0,
		window = 0.0,
		shred = 0.0,
		ethereal = false,
		vessel = false,
		blind = false,
	}

	local hero_pos = Entity.GetAbsOrigin(hero)
	local now_pos = Entity.GetAbsOrigin(target)
	if not hero_pos or not now_pos then return plan end
	if not impact_pos then impact_pos = now_pos end

	local dist = distance(now_pos, hero_pos)
	local point_dist = distance(impact_pos, hero_pos)
	local mana = NPC.GetMana(hero) - slider_value(ui.mana_reserve, 0.0)
	local function bump(value)
		if value > plan.window then plan.window = value end
	end

	if switch_on(ui.solar) and not NPC.HasModifier(target, SOLAR_MOD) then
		local bind = find_ability(hero, SOLAR_NAMES)
		local pending = state.solar_pending
		local clock = GameRules.GetGameTime()
		if bind and pending and pending.target == target and clock < pending.expire then
			plan.shred = plan.shred + solar_shred(hero, bind)
			local wait = pending.land - clock
			if wait > 0.0 then bump(wait) end
		elseif bind and not Ability.IsHidden(bind) and Ability.IsCastable(bind, mana) then
			if dist <= cast_range(hero, bind, SOLAR_RANGE) - 50.0 and SOLAR_LATENCY <= beam_window then
				mana = mana - (Ability.GetManaCost(bind) or 0.0)
				plan.shred = plan.shred + solar_shred(hero, bind)
				bump(SOLAR_LATENCY)
				plan.pre[#plan.pre + 1] = { item = bind, target = true }
			end
		end
	end

	if switch_on(ui.veil) and not NPC.HasModifier(target, VEIL_MOD) then
		local item, left = ready_item(hero, VEIL_ITEM, mana)
		if item then
			local range = cast_range(hero, item, VEIL_RANGE)
			local radius = special(item, { "radius" }, { VEIL_RADIUS }, 1)
			local spot = impact_pos
			if point_dist > range - 50.0 or distance(now_pos, impact_pos) > radius - hull(target) then spot = now_pos end
			if distance(spot, hero_pos) <= range - 50.0 and distance(now_pos, spot) <= radius - hull(target) and VEIL_LATENCY <= beam_window then
				mana = left
				plan.shred = plan.shred + veil_shred(hero)
				bump(VEIL_LATENCY)
				plan.pre[#plan.pre + 1] = { item = item, position = spot }
			end
		end
	end

	if switch_on(ui.ethereal) and not NPC.HasModifier(target, ETHEREAL_MOD) then
		local item, left = ready_item(hero, ETHEREAL_ITEM, mana)
		if item then
			local range = cast_range(hero, item, ETHEREAL_RANGE)
			local speed = special(item, { "projectile_speed", "blast_speed" }, { ETHEREAL_SPEED }, 1)
			local flight = dist / speed + ETHEREAL_LATENCY
			if dist <= range - 50.0 and flight <= beam_window - 0.05 then
				local base = special_value(item, { "blast_damage_base", "base_damage", "blast_damage", "damage" })
				local multiplier = special_value(item, { "blast_primary_attribute_multiplier", "blast_agility_multiplier", "damage_multiplier" })
				mana = left
				plan.ethereal = true
				if base and base > 0.0 then
					local bonus = 0.0
					if multiplier and multiplier > 0.0 then bonus = multiplier * primary_attribute(hero) end
					plan.flat = plan.flat + base + bonus
				end
				bump(flight)
				plan.pre[#plan.pre + 1] = { item = item, target = true }
			end
		end
	end

	if switch_on(ui.vessel) and not NPC.HasModifier(target, VESSEL_MOD) then
		local item, left = ready_item(hero, VESSEL_ITEM, mana)
		if item then
			local range = cast_range(hero, item, VESSEL_RANGE)
			local speed = special(item, { "projectile_speed" }, { VESSEL_SPEED }, 1)
			local flight = dist / speed + VESSEL_LATENCY
			if dist <= range - 50.0 and flight <= beam_window then
				mana = left
				plan.vessel = true
				bump(flight)
				plan.pre[#plan.pre + 1] = { item = item, target = true }
			end
		end
	end

	if switch_on(ui.dagon) then
		for level = #DAGON_NAMES, 1, -1 do
			local item, left = ready_item(hero, DAGON_NAMES[level], mana)
			if item then
				if dist <= cast_range(hero, item, DAGON_RANGE[level]) - 50.0 then
					mana = left
					local burst = DAGON_DAMAGE[math.floor(clamp(level, 1, #DAGON_DAMAGE))]
					local value = special_value(item, { "damage" })
					if value and value > burst then burst = value end
					plan.core = plan.core + burst
					plan.burst = plan.burst + burst
					bump(DAGON_LATENCY)
					plan.post[#plan.post + 1] = { item = item, target = true, burst = true }
				end
				break
			end
		end
	end

	if switch_on(ui.blind_finish) and not skip_blind then
		local bl = find_ability(hero, BLINDING_NAMES)
		if bl and not Ability.IsHidden(bl) and Ability.IsCastable(bl, mana) then
			local level = Ability.GetLevel(bl)
			if level > 0 then
				local radius = special(bl, { "radius" }, BL_RADIUS, level)
				local range = cast_range(hero, bl, BL_CAST_RANGE[math.floor(clamp(level, 1, #BL_CAST_RANGE))])
				local aim = predicted_pos(target, BL_LATENCY) or now_pos
				local spot = aim
				local axis = state.axis_dir
				if axis then spot = aim - axis * (radius * 0.55) end
				local away = distance(spot, hero_pos)
				if away > range - 20.0 and away > 1.0 then
					local step = spot - hero_pos
					if step:Length2D() > 1.0 then spot = hero_pos + step:Normalized() * (range - 20.0) end
				end
				local reach = distance(spot, hero_pos) <= range - 20.0
				local covered = distance(spot, aim) <= radius - hull(target) * 0.5 - 30.0
				if reach and covered then
					mana = mana - (Ability.GetManaCost(bl) or 0.0)
					plan.core = plan.core + special(bl, { "damage" }, BL_DAMAGE, level) + talent_value(hero, BL_TALENTS, 40.0, 250.0, 90.0)
					bump(BL_LATENCY)
					plan.blind = true
					plan.post[#plan.post + 1] = { item = bl, position = spot }
				end
			end
		end
	end

	return plan
end

local function scales(hero, target, plan, use_ethereal)
	local amp = spell_amp(hero)
	local ethereal = plan.ethereal
	if use_ethereal == false then ethereal = false end
	local amplified = magic_multiplier(hero, target, plan.shred, ethereal)
	local plain = magic_multiplier(hero, target, plan.shred, false)
	return amp * amplified, amp * plain
end

local function total_damage(hero, ability, target, channel_time, plan)
	local amplified, plain = scales(hero, target, plan, true)
	local beam = illuminate_damage(hero, ability) * clamp(channel_time, 0.0, MAX_CHANNEL) / MAX_CHANNEL
	return (beam + plan.core) * amplified + plan.flat * plain
end

local function needed_channel(hero, ability, target, required, plan)
	local total = illuminate_damage(hero, ability)
	if total <= 0.0 then return nil end
	local amplified, plain = scales(hero, target, plan, true)
	if amplified <= 0.0 then return nil end
	local rest = required - plan.flat * plain
	local raw = rest / amplified - plan.core
	if raw <= 0.0 then return 0.0 end
	local time = raw / total * MAX_CHANNEL
	if time > MAX_CHANNEL then return nil end
	return time
end

local function bare_plan(plan)
	local core = plan.core - (plan.burst or 0.0)
	if core < 0.0 then core = 0.0 end
	return {
		pre = {},
		post = {},
		core = core,
		flat = 0.0,
		burst = 0.0,
		window = plan.window,
		shred = plan.shred,
		ethereal = plan.ethereal,
		vessel = plan.vessel,
		blind = false,
	}
end

local function drop_burst(plan)
	if (plan.burst or 0.0) <= 0.0 then return end
	plan.core = plan.core - plan.burst
	if plan.core < 0.0 then plan.core = 0.0 end
	plan.burst = 0.0
	local keep = {}
	for i = 1, #plan.post do
		if not plan.post[i].burst then keep[#keep + 1] = plan.post[i] end
	end
	plan.post = keep
end

local function auto_margin(target, plan, window)
	local hp = Entity.GetHealth(target) or 0.0
	local margin = 70.0 + math.min(hp * 0.07, 200.0)
	local regen = call(NPC.GetHealthRegen, target) or 0.0
	if regen > 0.0 then
		local time = (window or 0.0) + (plan and plan.window or 0.0) + 0.7
		if plan and plan.vessel then time = time * 0.5 end
		margin = margin + regen * time
	end
	margin = margin + latency() * 200.0
	if call(NPC.IsRunning, target) then margin = margin + 30.0 end
	return margin
end

local function required_hp(target, plan, window)
	return effective_hp(target, window + plan.window, plan.vessel) + auto_margin(target, plan, window)
end

local function execute_casts(list, target)
	for i = 1, #list do
		local entry = list[i]
		if entry.position then
			Ability.CastPosition(entry.item, entry.position, false, false, true)
		else
			Ability.CastTarget(entry.item, target, false, false, true)
		end
	end
end

local function release(ability, ability_end)
	if ability_end and not Ability.IsHidden(ability_end) then
		Ability.CastNoTarget(ability_end, false, false, true)
	else
		Ability.CastNoTarget(ability, false, false, true)
	end
end

local function push_cast(item, target, position, label)
	if not item then return end
	state.queue[#state.queue + 1] = { kind = "cast", item = item, target = target, position = position, label = label }
end

local function queue_plan(plan, target, ability, ability_end)
	for i = 1, #plan.pre do
		local entry = plan.pre[i]
		push_cast(entry.item, target, entry.position, "pre")
	end
	if ability then
		state.queue[#state.queue + 1] = { kind = "release", item = ability, extra = ability_end, label = "release" }
	end
	for i = 1, #plan.post do
		local entry = plan.post[i]
		push_cast(entry.item, target, entry.position, "post")
	end
end

local function pump_queue(now)
	local queue = state.queue
	local head = state.queue_head or 1
	if head > #queue then
		if #queue > 0 then
			state.queue = {}
			state.queue_head = 1
		end
		return false
	end
	if now < state.queue_at then return true end
	local entry = queue[head]
	state.queue_head = head + 1
	state.queue_at = now + ORDER_GAP
	if entry.kind == "release" then
		if entry.extra and not Ability.IsHidden(entry.extra) then
			Ability.CastNoTarget(entry.extra, false, false, true)
		else
			Ability.CastNoTarget(entry.item, false, false, true)
		end
	elseif entry.item then
		if entry.position then
			Ability.CastPosition(entry.item, entry.position, false, false, true)
		elseif entry.target then
			Ability.CastTarget(entry.item, entry.target, false, false, true)
		else
			Ability.CastNoTarget(entry.item, false, false, true)
		end
		state.locks[entry.item] = now
	end
	if state.queue_head > #queue then
		state.queue = {}
		state.queue_head = 1
	end
	return true
end

local function targetable(unit)
	if not unit then return false end
	if not Entity.IsAlive(unit) then return false end
	if Entity.IsDormant(unit) then return false end
	if NPC.IsIllusion(unit) then return false end
	if NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE) then return false end
	if NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE) then return false end
	return true
end

local function enemy_list(hero, extra)
	local pos = Entity.GetAbsOrigin(hero)
	if not pos then return {} end
	local team = Entity.GetTeamNum(hero)
	local list = Heroes.InRadius(pos, BEAM_RANGE + 700.0, team, Enum.TeamType.TEAM_ENEMY, true, true) or {}
	if extra and distance(extra, pos) > 200.0 then
		local more = Heroes.InRadius(extra, BEAM_RANGE + 700.0, team, Enum.TeamType.TEAM_ENEMY, true, true) or {}
		local seen = {}
		for i = 1, #list do seen[list[i]] = true end
		for i = 1, #more do
			if not seen[more[i]] then
				seen[more[i]] = true
				list[#list + 1] = more[i]
			end
		end
	end
	return list
end

local function incoming_beam(target, pos, now)
	local beam = state.beam
	if not beam or not pos then return 0.0 end
	if now > beam.expire then return 0.0 end
	local forward, side = project(beam.origin, beam.dir, pos)
	if forward < 0.0 or forward > beam_limit() then return 0.0 end
	if side > BEAM_RADIUS - hull(target) * 0.5 then return 0.0 end
	if now >= beam.time + forward / BEAM_SPEED then return 0.0 end
	return beam.damage or 0.0
end

local function try_finish(hero, now)
	if not switch_on(ui.finish) then return false end
	if state.channeling then return false end
	local target = state.finish_target
	if not target then return false end
	if now > state.finish_expire then
		state.finish_target = nil
		return false
	end
	if now - state.last_finish < 0.7 then return false end
	if state.queue_head <= #state.queue then return false end
	if not targetable(target) or not NPC.IsVisible(target) then return false end
	local pos = Entity.GetAbsOrigin(target)
	if not pos then return false end
	local plan = build_plan(hero, target, pos, MAX_CHANNEL)
	if #plan.pre == 0 and #plan.post == 0 then return false end
	local amplified, plain = scales(hero, target, plan, true)
	local damage = (plan.core + incoming_beam(target, pos, now)) * amplified + plan.flat * plain
	local hp = effective_hp(target, plan.window + latency(), plan.vessel)
	if now - state.last_finish < 2.0 and (state.finish_damage or 0.0) >= hp then return false end
	if damage < hp then return false end
	queue_plan(plan, target, nil, nil)
	pump_queue(now)
	state.last_finish = now
	state.finish_damage = damage
	return true
end

local function try_solar_channel(hero, target, now)
	if not switch_on(ui.solar) then return false end
	if state.solar_early_off then return false end
	if NPC.HasModifier(target, SOLAR_MOD) then return false end
	if now - state.last_solar < 0.5 then return false end
	local pending = state.solar_pending
	if pending and pending.target == target and now < pending.expire then return false end
	local bind = find_ability(hero, SOLAR_NAMES)
	if not bind or Ability.IsHidden(bind) then return false end
	if not Ability.IsCastable(bind, NPC.GetMana(hero) - slider_value(ui.mana_reserve, 0.0)) then return false end
	local hero_pos = Entity.GetAbsOrigin(hero)
	local pos = Entity.GetAbsOrigin(target)
	if not hero_pos or not pos then return false end
	if distance(pos, hero_pos) > cast_range(hero, bind, SOLAR_RANGE) - 50.0 then return false end
	Ability.CastTarget(bind, target, false, false, true)
	state.locks[bind] = now
	state.last_solar = now
	state.solar_pending = { target = target, land = now + SOLAR_LATENCY, expire = now + 0.7 }
	return true
end

local function blinding_solution(hero, bl, target, origin, dir, time_available)
	local level = Ability.GetLevel(bl)
	if level < 1 then return nil end
	local radius = special(bl, { "radius" }, BL_RADIUS, level)
	local min_push = special(bl, { "min_knockback_distance", "knockback_distance_min", "min_knockback" }, { BL_MIN_PUSH }, 1)
	local push_time = special(bl, { "knockback_duration", "duration_knockback" }, { BL_PUSH_TIME }, 1)
	if radius <= 0.0 then return nil end
	if time_available < push_time + latency() then return nil end
	local hero_pos = Entity.GetAbsOrigin(hero)
	local target_pos = Entity.GetAbsOrigin(target)
	if not hero_pos or not target_pos then return nil end
	local forward, side = project(origin, dir, target_pos)
	local limit = beam_limit()
	if forward <= 100.0 or forward > limit then return nil end
	local safe_side = BEAM_RADIUS - hull(target) * 0.5 - 40.0
	if safe_side <= 0.0 then return nil end
	local axis_point = origin + dir * forward
	local push_dir = axis_point - target_pos
	if push_dir:Length2D() < 1.0 then return nil end
	push_dir = push_dir:Normalized()
	local push = side
	if push < min_push then push = min_push end
	if push > radius - hull(target) * 0.5 then return nil end
	local landing = target_pos + push_dir * push
	local land_forward, land_side = project(origin, dir, landing)
	if land_forward <= 0.0 or land_forward > limit then return nil end
	if land_side > safe_side then return nil end
	local center = landing - push_dir * radius
	if distance(center, target_pos) > radius - hull(target) * 0.5 then return nil end
	if distance(center, hero_pos) > cast_range(hero, bl, BL_CAST_RANGE[math.floor(clamp(level, 1, #BL_CAST_RANGE))]) - 20.0 then return nil end
	local damage = special(bl, { "damage" }, BL_DAMAGE, level) + talent_value(hero, BL_TALENTS, 40.0, 250.0, 90.0)
	return center, landing, damage, push_time, land_forward
end

local function try_blinding_channel(hero, ability, target, channel_time, now)
	if not switch_on(ui.blinding) then return false end
	local bl = find_ability(hero, BLINDING_NAMES)
	if not bl then return false end
	if Ability.GetLevel(bl) < 1 then return false end
	if not Ability.IsCastable(bl, NPC.GetMana(hero) - slider_value(ui.mana_reserve, 0.0)) then return false end
	local origin, dir = beam_source(hero)
	if not origin or not dir then return false end
	local center, landing, bl_damage, push_time, land_forward = blinding_solution(hero, bl, target, origin, dir, MAX_CHANNEL)
	if not center then return false end
	local window = land_forward / BEAM_SPEED + latency() + push_time
	local plan = build_plan(hero, target, landing, window, true)
	plan.core = plan.core + bl_damage
	local required = required_hp(target, plan, window)
	if total_damage(hero, ability, target, MAX_CHANNEL, plan) < required then return false end
	local need = needed_channel(hero, ability, target, required, plan)
	if not need or need > MAX_CHANNEL - 0.1 then return false end
	local lead = push_time + latency() - land_forward / BEAM_SPEED
	if lead < BL_LEAD then lead = BL_LEAD end
	local fire_at = need - lead
	local limit = MAX_CHANNEL - lead
	if fire_at > limit then fire_at = limit end
	if fire_at < 0.0 then fire_at = 0.0 end
	if channel_time < fire_at then return false end
	if try_solar_channel(hero, target, now) then return true end
	Ability.CastPosition(bl, center, false, false, true)
	state.last_blind = now
	return true
end

local function try_blinding_after(hero, now)
	if not switch_on(ui.blinding) or not switch_on(ui.blind_after) then return false end
	local beam = state.beam
	if not beam then return false end
	if now > beam.expire then
		state.beam = nil
		return false
	end
	if now - state.last_blind < 1.0 then return false end
	local bl = find_ability(hero, BLINDING_NAMES)
	if not bl then return false end
	if not Ability.IsCastable(bl, NPC.GetMana(hero) - slider_value(ui.mana_reserve, 0.0)) then return false end
	local front = (now - beam.time) * BEAM_SPEED
	local list = enemy_list(hero, beam.origin)
	for i = 1, #list do
		local target = list[i]
		if targetable(target) and NPC.IsVisible(target) then
			local pos = Entity.GetAbsOrigin(target)
			if pos then
				local forward, side = project(beam.origin, beam.dir, pos)
				if side > BEAM_RADIUS - hull(target) * 0.5 and forward > front then
					local available = (forward - front) / BEAM_SPEED
					local center, landing, bl_damage, push_time, land_forward = blinding_solution(hero, bl, target, beam.origin, beam.dir, available)
					if center then
						local window = math.max((land_forward - front) / BEAM_SPEED, 0.0) + push_time
						local plan = build_plan(hero, target, landing, window, true)
						plan.core = plan.core + bl_damage + beam.damage
						local amplified, plain = scales(hero, target, plan, true)
						local damage = plan.core * amplified + plan.flat * plain
						if damage >= required_hp(target, plan, window) then
							state.last_blind = now
							push_cast(bl, nil, center, "blind")
							queue_plan(plan, target, nil, nil)
							pump_queue(now)
							state.finish_target = target
							state.finish_expire = now + FINISH_WINDOW
							return true
						end
					end
				end
			end
		end
	end
	return false
end

local function update_tick()
	apply_language(false)
	if not switch_on(ui.enable) then
		return
	end
	if not Engine.IsInGame() then return end

	local hero = Heroes.GetLocal()
	if not hero or not Entity.IsAlive(hero) then return end
	if NPC.GetUnitName(hero) ~= HERO_NAME then return end

	local ability, ability_end = get_illuminate(hero)
	if not ability or illuminate_level(hero) < 1 then return end

	local now = GameRules.GetGameTime()
	if pump_queue(now) then return end
	if try_blinding_after(hero, now) then return end
	if try_finish(hero, now) then return end

	local channeling = Ability.IsChannelling(ability) or NPC.IsChannellingAbility(hero)
	if not channeling and ability_end then channeling = Ability.IsChannelling(ability_end) end
	local has_end = ability_end and not Ability.IsHidden(ability_end)
	local key_down = ui.key:IsDown()
	local real = channeling or has_end
	if real or key_down then state.channel_seen = now end
	local fresh = now - (state.channel_seen or -10.0) <= CHANNEL_GRACE
	local held = state.channeling and fresh and now - (state.channel_start or now) <= CHANNEL_HOLD
	local active = held or ((real or key_down) and now - state.last_release > 0.35)

	if not active then
		state.channeling = false
		state.channel_start = nil
		state.channel_real = false
		state.channel_origin = nil
		state.channel_dir = nil
		return
	end

	if real then state.channel_real = true end

	if not state.channeling then
		state.channeling = true
		state.channel_real = real
		state.channel_origin = nil
		state.channel_dir = nil
		if NPC.HasModifier(hero, SPIRIT_FORM_MOD) then
			state.channel_origin = Entity.GetAbsOrigin(hero)
			state.channel_dir = beam_direction(hero)
		end
		local start = call(Ability.GetChannelStartTime, ability)
		if start and start > 0.0 and now - start >= 0.0 and now - start <= MAX_CHANNEL then
			state.channel_start = start
		else
			state.channel_start = now
		end
	end

	local channel_time = clamp(now - (state.channel_start or now), 0.0, MAX_CHANNEL)
	if state.channel_origin and channel_time < 0.6 then
		local here = Entity.GetAbsOrigin(hero)
		if here and distance(here, state.channel_origin) < 60.0 then
			state.channel_origin = here
			state.channel_dir = beam_direction(hero)
		end
	end
	if channel_time < slider_value(ui.min_channel, 200.0) / 1000.0 then return end
	if now - state.last_release < 0.5 then return end

	local origin, dir = beam_source(hero)
	if not origin or not dir then return end
	local list = enemy_list(hero, origin)

	local best = nil
	local best_hp = 0.0
	local best_pos = nil
	local best_window = 0.0
	for i = 1, #list do
		local target = list[i]
		if targetable(target) then
			local hit, forward, impact_pos, window = impact_info(origin, dir, target)
			if hit then
				local hp = effective_hp(target, 0.0, false)
				if not best or hp < best_hp then
					best = target
					best_hp = hp
					best_pos = impact_pos
					best_window = window
				end
			end
		end
	end

	if best then
		local plan = build_plan(hero, best, best_pos, best_window)
		local required = required_hp(best, plan, best_window)
		if needed_channel(hero, ability, best, required, bare_plan(plan)) then drop_burst(plan) end
		local damage = total_damage(hero, ability, best, channel_time, plan)
		local lethal = damage >= required
		local forced = channel_time >= MAX_CHANNEL - 0.05
		state.finish_target = best
		state.finish_expire = now + FINISH_WINDOW
		if lethal or forced then
			if not lethal then
				local max_hp = 0.0
				if Entity.GetMaxHealth then max_hp = call(Entity.GetMaxHealth, best) or 0.0 end
				if max_hp <= 0.0 then max_hp = Entity.GetHealth(best) or 0.0 end
				local slack = 200.0
				if max_hp * 0.15 > slack then slack = max_hp * 0.15 end
				local dump = damage >= required - slack
				if not dump then
					plan.pre = {}
					plan.post = {}
				end
			end
			local delay = ORDER_GAP * #plan.pre
			state.last_release = now
			state.channeling = false
			state.channel_start = nil
			state.channel_real = false
			state.channel_seen = -10.0
			state.channel_origin = nil
			state.channel_dir = nil
			state.finish_target = best
			state.finish_expire = now + FINISH_WINDOW + delay
			state.beam = {
				time = now + delay + latency(),
				origin = origin,
				dir = dir,
				damage = illuminate_damage(hero, ability) * clamp(channel_time, 0.0, MAX_CHANNEL) / MAX_CHANNEL,
				expire = now + delay + latency() + beam_limit() / BEAM_SPEED,
			}
			queue_plan(plan, best, ability, ability_end)
			pump_queue(now)
			return
		end
		local hold = needed_channel(hero, ability, best, required, plan)
		if hold and channel_time >= hold - 0.4 then
			try_solar_channel(hero, best, now)
		end
		if now - state.last_blind > 1.5 then
			if try_blinding_channel(hero, ability, best, channel_time, now) then return end
		end
		return
	end

	for i = 1, #list do
		local target = list[i]
		if targetable(target) and now - state.last_blind > 1.5 then
			if try_blinding_channel(hero, ability, target, channel_time, now) then return end
		end
	end
end

function script.OnUpdate()
	pcall(update_tick)
end

local function draw_tick()
	apply_language(false)
	if not switch_on(ui.esp) then return end
	if not Engine.IsInGame() then return end

	local hero = Heroes.GetLocal()
	if not hero or not Entity.IsAlive(hero) then return end
	if NPC.GetUnitName(hero) ~= HERO_NAME then return end

	local ability = get_illuminate(hero)
	if not ability or illuminate_level(hero) < 1 then return end

	local origin, dir = beam_source(hero)
	if not origin or not dir then return end

	local now = GameRules.GetGameTime()
	local channel_time = 0.0
	if state.channeling and state.channel_start then
		channel_time = clamp(now - state.channel_start, 0.0, MAX_CHANNEL)
	end

	local size = slider_value(ui.esp_size, 16.0)
	local list = enemy_list(hero, origin)
	local need_text = tr("esp_need")
	local nokill_text = tr("esp_nokill")

	for i = 1, #list do
		local target = list[i]
		if target and Entity.IsAlive(target) and not Entity.IsDormant(target) and not NPC.IsIllusion(target) and NPC.IsVisible(target) then
			local pos = Entity.GetAbsOrigin(target)
			if pos then
				local _, forward, impact_pos, window = impact_info(origin, dir, target)
				local plan = build_plan(hero, target, impact_pos, window)
				local required = required_hp(target, plan, window)
				if needed_channel(hero, ability, target, required, bare_plan(plan)) then drop_burst(plan) end
				local damage = total_damage(hero, ability, target, channel_time, plan)
				local enough = damage >= required
				local need = needed_channel(hero, ability, target, required, plan)
				local offset = call(NPC.GetHealthBarOffset, target) or 200
				local screen, visible = Render.WorldToScreen(Vector(pos.x, pos.y, pos.z + offset + 40))
				if visible then
					local color = enough and COLOR_KILL or COLOR_LOW
					local line1 = string.format("DMG: %d / HP: %d", math.floor(damage + 0.5), math.floor(Entity.GetHealth(target)))
					local line2
					if enough then
						line2 = need_text .. ": 0.00s"
					elseif need then
						line2 = string.format("%s: %.2fs", need_text, math.max(need - channel_time, 0.0))
					else
						line2 = need_text .. ": " .. nokill_text
					end
					local size1 = Render.TextSize(font, size, line1)
					local size2 = Render.TextSize(font, size - 1, line2)
					local x1 = screen.x - size1.x * 0.5
					local x2 = screen.x - size2.x * 0.5
					local y2 = screen.y + size1.y + 2
					Render.Text(font, size, line1, Vec2(x1 + 1, screen.y + 1), COLOR_SHADOW)
					Render.Text(font, size, line1, Vec2(x1, screen.y), color)
					Render.Text(font, size - 1, line2, Vec2(x2 + 1, y2 + 1), COLOR_SHADOW)
					Render.Text(font, size - 1, line2, Vec2(x2, y2), color)
				end
			end
		end
	end
end

function script.OnDraw()
	pcall(draw_tick)
end

function script.OnGameEnd()
	state.channeling = false
	state.channel_start = nil
	state.last_release = -10.0
	state.last_blind = -10.0
	state.last_solar = -10.0
	state.solar_pending = nil
	state.solar_break = 0
	state.solar_early_off = false
	state.last_finish = -10.0
	state.finish_damage = 0.0
	state.finish_target = nil
	state.finish_expire = 0.0
	state.beam = nil
	state.queue = {}
	state.queue_head = 1
	state.queue_at = 0.0
	state.locks = {}
	state.channel_seen = -10.0
	state.channel_real = false
	state.channel_origin = nil
	state.channel_dir = nil
	state.axis_origin = nil
	state.axis_dir = nil
end

apply_language(true)

return script
