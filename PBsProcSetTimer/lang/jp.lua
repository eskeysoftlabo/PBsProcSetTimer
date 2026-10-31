-- 日本語。lang/strings.lua のあとに読み込まれ、同じIDを上書きします。
local strings = {
	SI_PBSPST_ACTIVE = "発動中 %.1f",
	SI_PBSPST_COOLDOWN = "CD %.1f",
	SI_PBSPST_READY = "発動可能",
	SI_PBSPST_IDLE = "-",
	SI_PBSPST_AGO = "%.1f秒前",
	SI_PBSPST_PREVIEW_ROW = "発動中 3.2  CD 4.8",
	SI_PBSPST_SAMPLE_SET = "セット名 %d",

	SI_PBSPST_EXPLANATION = "装備しているセットのうち、ボーナス説明文に時間が書かれているものすべてについて、効果が発動した瞬間、効果が続いている時間、クールダウンの残りを表示します。どのセットの情報もアドオンの中には持たず、装備しているセットとその説明文をゲームから読み取ります。",
	SI_PBSPST_SETS_HINT = "表示から外したいセットがあるときは、/procset sets で装備中のセットを確認し、/procset hide <ID またはセット名の一部> で行を消します。/procset show で戻します。",

	SI_PBSPST_SECTION_DISPLAY = "表示",
	SI_PBSPST_ENABLED = "タイマーを表示",
	SI_PBSPST_ENABLED_TOOLTIP = "装備しているセットのうち、ボーナス説明文に時間があるものについて、そのボーナスが有効になる数の装備を着けている間だけ、1行ずつ表示します。",
	SI_PBSPST_COMBAT_ONLY = "戦闘中のみ",
	SI_PBSPST_COMBAT_ONLY_TOOLTIP = "戦闘外では表示を隠します。",
	SI_PBSPST_ONLY_DETECTED = "発動を検出したセットだけ表示",
	SI_PBSPST_ONLY_DETECTED_TOOLTIP = "セットの効果が今回の起動中に一度でも検出されるまで、その行を隠します。多くのセットを装備しているときに表示を短く保てますが、効果を認識できないセットは表示されません。",
	SI_PBSPST_SOUND_READY = "クールダウン明けに音を鳴らす",
	SI_PBSPST_SOUND_READY_TOOLTIP = "セットのクールダウンが終わった瞬間に、短い音を鳴らします。",
	SI_PBSPST_PREVIEW = "表示のプレビュー",
	SI_PBSPST_PREVIEW_TOOLTIP = "サンプルの3行を表示します。各要素の位置と大きさを決めるときに使ってください。保存されません。",

	SI_PBSPST_SECTION_BLOCK = "表示全体",
	SI_PBSPST_POS_X = "横位置",
	SI_PBSPST_POS_X_TOOLTIP = "表示全体の左上の角の位置です。画面の中央からの距離で指定します。",
	SI_PBSPST_POS_Y = "縦位置",
	SI_PBSPST_POS_Y_TOOLTIP = "表示全体の左上の角の位置です。画面の中央からの距離で指定します。大きいほど下に動きます。",
	SI_PBSPST_SCALE = "大きさ (%)",
	SI_PBSPST_SCALE_TOOLTIP = "左上の角を基準に、すべてをまとめて拡大・縮小します。",
	SI_PBSPST_ROW_HEIGHT = "行の高さ",
	SI_PBSPST_ROW_HEIGHT_TOOLTIP = "セットの行から次の行までの間隔です。",

	SI_PBSPST_SECTION_NAME = "セット名",
	SI_PBSPST_SECTION_BAR = "バー",
	SI_PBSPST_SECTION_TEXT = "状態テキスト",
	SI_PBSPST_ELEM_SHOW = "表示する",
	SI_PBSPST_ELEM_X = "横位置",
	SI_PBSPST_ELEM_X_TOOLTIP = "行の左端からの距離です。",
	SI_PBSPST_ELEM_Y = "縦位置",
	SI_PBSPST_ELEM_Y_TOOLTIP = "行の縦方向の中央からの距離です。大きいほど下に動きます。",
	SI_PBSPST_ELEM_WIDTH = "幅",
	SI_PBSPST_ELEM_HEIGHT = "高さ",
	SI_PBSPST_ELEM_FONT = "文字の大きさ",

	SI_PBSPST_RESET = "設定をすべて初期値に戻す",
	SI_PBSPST_RESET_BUTTON = "リセット",

	SI_PBSPST_LOADED = "PB's Proc Set Timer %s を読み込みました。/procset でコマンド一覧を表示します。",
	SI_PBSPST_HELP = "/procset on | off -- 表示のオン・オフ\n/procset sets -- 装備中のセットと、それぞれに行があるか\n/procset hide | show <セットIDまたはセット名の一部> -- セットの行を消す・戻す\n/procset status -- 各行について、説明文から読み取った時間と、対応づけたアビリティ\n/procset log -- 装備セットの最近の変化(バー切り替え、装備数、ボーナスの有効・無効)\n/procset text [セットID] -- 装備中のセット(またはIDで指定した1つ)のボーナス説明文の原文と、読み取った内容\n/procset probe -- セット装備中に出たアビリティを一覧表示(対応づけに失敗した効果を探すため)\n/procset bind <アビリティID> <セットIDまたは名前> -- アビリティを手動でセットに結びつける。bind clear で解除\n/procset ignore <アビリティID> -- このアビリティを照合の対象から外す。ignore clear で解除\n/procset preview -- 位置決め用のサンプル表示",
	SI_PBSPST_ON = "Proc Set Timer をオンにしました。",
	SI_PBSPST_OFF = "Proc Set Timer をオフにしました。",
	SI_PBSPST_PROBE_ON = "プローブをオンにしました。どのセットにも対応しない自分のアビリティを、1つにつき1回だけ表示します。",
	SI_PBSPST_PROBE_OFF = "プローブをオフにしました。",
	SI_PBSPST_PREVIEW_ON = "プレビューをオンにしました。",
	SI_PBSPST_PREVIEW_OFF = "プレビューをオフにしました。",
	SI_PBSPST_SET_NOT_FOUND = "'%s' に合うセットがありません。/procset sets で装備中のセットを確認できます。",
	SI_PBSPST_HIDE_DONE = "非表示にしました: %s (ID %d)。/procset show %d で戻せます。",
	SI_PBSPST_SHOW_DONE = "再び表示します: %s (ID %d)。",
	SI_PBSPST_BIND_DONE = "アビリティ %d を %s に結びつけました。",
	SI_PBSPST_BIND_CLEARED = "結びつけをすべて解除しました。",
	SI_PBSPST_BIND_USAGE = "使い方: /procset bind <アビリティID> <セットIDまたは名前の一部>   または   /procset bind clear",
	SI_PBSPST_IGNORE_DONE = "アビリティ %d は、今後どのセットにも対応づけません。",
	SI_PBSPST_IGNORE_CLEARED = "照合から外したアビリティをすべて元に戻しました。",
	SI_PBSPST_IGNORE_USAGE = "使い方: /procset ignore <アビリティID>   または   /procset ignore clear",
}

for stringId, stringValue in pairs(strings) do
	ZO_CreateStringId(stringId, stringValue)
	SafeAddVersion(stringId, 1)
end
