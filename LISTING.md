# Store listing copy

Text for the Bethesda.net / ZOS Console AddOn Uploader entry. Plain text, no markdown --
paste as-is. The **name** field is what the in-game add-on browser shows, so it must read
`PB's Proc Set Timer` there; `## Title` in the manifest does not reach that screen.

"It never presses anything" is near the top of both Descriptions on purpose: players read an
add-on that touches combat with that question in mind.

What has not been measured on a console is listed under "Known limitations", with the command
that settles each: how the game names the abilities of a proc (the add-on matches them to a set
by name), and how far the game reports debuffs on enemies other than the one you target.

---

## Name

PB's Proc Set Timer

## Overview (JP)

装備しているセットの効果が、いつ発動し、いつまで続き、次はいつ使えるのかを、バーと数字で
リアルタイムに表示するアドオンです。セットや効果の数値はアドオンの中に持たず、ゲームが表示する
ボーナスの説明文から読み取るので、パッチや新セットのあとも更新は要りません。1つのセットに
効果が複数あれば、効果ごとに別々のタイマーで管理します。追跡するセット、位置、大きさ、色は
設定画面で選べます。入力は代行せず、ゲームの出来事を読んで表示するだけです。

## Overview (EN)

See when a set's effect fires, how long it stays active and when it can fire again, as a bar
and numbers in real time. Nothing about any set is stored in the add-on: it reads the bonus
text the game shows, so a patch or a new set needs no update. A set with several effects gets
a separate timer for each. Which sets to follow, and the position, size and colors, are set in
the settings panel. It only reads game events; it never presses anything for you.

---

## Description (JP)

装備しているセットのボーナスには、「5秒間」「8秒に1回」のように、発動して、続いて、しばらく使えなく
なる効果がたくさんあります。いつ発動したのか、まだ続いているのか、次はいつ使えるのかを、バーと
数字で見られるようにするためのアドオンです。

■ このアドオンがしないこと

　ボタン入力は一切行いません。ゲームが知らせる戦闘の出来事と、装備品のセットの説明文を読んで、
　バーと文字を表示するだけです。行のあるセットを装備している間だけ、戦闘の出来事を読みます。

■ 表示されるもの

　ボーナスの説明文に「N秒間」「N秒に1回」のような時間が書かれている効果ごとに、1行が出ます。
　時間のない能力値だけのセットには出ません。1行は、セット名、バー、状態の文字でできています。

　　発動中 3.2　　　（緑）　　　効果が続いている残り秒数。クールダウンも数えているときは
　　　　　　　　　　　　　　　　「発動中 3.2  CD 4.8」と並びます
　　CD 4.8　　　　　（オレンジ）クールダウンの残り秒数
　　発動可能　　　　（水色）　　また発動できる状態
　　-　　　　　　　　（灰）　　　まだ何も起きていない行、またはクールダウンのない効果

　発動した瞬間は、バーが一瞬白く光ります。クールダウン明けに小さな音を鳴らすこともできます。
　行は最大8つです。

■ セットも効果も、アドオンの中に持たない

　セットの一覧も、効果の数値も、アビリティIDも持っていません。装備しているセットとその説明文を
　ゲームから読み取ります。パッチで数値が変わっても、新しいセットが追加されても、説明文に時間が
　書かれていれば、アドオンの更新なしで追従します。説明文の秒数の言い回しは、日本語、英語、
　ドイツ語、フランス語、スペイン語、ロシア語、中国語に対応しています。

■ 効果が複数あるセット

　効果ごとに、行とタイマー（発動中、クールダウン、結びつけたアビリティ）を別々に持ちます。

　・ボーナスが複数あり、どれにも時間があるセットは、有効になっているものすべてが別々の行に
　　なります（たとえば3個効果と5個効果）。
　・1つのボーナスの中に効果が複数書かれているときは、クールダウンの文や、続けて並ぶ持続時間の
　　ある文を目印に区切って、別々の行にします。
　・効果が複数あるセットでは、行の名前に必要な装備数が付きます。「セット名 (5)」、1つの
　　ボーナスの中に複数あれば「セット名 (5-2)」のようになります。

■ バーを切り替えたとき

　バーを切り替えて、セットのボーナスが切れても、すでに敵に付いている効果や、残りのクールダウンは
　続きます。その分は最後まで表示し、終わったときにボーナスが切れたままなら行を消します。
　切り替えの瞬間に装備数が一瞬だけ変わって見えても、2秒以内に戻れば行は消えません。切り替えて
　戻したときは、タイマーを続きから数えます。

■ 追跡するセットを選ぶ

　設定画面の「追跡するセット」に、時間のある効果を持つセットが一覧で並びます。いま装備している
　セットが先頭で、これまでに装備したセットが続きます。チェックを入れたセットだけ、行が出ます。

　「新しく装備したセットも追跡する」をオフにすると、チェックを入れたセットだけが追跡され、
　初めて装備したセットは、チェックを入れるまで追跡されません。「このセットだけ追う」には
　この方法を使います。チェックを外すと、タイマーが動いている最中でも、そのセットの行はすぐ
　消えます。

■ 設定

　設定パネルには LibHarvensAddonSettings が必要です。

　　追跡するセット　　新しく装備したセットも追跡する　初期値：オン
　　　　　　　　　　　すべて入れる／すべて外す、セットごとのチェック
　　タイマーを表示　　　　　　　　　　　初期値：オン
　　戦闘中のみ　　　　　　　　　　　　　初期値：オフ
　　発動を検出したセットだけ表示　　　　初期値：オフ
　　クールダウン明けに音を鳴らす　　　　初期値：オフ
　　表示のプレビュー　　　　　　　　　　5行のサンプルを出します。保存されません
　　表示全体　　　　　　　横位置・縦位置・大きさ（%）・行の高さ
　　セット名・バー・状態テキスト
　　　　　　　　　　　　　それぞれ、表示する・横位置・縦位置・幅
　　　　　　　　　　　　　（バーは高さ、文字は文字の大きさも）
　　色　　　　　　　　　　発動中・クールダウン・発動可能・効果なし・発動の瞬間の5つを、
　　　　　　　　　　　　　赤・緑・青それぞれ0〜255で指定します。バーと、その横の文字が
　　　　　　　　　　　　　同じ色になります
　　設定をすべて初期値に戻す

■ コマンド

　　/procset on | off　　　　　　　　表示のオン・オフ
　　/procset sets　　　　　　　　　　装備中のセットと、それぞれに行があるか（ないなら理由）
　　/procset hide | show <ID または名前の一部>　セットの追跡をやめる・再開する
　　/procset status　　　　　　　　　各行の装備数、読み取った時間、結びつけたアビリティ
　　/procset text [セットID]　　　　　ボーナス説明文の原文と、読み取った内容
　　/procset log　　　　　　　　　　　バー切り替えや装備数の変化の記録
　　/procset probe　　　　　　　　　　自分のアビリティを一覧表示（結びつかない効果を探す）
　　/procset bind <アビリティID> <セット>[:<装備数>[-<n>]]
　　　　　　　　　　　　　　　　　　　アビリティを手動で、セットまたはその中の1つの効果に結びつける
　　/procset ignore <アビリティID>　　取り違えたアビリティを対象から外す
　　/procset preview　　　　　　　　　位置決め用のサンプル表示

■ 既知の制限

　効果の検出は、戦闘の出来事に付いているアビリティの名前を、セット名と説明文に結びつけて行う
　推定です。ゲームが実際にどんな名前を付けているかは、すべてのセットで確かめたわけではないので、
　行が出ても反応しない効果があるかもしれません。その場合は、/procset status で結びつけた
　アビリティを確認し、/procset probe で自分のアビリティの名前を調べ、/procset bind で手動で
　結びつけてください。

　敵に付く効果（デバフ）は、ゲームが知らせる範囲でしか追えません。ターゲットしている敵の
　ぶんは確実ですが、それ以外の敵のぶんが届くかどうかは確かめていません。

　説明文の言い回しによっては、秒数が持続時間なのかクールダウンなのかを、文中の位置から推定
　します。/procset status に「placed by position」と出ている行がそうです。表示が実際と
　ずれるときは、/procset text で読み取りを確かめてください。

　追うのは、自分が発動した効果だけです。同じセットを着た他のプレイヤーの効果には反応しません。

必須ライブラリはありません。LibHarvensAddonSettings があれば設定パネルが追加されます。
なくても初期設定のまま動き、/procset で操作できます。

## Description (EN)

Many set bonuses are something that fires, lasts a while, and then cannot fire again for a
while: "for 5 seconds", "once every 8 seconds". This add-on shows when each one fired, whether
it is still going, and when it is ready again, as a bar and numbers.

■ What it does not do

　It never presses anything. It reads the combat events the game reports and the set text on the
　items you wear, and draws a bar and some text, nothing more. It listens to combat events only
　while you wear a set that has a row.

■ What it shows

　One row for every effect whose bonus text names a time -- "for N seconds", "once every N
　seconds". A set that only adds stats gets none. A row is the set name, a bar and a line of text:

　　Active 3.2　　　(green)　　the seconds the effect has left; while its cooldown is also
　　　　　　　　　　　　　　　 counting it reads "Active 3.2  CD 4.8"
　　CD 4.8　　　　　(orange)　 the seconds the cooldown has left
　　Ready　　　　　 (blue)　　 it can fire again
　　-　　　　　　　 (grey)　　 nothing has happened yet, or the effect has no cooldown

　The bar flashes white for a moment as the effect fires. A small tick can sound when the
　cooldown ends. At most eight rows.

■ Nothing about any set is stored in the add-on

　No list of sets, no numbers, no ability ids. It reads the sets you wear and their text from
　the game. When a patch changes a number or a new set appears, it follows without an update, as
　long as the text names a time. The wording of the seconds is understood in Japanese, English,
　German, French, Spanish, Russian and Chinese.

■ Sets with several effects

　Every effect gets its own row and timer (active, cooldown, the abilities matched to it).

　- A set with several bonus lines that each name a time gets a row for every line that is
　　switched on (for example the 3-piece and the 5-piece bonus).
　- When one bonus line holds several effects, it is cut at the cooldown sentences and at
　　consecutive sentences that each name a duration, and each piece gets a row.
　- A set with several effects names its rows by the pieces needed: "Set name (5)", or "Set
　　name (5-2)" for the second effect inside one bonus.

■ When you swap bars

　If a bar swap switches a set's bonus off, an effect already on an enemy and a cooldown still
　counting carry on, and are shown to the end; the row then goes if the bonus is still off. If
　the piece count only seems to dip for a moment at the swap, the row stays when it is back
　within 2 seconds. Swap back and the timers carry on instead of starting over.

■ Choosing the sets to follow

　The section "Sets to follow" in the settings panel lists the sets that have a timed effect:
　the ones you wear now first, then the ones you wore before. Only ticked sets get rows.

　Turn "Follow newly worn sets" off and only the ticked sets are followed; a set you wear for
　the first time stays off until you tick it. That is the way to follow just a few sets.
　Unticking a set removes its rows at once, even while a timer is running.

■ Settings

　The settings panel needs LibHarvensAddonSettings.

　　Sets to follow　　 Follow newly worn sets　default: on
　　　　　　　　　　　 Tick all / Untick all, and a tick for every set
　　Show the timers　　　　　　　　　　　　 default: on
　　Only in combat　　　　　　　　　　　　　default: off
　　Only sets whose proc was seen　　　　　 default: off
　　Tick when the cooldown ends　　　　　　 default: off
　　Preview the rows　　　　　　　　　　　　five sample rows; not saved
　　Whole display　　　　　 horizontal and vertical position, size (%), row height
　　Set name, Bar, Status text
　　　　　　　　　　　　　　each: show, horizontal and vertical position, width
　　　　　　　　　　　　　　(the bar also height, the text also text size)
　　Colors　　　　　　　　　 In effect, Cooldown, Ready, Idle and Proc flash, each as red /
　　　　　　　　　　　　　　green / blue from 0 to 255. The bar and the text beside it share it
　　Reset all settings

■ Commands

　　/procset on | off　　　　　　　　show or hide the rows
　　/procset sets　　　　　　　　　　the sets you wear and whether each has a row (and why not)
　　/procset hide | show <id or part of the name>　stop or resume following a set
　　/procset status　　　　　　　　　each row: pieces, the times read, the abilities matched
　　/procset text [set id]　　　　　 the raw bonus text and what was read from it
　　/procset log　　　　　　　　　　　a record of bar swaps and piece counts
　　/procset probe　　　　　　　　　　list your own abilities (to find an effect that is not matched)
　　/procset bind <abilityId> <set>[:<pieces>[-<n>]]
　　　　　　　　　　　　　　　　　　　pin an ability to a set, or to one effect of it
　　/procset ignore <abilityId>　　　 never match this ability
　　/procset preview　　　　　　　　　sample rows for placing the display

■ Known limitations

　An effect is recognised by matching the name of the ability on a combat event to the set's name
　and text. How the game actually names the abilities has not been checked for every set, so a
　row may appear and never react. Then /procset status shows what was matched, /procset probe
　lists the names of your own abilities, and /procset bind pins one by hand.

　Debuffs on enemies are followed as far as the game reports them. The enemy you target is
　covered; whether the others are reported has not been checked.

　Depending on the wording, the add-on tells a duration from a cooldown by where the number
　stands in the sentence. A row marked "placed by position" in /procset status is one of those.
　If a row does not match the game, check what was read with /procset text.

　Only effects you fired are followed. Another player wearing the same set does not move your
　timers.

No required libraries. LibHarvensAddonSettings adds the settings panel if you have it; without
it the add-on runs on its defaults and /procset controls it.
