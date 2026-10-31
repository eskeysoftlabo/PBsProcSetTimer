-- Bonus descriptions the tests feed to the parser.
--
-- "en" is the wording on the UESP wiki (2026-10-31). The other languages are NOT the game's text
-- (it could not be read from here): they are plausible renderings, written with the cue words a
-- translator would be likely to use, to show the parser does not hang on one phrasing. Each
-- entry: { required, text }.

local T = {}

local function stats(a)
	return {
		{ 2, "Adds 25-1096 Maximum Magicka" },
		{ 3, "Adds 3-129 Weapon and Spell Damage" },
		{ 4, "Adds 3-129 Weapon and Spell Damage" },
		a,
	}
end

T.en = {
	martial = stats({
		5,
		"While your Stamina is below 50%, your Light Attacks cause the enemy to take 8% additional damage for 5 seconds. This effect can occur once every 8 seconds.",
	}),
	zen = stats({
		5,
		"Your Light Attacks apply the Touch of Z'en on enemies for 20 seconds. Enemies with the Touch of Z'en take an additional 1% more damage for each damage over time effect you've placed on them, up to 5%. Enemies can only be affected by one Touch of Z'en at a time.",
	}),
	nightmare = {
		{ 2, "Adds 15-657 Critical Chance" },
		{ 3, "Adds 15-657 Critical Chance" },
		{ 4, "Adds 15-657 Critical Chance" },
		{
			5,
			"When you deal Critical Damage to an enemy, glass shards burst 8 meters around them after 1.3 seconds, dealing 1129 Physical Damage to enemies in the burst and applying the Sundered status effect. This effect can occur once every 8 seconds and the damage scales off the higher of your Weapon and Spell Damage.",
		},
	},
}

-- expected reading of the 5-piece bonus: { cooldown, duration, delay }
T.expected = {
	martial = { 8, 5, nil },
	zen = { nil, 20, nil },
	nightmare = { 8, nil, 1.3 },
}

-- Other languages / wordings of the three 5-piece lines.
T.variants = {
	{
		label = "jp (に1回)",
		martial = "スタミナが50%未満の間、軽攻撃で敵が5秒間、追加で8%多くのダメージを受ける。この効果は8秒に1回発生する。",
		zen = "軽攻撃で敵にズェンの接触を20秒間付与する。ズェンの接触を受けた敵は、あなたが与えた継続ダメージ効果1つにつき追加で1%多くのダメージを受ける(最大5%)。",
		nightmare = "敵にクリティカルダメージを与えると、1.3秒後にその周囲8メートルでガラスの破片が破裂し、1129の物理ダメージを与える。この効果は8秒に1回発生する。",
	},
	{
		label = "jp (ごとに)",
		martial = "スタミナが50%未満の間、軽攻撃で敵が5秒間、8%多くのダメージを受ける。この効果は8秒ごとに1回のみ発生する。",
		zen = "軽攻撃で敵にズェンの接触を20秒間付与する。",
		nightmare = "クリティカルダメージを与えると、1.3秒後に破片が破裂する。この効果は8秒ごとに発生する。",
	},
	{
		label = "jp (の間隔)",
		martial = "軽攻撃で敵が5秒間、8%多くのダメージを受ける。この効果は8秒の間隔で発生する。",
		zen = "軽攻撃で敵にズェンの接触を20秒間付与する。",
		nightmare = "クリティカルダメージを与えると、1.3秒後に破片が破裂する。この効果は8秒の間隔で発生する。",
	},
	{
		label = "jp (full-width digits)",
		martial = "軽攻撃で敵が５秒間、８％多くのダメージを受ける。この効果は８秒に１回発生する。",
		zen = "軽攻撃で敵にズェンの接触を２０秒間付与する。",
		nightmare = "クリティカルダメージを与えると、１．３秒後に破片が破裂する。この効果は８秒に１回発生する。",
	},
	{
		label = "jp (cooldown wording not recognised: position decides)",
		martial = "軽攻撃で敵が5秒間、8%多くのダメージを受ける。この効果の再発動には8秒必要。",
		zen = "軽攻撃で敵にズェンの接触を20秒間付与する。",
		-- the delay is worded "after" (後) so it is still told apart; only the cooldown is positional
		nightmare = "クリティカルダメージを与えると、1.3秒後に破片が破裂する。再発動には8秒必要。",
	},
	{
		label = "de",
		martial = "Solange deine Ausdauer unter 50 % liegt, erhalten Gegner durch deine leichten Angriffe für 5 Sekunden 8 % mehr Schaden. Dieser Effekt kann alle 8 Sekunden auftreten.",
		zen = "Deine leichten Angriffe versehen Gegner für 20 Sekunden mit der Berührung von Z'en.",
		nightmare = "Wenn du kritischen Schaden verursachst, bersten nach 1,3 Sekunden Glassplitter. Dieser Effekt kann alle 8 Sekunden auftreten.",
	},
	{
		label = "fr",
		martial = "Tant que votre Endurance est inférieure à 50 %, vos attaques légères infligent 8 % de dégâts supplémentaires pendant 5 secondes. Cet effet peut se produire toutes les 8 secondes.",
		zen = "Vos attaques légères appliquent le Toucher de Z'en pendant 20 secondes.",
		nightmare = "Quand vous infligez des dégâts critiques, des éclats de verre explosent après 1,3 secondes. Cet effet peut se produire toutes les 8 secondes.",
	},
	{
		label = "es",
		martial = "Mientras tu aguante esté por debajo del 50 %, tus ataques ligeros hacen que el enemigo reciba un 8 % más de daño durante 5 segundos. Este efecto puede ocurrir una vez cada 8 segundos.",
		zen = "Tus ataques ligeros aplican el Toque de Z'en a los enemigos durante 20 segundos.",
		nightmare = "Cuando infliges daño crítico, fragmentos de cristal estallan después de 1,3 segundos. Este efecto puede ocurrir una vez cada 8 segundos.",
	},
	{
		label = "ru",
		martial = "Пока ваша выносливость ниже 50%, ваши легкие атаки заставляют врага получать на 8% больше урона в течение 5 секунд. Этот эффект может срабатывать раз в 8 секунд.",
		zen = "Ваши легкие атаки накладывают на врагов Касание З'ена на 20 секунд.",
		nightmare = "Когда вы наносите критический урон, через 1.3 секунды взрываются осколки стекла. Этот эффект может срабатывать раз в 8 секунд.",
	},
	{
		label = "zh",
		martial = "当你的耐力低于50%时,你的轻击使敌人在5秒内受到额外8%伤害。该效果每8秒最多发生一次。",
		zen = "你的轻击使敌人在20秒内受到祖恩的触碰。",
		nightmare = "当你造成暴击时,1.3秒后玻璃碎片爆裂。该效果每8秒最多发生一次。",
	},
}

-- One bonus line holding two effects, each closing with its own cooldown sentence.
T.twin = {
	en = "When you cast a spell, gain Major Courage for 6 seconds. This effect can occur once every 12 seconds. When you block, restore Stamina and gain Minor Heroism for 3 seconds. This effect can occur once every 20 seconds.",
	jp = "魔法を使うと6秒間、勇気を得る。この効果は12秒に1回発生する。ブロックすると3秒間、英雄を得る。この効果は20秒に1回発生する。",
	de = "Wenn du einen Zauber wirkst, erhältst du für 6 Sekunden Mut. Dieser Effekt kann alle 12 Sekunden auftreten. Wenn du blockst, erhältst du für 3 Sekunden Heldentum. Dieser Effekt kann alle 20 Sekunden auftreten.",
}

-- Wretched Vitality: one bonus line, two effects, no cooldown sentence at all (UESP wording).
T.wretched = {
	en = "While in combat, applying a Major Buff or Debuff with a duration to a target grants you 260 Magicka and Stamina Recovery for 15 seconds. While in combat, applying a Minor Buff or Debuff with a duration to a target grants you 130 Magicka and Stamina Recovery for 15 seconds.",
	jp = "戦闘中、対象に持続時間のあるメジャーバフまたはデバフを付与すると、15秒間、マジカとスタミナ回復が260増加する。戦闘中、対象に持続時間のあるマイナーバフまたはデバフを付与すると、15秒間、マジカとスタミナ回復が130増加する。",
	jp2 = "戦闘中、メジャーバフを付与すると、15秒の間、回復が260増加する。戦闘中、マイナーバフを付与すると、15秒の間、回復が130増加する。",
	de = "Im Kampf erhältst du, wenn du ein Major-Buff oder -Debuff auf ein Ziel wirkst, für 15 Sekunden 260 Magicka- und Ausdauererholung. Im Kampf erhältst du, wenn du ein Minor-Buff oder -Debuff auf ein Ziel wirkst, für 15 Sekunden 130 Magicka- und Ausdauererholung.",
}

-- Sets made up for the tests of "any set". { name, max pieces, bonuses }; a bonus is
-- { pieces needed, text, perfected? }.
T.extra = {
	[9001] = {
		name = "Test Haste Set",
		bonuses = {
			{ 2, "Adds 1000 Health" },
			{ 3, "When you cast a spell, gain Major Courage for 6 seconds. This effect can occur once every 12 seconds." },
			{ 5, "When you restore a resource, this effect restores Stamina. This effect can occur once every 20 seconds." },
		},
	},
	[9002] = {
		name = "Plain Stats Set",
		bonuses = { { 2, "Adds 1000 Health" }, { 3, "Adds 100 Weapon Damage" }, { 5, "Adds 8% Critical Damage" } },
	},
	[9003] = {
		name = "Test Monster Set",
		max = 2,
		bonuses = {
			{ 1, "Adds 100 Health" },
			{ 2, "When you deal damage, gain Minor Heroism for 4 seconds. This effect can occur once every 10 seconds." },
		},
	},
	[9004] = {
		name = "Perfected Test Set",
		bonuses = {
			{ 2, "Adds 1000 Health" },
			{ 5, "Your attacks grant Empower for 7 seconds. This effect can occur once every 15 seconds.", true },
		},
	},
}
T.extra[9202] = {
	name = "Wretched Test Set",
	bonuses = { { 2, "Adds 1000 Health" }, { 5, T.wretched.en } },
}
T.extra[9201] = {
	name = "Twin Effect Set",
	bonuses = { { 2, "Adds 1000 Health" }, { 5, T.twin.en } },
}
for index = 1, 10 do
	T.extra[9100 + index] = {
		name = "Cap Set " .. index,
		max = 1,
		bonuses = { { 1, "Gain Major Sorcery for 5 seconds. This effect can occur once every 9 seconds." } },
	}
end

return T
