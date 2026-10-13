# 青番 · PROGRESS

## 概览

- 阶段：功能开发完成，已接入 CloudBase（三端互通），命令行构建通过。
- 构建：`hvigorw assembleHap --no-daemon` → `BUILD SUCCESSFUL`。
- 产物：`entry/build/default/outputs/default/entry-default-unsigned.hap`。

## 进度记录

### 2026-10-12

- 修复徽章图标不显示：BadgeIcon 的 SVG path 令牌化有误——一段数字串（如 0-6-2.5）被当成单数字 parseFloat，坐标全乱只剩小短线；新增 splitNumbers 按负号/小数点拆分为单数字令牌，离线仿真验证全部图标坐标范围正确（0~24 内）。
- 3D 金币弹窗恢复：抽成公共组件 components/CoinBadge.ets（Canvas 柱面 + PanGesture 拖动旋转，@Prop glyph 显示徽章 emoji），“我的”页徽章弹窗与 Badges 独立页详情弹窗共用；弹窗宽度统一 300。
- 构建：assembleHap → BUILD SUCCESSFUL。

- 徽章弹窗改为视频样式的 3D 彩虹奖章（CoinBadge.ets 重写，后于同日改为稀有度配色）：正面 16 段彩虹风车环（红橙黄绿蓝紫，内外弧错开 twist 形成漩涡）+ 白色币心 + 徽章 emoji + 左上高光；侧面 12 条暗色彩带随倾斜露出；自动摆动 ±30°（setInterval 33ms，angle=30·sin(t)），拖动检视同样限制 ±30°，拖动时暂停自动摆动；两个弹窗文案改为「徽章自动旋转 · 可拖动检视」。Python 离线渲染预览确认视觉效果后构建通过。

### 2026-10-11

- 徽章样式对齐小程序端（design/miniprogram.html）：
  - 新增 `components/BadgeIcon.ets`：Canvas 重绘小程序 const I 的线性描边图标（flame/leaf/star/trophy/lock），24×24 viewBox 坐标 + stroke 随尺寸缩放 + 圆角端点，替代 emoji。
  - `BadgeItem` 新增 `iconKey` 字段；`BADGE_CATALOG` b2 由「番茄丰收/🍅」改为小程序的「森林新芽/🍃 · 种下第 1 棵树解锁」；`AppState.copyBadges` 同步该字段，新增 `reconcileBadges` 兼容旧存档（补 iconKey、校正 b2 名称，不触碰解锁进度）。
  - `Me.ets` 徽章条：24px 图标、未解锁卡片整体 0.5 透明度 + 右下角 12px 锁标；徽章弹窗由「旋转金币 Canvas」改为小程序样式的 56×56 圆角 18 图标块（goldSoft/surface2）+ 状态胶囊 + 知道了按钮，删除金币绘制代码。
  - `Badges.ets` 独立页同步：卡片对齐小程序（圆角 16 / 间距 12 / 锁标 / 已获得 flame→tomato 其余→leafDeep、未解锁 ink3），新增详情弹窗；解锁条件保持不变。
  - 构建：`assembleHap` → BUILD SUCCESSFUL（注意：组件属性不能命名为 `size`，与内置通用属性冲突，已用 `iconSize`）。
  - 解锁条件按描述语义重排：b1 连续 7 天 → streak≥7；b2 森林新芽 → 累计番茄≥10（种下第 1 棵树）；b3 专注达人 → 累计专注≥100 小时（新增 totalFocusMinutes()）；b4 月度冠军 → 暂无排行系统，沿用「今日完成挑战目标」。

### 2026-09-19

- 引导页改为横向滑动轮播（Swiper + 动画 + 可点圆点）。
- 登录页补叶子背景装饰、Logo 摇摆动画；后续加入注册。
- 修复 `Focus` 倒计时未启动的 bug；切换时长重置计时基准。
- `WidgetPicker` 按原型重写为整屏预览；修复切换尺寸错位。
- 次级页（ThemePicker/Badges/Notify/EditProfile/AIAssistant）统一主题令牌（原写死浅色，深色主题穿帮）。

### 2026-09-20 ~ 09-21

- 首页待办：`List + onItemDragStart/onItemDrop` 实现长按拖动排序；`@State tasks` 驱动刷新。
- 专注背景改为「天空 / 晨雾 / 夕阳」，色块显示对应颜色；新增开始/暂停。
- 待办支持添加时长（预设 + 自定义）。
- 签到规则：文案与实际奖励一致；点击即时刷新；连续 = 签到且专注≥10min；森林 = 每 10 番茄 1 棵树；提前退出记录原因。
- 新增新手引导（启动引导回放 + 首页高亮气泡）。
- 桌面小组件：修复 4×4 溢出、删除图标网格、修复切换尺寸错位；「添加到桌面」改走 `formProvider.openFormManager`。
- 项目推送到 GitHub：`https://github.com/mufeng661/qingfan_HarmonyOs`。

### 2026-09-22 ~ 09-23

- 接入 CloudBase：写入 `.opencode.json`（MCP）、安装 `@cloudbase/cli`、登录并设置环境。
- 访客模式：游客可用待办+计时；AI/统计/自习室需登录；自习室曾设「专注满 25 分钟」后取消。
- 自习室改为对接三端共用云函数 `studyRoomFunctions`：房间列表/创建/按房间号加入/退出/解散、房间留言+回复、房间内计时、房间成员弹窗。
- 登录/注册改走云函数 `auth.login`/`auth.register`（与 Web/小程序同一套账号）。
- 业务数据按手机号隔离存储；退出登录保留账号数据，登录后 `loadBusinessData()` 恢复（番茄/时长/已加入自习室）。
- 底部导航删除「排行」标签（排行移入自习室计时界面的「房间成员」）。
- 房间成员排行展示专注时长（本人本机累计；`focus.record` 上报已预留，云函数未支持时自动忽略）。

### 2026-09-30

- 修复云函数 `room.create` 失败：线上 `rooms_self` 实为 `id`(bigint 自增 PK) + `room_no`(varchar 唯一非空) 双列结构，旧代码只写 `id`、漏写 `room_no`，触发 `Field 'room_no' doesn't have a default value` / `Duplicate entry '' for key 'uk_rooms_room_no'`。改为**生成唯一 6 位 `room_no` 写入**，并让 `room.get` / `room.listMine` / `room.join` 以 `room_no` 作为 `id` 下发（房间号语义由 UUID 改为 6 位数字）。
- 修复 `room.listMine` 的 `member_count` 恒为 1：`.in("room_id", …)` 只选 `room_id` 时，同房间多行内容完全相同被整行去重；改为 `select("room_id,user_id")` 后计数正确（App 端 `room.get` 兜底可移除，暂留无害）。
- 云函数 `studyRoomFunctions` 源码纳入本地管理（`index/cloudbase/auth/token/password/utils` + `schema.sql`）；确认该环境（`cloud1-d5g8q89yd66340db4`）当前账号**已可访问与部署**。
- 部署要点：`tcb fn code update` 需在函数目录内执行（否则按 `functionRootPath`=当前目录打包），`--deployMode zip` 在含依赖时超 1.5MB 上限，改用**不含 `node_modules` 的源码包**走 ZIP base64（云端按 `InstallDependency` 安装依赖）。
- 联调通过：`room.create → room.get → room.join → comment.add → comment.list → room.listMine → room.delete` 全链路正常，中文名/留言入库与回读无误；联调数据已清理。
- 自习室房间号支持复制：房间卡片与留言弹窗均加复制入口（`@kit.BasicServicesKit` 剪贴板 + Toast）；创建成功后自动复制房间号；加入弹窗文案改为「6 位数字」。
- 自习室房间卡片重排：文字（房间名/房间号/人数/开始自习）左对齐、图标（💬 标题行右、📋 房间号行右）右对齐；删除/退出由卡片按钮改为**列表左滑**（`List + ListItem.swipeAction`，露出「解散 / 退出」后走二次确认弹窗）。

### 2026-10-01

- **AI 接入真实大模型（B 方案）**：云函数新增 `ai.chat` / `ai.insight`（`ai.js`，OpenAI 兼容 `/chat/completions`，Node 内置 `https`；密钥只存云函数环境变量 `AI_BASE_URL` / `AI_API_KEY` / `AI_MODEL`，客户端零密钥）。
- 前端新增 `service/CloudAiService.ets`（组装真实上下文：昵称/今日专注/番茄/连续/打断原因/待办），`CloudFnService.call` 支持自定义 `readTimeout`（AI 用 60s）。
- `AIChat`（对话 + 建议卡）、`Stats`（AI 洞察）、`Home`（AI 建议卡）接入真实模型，**未登录或调用失败时回退本地文案**；删除原先写死的假洞察/假建议。
- 已在云函数配置 AI 环境变量（DeepSeek：`AI_BASE_URL`/`AI_MODEL=deepseek-chat`/`AI_API_KEY`/`AI_TIMEOUT_MS`）、函数超时提到 **60s** 并部署；联调通过：`ai.chat` 与 `ai.insight` 均返回真实模型回复（含用户数据上下文），未登录返回 `NO_USER`。
- **AI 用量治理**：新增 `ai_usage_self` 表（`user_id`+北京时间日期唯一，列名 `used` 避开 rdb 的 `count` 聚合冲突），云函数 `ai.js` 加**每人每日配额**（`AI_DAILY_LIMIT`，默认 50）+ **频率限制**（`AI_MIN_INTERVAL_MS`，默认 8s），超限返回 `AI_QUOTA_EXCEEDED` / `AI_RATE_LIMIT`；前端 `AIChat` 直接提示，`Stats`/`Home` 静默回退。DB 异常 fail-open。已部署并实测通过。
- **AI 聊天记录**：`AIChat` 对话（问 + 答）本地持久化（`Store`，按账号 `qf_ai_chat_<userKey>`，保留最近 200 条），进入页面自动恢复；顶栏「🗑」可一键**清空记录**（`promptAction.showDialog` 二次确认）。
- **AI 计划 → 待办联动**：`ai.chat` 支持 `wantPlan`（用户消息含「计划/规划/安排/清单/制定」等触发），云函数要求模型在回复末尾输出 ```json``` 计划块并解析为 `todos`（title/durationMin/difficulty）；`AIChat` 收到后**自动写入待办列表**并提示「已添加 N 个待办」，建议卡新增「制定今日计划」。
- **统计时间轴改真实数据**：`Stats` 的「今日完成时间轴」只取当日真实专注记录（`AppState.records`），移除写死的演示时间轴；无记录时显示空状态「今天还没有完成记录」。
- **导航与统计改版**：底部导航由 4 项改为 5 项（今日/自习室/**时间轴**/**数据**/我的）；原「统计」页改为**时间轴页**（`Stats`，日/周/月切换，展示真实专注记录，空状态提示）；新增**数据页**（`DataStats`）：累计专注卡（次数/累计时长/日均时长）、当日专注卡（实时日期/次数/时长）、**专注时长分布（饼图，按任务占比，日/周/月切换）**、**月度专注统计卡（标题带年月 + `🗓`/`‹`/`›`；折线/面积图：纵轴多级刻度用 Text、横轴列出每一天并可横向滑动；`🗓` 打开**居中热力图弹窗**[真实日历排布、空白格留空、绝对色阶、<1h 标注 `<1h`]）**、本月打断原因分布（横向条）、AI 洞察。图表文字一律用 ArkUI `Text`（Canvas 的 `fillText` 不渲染），Canvas 只画图形；数据取本地真实统计（按账号隔离）。
- **首次引导优化**：首页新手引导按登录状态自适应——游客不显示需登录的「签到/挑战」，只讲「待办 / AI / 底部导航」；修正底部导航过时文案（排行 → 时间轴 / 数据）；引导延迟到布局测量后再弹出，修复高亮/气泡错位。
- **新账号引导待办**：新账号（含游客）首次进入待办页种入 4 条引导待办（作用 / 添加 / 删除 / 开始），登录账号只种一次（`qf_tasks_seeded`）。
- **自习室升级**：后端「一人一室」（`room.create`/`room.join` 校验，返回 `ALREADY_IN_ROOM`）、新增 `focus.record`（房间模式完成番茄累加 `room_members_self.focus_minutes`，成员按此排名）与 `room.kick`（房主移除成员）；前端房间卡片显示「我的专注 X 分」并支持分享（复制含加入码文案）、`Focus` 成员榜按专注时长排名且房主可长按成员移出（二次确认）、房主解散需二次确认 + 10s 倒计时、`Home` 读剪贴板命中分享文案弹出邀请加入弹窗（加入预填房间号）。
- **自习室页改版**：`StudyRoom` 按状态切换——无房间时只显示「加入 / 创建」卡片；有房间时直接内联显示房间信息与**成员专注排行**；待办模式完成的专注时长也计入本人所在自习室（`Focus.reportToMyRoom`，一人一室取当前房间）。
- **自习室规则升级（按图）**：新增 **8 位加入码**（`rooms_self.join_code`）与**每日最低专注时长**（`daily_min`，默认 30、0=不设限，`room.join` 房间号/加入码皆可）；`focus.start` 标记「正在专注中」、`focus.record` 累加当日；留言需当日达标（`NEED_FOCUS`）；**`room.settle` 每日定时结算**（云函数定时触发器 `dailySettle` 每天 00:05：达标累计 `streak_days`/`total_days`，未达标移出、房主除外）。房间页按图重设计：房间名 + 加入码、正在专注中人数、当前排名、成员专注卡片（今日已专注/连续/共专注/累计分钟），并删除「开始专注」按钮、留言入口由「许愿墙」改回「留言」。已部署并联调（含定时结算验证）。

### 2026-10-12

- **等级经验体系升级（三端同步）**：每升一级所需经验递增——公式 `expForLevel(n) = 200 + (n-1) * 100`（L1→L2: 200, L2→L3: 300, L5→L6: 600, L10→L11: 1100…），替代原来固定 3000 × 1.5^(n-1)。
  - 新增 6 段等级阶段名（`LEVEL_TIERS`）：萌新叶(L1) / 成长苗(L6) / 繁茂枝(L11) / 参天木(L21) / 森林守护(L31) / 传说之森(L51)，每段有独立配色与渐变背景色。
  - **ArkTS 端**：`Types.ets` 新增 `expForLevel()` / `tierOfLevel()` / `LevelTier` / `LEVEL_TIERS`；`AppState.signInToday()`、`Focus`、`Home`、`StudyRoomFocus` 升级逻辑全部改用 `expForLevel(u.level + 1)`；`guestUser()` / `Login` 初始 `nextLevelExp` 改为 `expForLevel(1)`。
  - **Web / 小程序端**（`design/index.html`、`web.html`、`miniprogram.html`）：移除硬编码 `expMax = 3000`，改用 `expForLevel(level)` 动态计算；`handleSign` / `handleToggleDone` / `handleComplete` 新增 level-up 逻辑（`while` 循环扣减经验并 `setLevel`）；初始演示状态从 `level=12 exp=2450` 改为 `level=3 exp=150`。
- **等级卡片 UI 优化（仿小黑盒）**：三端统一将原来分散的「个人信息卡 + 经验值卡」合并为单张渐变等级卡片——深色渐变背景（按等级阶段配色）、头像 + `Lv.X` 徽章（徽章底色随阶段变化）、阶段名 pill 标签、白色经验进度条、半透明文字层级。ArkTS 端 `Me.profileHeader()` 重写（删除原 `expCard`），Web / 小程序端 `ScreenMe` 同步重写。

### 2026-10-10

- **修复徽章弹窗不显示奖章样式（小程序移植兼容）**：`Me.badgePanel` 的 3D 硬币用 `translate/scale + arc(r=1)` 画椭圆且在 `fill()` 前 `restore()`——小程序端（路径添加时烘焙矩阵）正常，鸿蒙 ArkUI Canvas（Skia，绘制时才应用矩阵）画出来只有 1px 点。改为 `ellipse()` 直接定义椭圆路径（`Me.coinPath`），不依赖 save/restore 语义。
- **修复 Home 编译错误**：`regenerateTodos` 用到 `Msg` 接口（`Store.getArr<Msg>`）但该接口是 `AIChat.ets` 页面私有定义，在 `Home.ets` 补同构本地接口。

### Web / 小程序端（`qingfan(web)` 及同构小程序）

- **功能与鸿蒙端一致**：引导、登录注册、今日待办、专注计时、成长（我的）、统计、自习室、主题、AI 助手。
- 自习室已实现：`index.html`（我的自习室/自习动态/留言板/好友的自习室）、`login.html`、`create.html`、`join.html`、`room.html`（成员 + 交流/回复/点赞/删除/分页）。
- 登录/注册与鸿蒙同一套账号（`auth.login` / `auth.register`），token 存 localStorage。
- 小程序：与 Web 同构（`wx.cloud.callFunction`），身份为微信 OPENID。
- 三端共用云函数 `studyRoomFunctions` 与同一套账号，房间/留言互通。

## 已知问题 / 依赖后端

- 云函数无 `focus.record` 与成员 `nickname/focus_minutes`，故成员真实昵称/真实时长排行暂不可得。
- （已解决 09-30）`room.create` 的 `room_no` 唯一约束冲突、`room.listMine` 的 `member_count` 恒为 1、该环境不可访问。

- 徽章配色改为稀有度阶段色（用户反馈：要视频的样式而非彩虹色）：BadgeItem 新增 tier 字段（0未解锁/1青铜/2白银/3黄金/4钻石），BADGE_TIER_GOALS 定义各徽章升阶阈值（b1 streak 7/14/30/60；b2 累计番茄 10/50/200/500；b3 专注分钟 6000/12000/30000/60000；b4 今日数÷目标倍数 1/2/3/5）；Badges.ets recalcBadges 计算并持久化；CoinBadge.ets 彩虹风车改为阶段主色/亮色交替纹路 + 阶段暗色侧面，币心图案色随阶段；弹窗胶囊显示「已获得 · 阶段名」；AppState copyBadges/reconcileBadges 同步 tier（旧存档默认按已获得=青铜）。构建 BUILD SUCCESSFUL。

- 修复徽章只向一侧转：厚度带原先固定画在币面右侧且角度取绝对值，正负角渲染相同；改为按 angle 符号镜像厚度带方向（dir=±1），厚度改为 thickness·|sin|（正对时 0），±30° 观感一致。币心美化：抽 BadgeIcon.ets 导出 drawGlyphCentered()，CoinBadge 币心改为白色渐变 + 阶段色装饰双环 + 线性描边图标（未解锁自动绘 lock），CoinBadge 的 glyph(emoji) 属性由 iconKey 取代，两个弹窗调用同步更新。构建 BUILD SUCCESSFUL（1m12s）。

- 币心图标优化：删除未解锁显示锁形的逻辑（始终显示徽章自身图案，未解锁以灰色阶段区分），图标放大至 rIn 全径，新增阶段色淡色底衬圆盘（12% 透明 face2）与柔和投影（shadowBlur 8 / offsetY 2.5）提升立体感与视觉层次。HTML 预览同步更新。构建 BUILD SUCCESSFUL（1m17s）。

- b2 徽章由「森林新芽/🍃」改为番茄主题「番茄丰收/🍅」：BadgeIcon 新增 tomato 线性图标（果身+果梗+双萼叶），badgeIconKey(b2)→tomato，条目配色 flame/tomato→番茄红；升阶阈值不变（累计番茄 10/50/200/500）。徽章弹窗新增右上角「下一等级 · X」按钮（已解锁且未满级时显示）：点击后奖章切换为下一稀有度配色预览、状态胶囊显示「下一等级 · X」，再点「返回当前等级」复原；Me.ets 与 Badges.ets 共用该交互（badgePreviewNext/previewNext 状态，打开弹窗时重置）。当前等级徽章展示保持不变（奖章颜色始终为当前 tier）。构建 BUILD SUCCESSFUL（40s）。

- 修复番茄图标乱线 + 「已获得·未解锁」矛盾文案 + 右上角按钮不显示：①tomato 果身 path 用了 s（平滑三次曲线）命令，解析器只支持 M/L/H/V/C/A/Z，s 被跳过导致果身丢失只剩萼叶乱线；重写果身为 4 段 C 命令（隐式重复）并新增左侧高光弧。②tierOf 兜底修正：旧存档 unlocked=true 但 tier=0 时返回 0 拼出「已获得·未解锁」且奖章误显灰色、按钮被 tier≥1 条件卡住；改为 unlocked ⇒ tier 夹到 1~4、未解锁 ⇒ 0。构建 BUILD SUCCESSFUL（36s）。

### 2026-10-12 · 三端等级经验体系对齐（测试 + Web 端补齐）

- 测试结论：小程序端（design/miniprogram.html）与鸿蒙端（Types.ets/Me.ets）早已完成「递进经验 + 小黑盒式等级卡片」，Web 端（qingfan(web)）仅有文字行+细进度条，为唯一缺口。
- Web 端修复：store.js nextLevelExp 由 level*300 改为 200+(level-1)*100（对齐三端，旧存档兼容）；新增 LEVEL_TIERS(6段)/tierOfLevel()/levelInfo()；defaultProfile 加 nextLevelExp 字段；app.js screenMe() 等级区由文字行改为 level-card 结构（渐变卡+头像Lv徽标+段位标签+经验条+升级提示）；styles.css 追加 .level-card* 样式。
- 三端一致性测试全通过：公式三者均为 200+(level-1)*100；6 段段名与 minLevel=[1,6,11,21,31,51] 完全一致；卡片关键元素各 6 项全部命中；离线渲染 4 场景（Lv1/7/25/游客）文案与进度宽度断言 PASS；鸿蒙端 assembleHap BUILD SUCCESSFUL 未受影响。

### 2026-10-12 · Web「我的」等级卡片修复 + 底色跟随主题

- **根因**：`app.html` 只引用 `app.css`，而上一步把 `.level-card*` 样式误写进了 `styles.css`（仅 login/room/studyroom 等页引用）。结果「我的」页等级卡片零样式渲染——正是用户截图里的深绿块 + 黑字 + 元素纵排散架。规则实际使用方只有 `app.js`，故为死代码，已从 `styles.css` 移除并落到 `app.css`。
- **底色改为跟随主题**：app.css 四套主题令牌各新增 `--lv-from / --lv-to / --lv-shadow`（青番绿 #4c7a3e→#2b4022 / 深夜墨 #36452f→#131a12 / 晨光暖 #b8804a→#5a3a1c / 静谧蓝 #5c8ba6→#1f3746）；`.level-card` 背景改为 `radial-gradient(--lv-accent-soft) + linear-gradient(140deg, var(--lv-from), var(--lv-to))`，切换主题即时改变卡片背景。
- **段位色保留为点缀**：`app.js` 移除写死的 `linear-gradient(tier.bgFrom, tier.bgTo)` 内联背景，改为注入 `--lv-accent-soft: hexA(tier.color, .34)`（新增 `hexA()` 工具）作右上角柔和光晕；Lv 徽标底色仍为 `tier.color`，段位名标签/等级信息不丢失。
- **顺带优化**：昵称包 `<span class="level-card__nick">`，`nowrap + ellipsis`，超长昵称不再把段位标签挤出卡片（原先会换行撑高）；补 `@media (max-width:430px)` 小屏压缩（头像 50 / 字号 16 / 内边距 16）；统一卡阴影 `--lv-shadow`。
- **验证**（非 mockup，跑真实页面）：临时 seed 页写入 `qingfan:onboarded/theme/profile` 后跳转 `app.html#/me`，用 Chrome headless 分别截 4 套主题的真实渲染 → `.workbuddy/theme_switch_verify_2026-10-12.png`，四色一一对应且白字可读；另出交互预览 `.workbuddy/theme_level_card_preview.html`（内联线上 app.css，含 6 段位点缀色与超长昵称用例）→ `.workbuddy/theme_level_card_preview.png`。校验脚本确认 app.css 有 24 条 `.level-card*` 规则、花括号平衡、无未定义类名。
- **未改动**：小程序端设计稿（design/*.html）与鸿蒙端（Types.ets/Me.ets）仍按段位色渲染卡片；如需三端一致可再同步（本次用户仅指向该界面）。

### 2026-10-12 · Web 端开发热刷新（LiveReload）

- `serve.js`（无依赖本地静态服务器）内置热刷新，改文件后浏览器自动更新：`fs.watch` 递归监听 `.html/.css/.js/.json/.svg`，80ms 去抖合并同批事件；页面经 SSE `/__livereload` 长连接接收。
- 分流策略：**仅 CSS 变更 → 免刷新热替换样式表**（清掉旧 `__lr` 时间戳再追加，保留滚动/表单/正在计时的专注状态）；JS/HTML 变更 → 整页 `location.reload()`（`#/` 路由与登录态保留）。右下角角标提示 1.5s 淡出，`pointer-events:none` 不拦截点击。
- 服务端自动注入客户端脚本（HTML 纯追加，已逐字节校验：磁盘 2968 → 服务 5146 → 去掉注入 2968 完全一致）；`QF_LIVE=0` 全服务关闭，`?nolive=1` 单页关闭。
- **踩坑（已修）**：①SSE 清理必须监听 `res.on('close')` 而非 `req.on('close')` —— 无 body 的 GET 在收到请求头时即算完成，`req` 会立刻 close，把刚加入的客户端马上移除，表现为事件「推送至 0 个页面」；②长连接需 `res.socket.setTimeout(0) + setKeepAlive(true)`，避免 Node 默认 `keepAliveTimeout(5s)` 掐断 SSE；③20s 心跳防中间层回收。
- **验证**：Node SSE 客户端实测收到 `css → reload` 两个事件且流不掉线；注入脚本在 vm 沙箱 + 假 DOM 中单测（热替换/不误刷新/`__lr` 不累积/角标）全 PASS；真实 Chrome 加载时服务端日志出现「页面已连接」，证明注入脚本在浏览器中确实执行。调试脚本留存 `.workbuddy/_sse_test.js`、`_client_logic_test.js`、`_inject_diff_test.js`。

### 2026-10-12 · Web 端「我的」页：移除段位标签 + 修复主题选中态不更新

- **需求①**：删掉等级卡片昵称右侧的段位药丸（截图中的「萌新叶」）。`app.js` 的 `screenMe()` 只保留 `<span class="level-card__nick">`；`app.css` 删除 `.level-card__tier` 规则并把 `__nick` 改为 `flex: 1 1 auto`（昵称独占整行、超长仍省略号截断）；段位信息仍由 Lv 徽标底色与右上角 `--lv-accent-soft` 光晕承载，未丢失。`.workbuddy/gen_theme_preview.js` 同步去掉该药丸。
- **需求②（真 bug）**：切换主题时页面配色已变，但主题按钮高亮「卡」在原主题不动。**根因**：处理器原为 `D.setTheme(th); go('me')`，`go()` 仅改 `location.hash`；当前已在 `#/me` 时 hash 不变 → 不触发 `hashchange` → `route()`/重渲染不执行 → 依赖重渲染刷新的 `.pill.is-on` 永远停留在旧主题。而 `setTheme()` 内部直接 `applyTheme()` 改 `<html data-theme>`，故配色能变、高亮不变 —— 正是用户截图（高亮在「静谧蓝」而底色是「晨光暖」）。
- **修复**：`paintThemeDots()`（原只选 `#themeDots [data-th]`）升级为 `paintThemeUI()`，选择器放宽为 `[data-th]`，一处同时覆盖侧栏圆点与「我的」页按钮；主题按钮点击处理器改为 `setTheme + paintThemeUI()` 并去掉 `go('me')`，**顺带免掉整页重渲染**（不闪屏、保留滚动位置）。`renderRoute()` 与侧栏圆点处理器同步改名。
- **验证**（跑真实 `app.html#/me`，非 mockup）：临时 `_theme_test.html` 以同源 iframe 驱动真实页面，**25 项断言全 PASS** —— 段位药丸 0 个、卡片内无段位名残留、昵称仅 1 个子元素、`ellipsis` 生效、超长昵称不再撑高/撑破卡片、初始高亮正确、点击后 hash 不变但 `data-theme` 与按钮+圆点高亮同步、连续切换 `is-on` 恒为 2、侧栏圆点反向同步、localStorage 持久化。
- **产出**：对比图 `.workbuddy/theme_fix_verify_2026-10-12.png`（初始态 vs 点击「晨光暖」后）。临时文件 `_theme_test.html` / `_shot_me.html` / `_shot_a.png` / `_shot_b.png` / `_compare.html` 均已清理。
- **未改动（范围提示）**：小程序设计稿与鸿蒙端 `Me.ets` 仍显示段位名，如需三端一致需另同步（本次用户仅指向 Web 端截图）。

### 2026-10-12 · 撤销 Web 端热刷新（LiveReload）

- 用户要求「将刚才添加的热刷新取消」。因 `serve.js` 与 `README.md` 的未提交改动 100% 属热刷新功能（已用 `git diff` 逐段确认无其它内容），直接 `git checkout -- serve.js README.md` 干净还原：`serve.js` 259 → 50 行（回到无依赖静态服务器），`README.md` 回到原版（热刷新章节整段移除）。
- 还原后 Web 目录仅剩 `app.css` / `app.js` / `store.js` 三处改动，即等级卡片与主题选中态修复，予以保留。
- **验证**：`node --check serve.js` 通过；启动服务后 ①`app.html` 不再含 `data-qf-live` / `__livereload`（计数 0）；②`/__livereload` 返回 404；③服务端返回的 `app.html` 与磁盘文件逐字节一致（3092 = 3092，确认服务端零注入）；④`app.css` 正常 200 `text/css`；⑤启动日志回到原始的「青番留言板已启动」。
- **清理**：删除 `.workbuddy` 下热刷新的 3 个调试脚本（`_sse_test.js` / `_client_logic_test.js` / `_inject_diff_test.js`）及验证截图 `live_reload_page_check.png`。
- **影响**：改完文件需手动刷新浏览器（F5）；`serve.js` 恢复为最初的无依赖 50 行版本。

### 2026-10-12 · 三端「更改昵称 / 个性签名」功能完善

**统一规格**（三端一致）：昵称必填、去首尾空格、最长 **12** 字；个性签名可空、去首尾空格、最长 **30** 字；实时字数计数（满格变红）；超限按**码点**截断；昵称为空拦截保存并提示；保存后卡片即时更新、头像跟随昵称首字、本地持久化、登录态云端同步。

- **鸿蒙端**：`Types.ets` 新增共享常量与工具 `MAX_NICK=12 / MAX_BIO=30 / cpLen() / cpCut() / firstCp()`（按码点计数与截断，emoji 算 1 个字且不会被劈成半个代理对）。`EditProfile.ets` 重写表单区：昵称/签名各加 `maxLength` + 实时计数 Row（满格转 `t.tomato`）+ `onChange` 兜底截断、`Scroll` 包裹防小屏溢出、签名 placeholder 统一为「写一句鼓励自己的话」；新增 `avatarTouched`，未手动挑头像时 `avatarSeed` 跟随新昵称首字（挑过则保留 emoji）。`Me.ets` 的 `firstChar()` 改为优先取 `avatarSeed`、退回昵称首字（按码点），让此前形同虚设的头像选择器真正生效。
- **小程序设计稿** `design/miniprogram.html`：`ScreenMe` 新增 `showToast` 通道；弹窗补头像预览、字数计数（满格变红）、输入即时按码点截断；`saveProfile` 补空昵称拦截 + 保存 toast（原实现是静默保留旧值，点了没反应）；`name/signature` 落 `localStorage`（`qf:mp:nick` / `qf:mp:bio`）实现刷新后保留；默认签名文案由「把专注，种成一片森林」统一为「把专注，种成一片番茄园」；头像 `{name[0]}` 改 `{firstCp(name)}` 按码点取。
- **Web 端** `qingfan(web)`（此前**完全没有**该功能）：等级卡片加 `id="lvCard"` + `cursor:pointer` 并绑定点击 → 新增 `editProfileModal()`（复用既有 `openModal`），含头像首字预览、昵称/签名输入、`n / 12` / `n / 30` 实时计数、空昵称拦截、回车保存、保存 toast；新增 `MAX_NICK/MAX_BIO` 与 `cpArr/cpLen/cpCut/firstCp` 工具。保存写 `profile` + 登录态 `auth.setNickname()` + `D.saveProfile()`（本地 + `data.saveProfile` 云同步），随后调 `renderRoute()` 重渲染。
- **连带修掉的 3 个真 bug**：
  1. `auth.getNickname()` 优先读会话用户对象，而 `setNickname()` 只写 `NICK_KEY` → 登录用户改完昵称界面不变。改为 `setNickname()` 同时 `patchUser({nickname})`。
  2. `screenMe()` 里游客昵称硬编码 `'游客'`，而档案里存的是「专注的你」，导致弹窗预填名与卡片显示不一致。统一为档案里的 `nickname`（`defaultProfile` 兜底改 `'游客'`，并对旧数据做一次性归一迁移）。
  3. 「退出登录」按钮用 `go('me')`，而 hash 已是 `#/me` → 不重渲染，退登后界面不更新（与主题选中态是同一类 bug）。改用 `renderRoute()`。
- **验证**（跑真实运行页面，非 mockup）：
  - Web 端：同源 iframe 驱动 `app.html#/me`，**42 项断言全 PASS**（弹窗结构/预填/计数/12 字截断/满格变色/emoji 计 1 个且不被劈开/空昵称拦截 + toast/保存后卡片与本地档案更新/刷新持久化/登录态改昵称生效且不被旧登录昵称盖住/账号档案与游客档案隔离/回车保存/退登重渲染）。
  - 小程序端：同源 iframe 驱动 `design/miniprogram.html`（点「跳过」→ 登录 → 我的 → 卡片），**33 项断言全 PASS**（含 Babel 编译 + React 渲染、计数、截断、警示色、空值拦截、保存落 localStorage、重挂载后仍保留、默认文案已统一）。
  - 鸿蒙端：`assembleHap` **BUILD SUCCESSFUL**（2m3s），产出新的 `entry-default-signed.hap`（21:31），改动文件无 WARN/ERROR。
  - 产出对比图 `.workbuddy/profile_edit_verify_2026-10-12.png`。临时测试/截图文件已全部清理。
- **遗留提示**：小程序设计稿里「把专注，种成一片森林」仍作为品牌标语出现在未登录门户与引导页文案中（属营销文案，非资料字段），未改动。

---

## 修复「三端改名 / 改签名不同步」+ 鸿蒙端改完需刷新才显示（2026-10-12 晚）

用户实测反馈 4 条：①小程序端无法修改名称与个性签名 ②鸿蒙端改完要点刷新才显示 ③Web 端同一账号的名称签名不同步 ④Web 端改完，鸿蒙端与小程序端不同步。逐条排查后**全部确认为真实缺陷**，根因如下：

**① 鸿蒙端「拉不到别人的改动」** — `AppState.pullCloud()` 只接收 `level/exp/nextLevelExp/streak/lastSignDate/signDates`，**唯独漏了 `nickname / avatarSeed / bio`**：别的端改了名字，鸿蒙端拉云端也当没看见，而且下一次 `saveUser()` 还会把自己的旧名字推回去，形成互相覆盖。已补上这三个字段的接收，并加「本地 4 秒内刚推过就以本地为准」（`AppState.lastProfilePushAt`）的回声保护；只在值真的不同时才覆盖并广播。

**② 鸿蒙端资料卡不刷新** — 两层原因叠加：
- `@State uiTick` 一直在 `+= 1`，但**从未被 `build()` 读取过**。ArkUI 只重绘「读到了该状态」的节点，不读就等于空转；
- `Text(AppState.instance.user?.nickname)` 读的是普通对象的属性，本身不可观察。
修法：`Me.ets` / `Home.ets` 各加 `@StorageLink('qfProfileTick') @Watch(...)`，并把资料抄成 `@State` 镜像（`pNick/pBio/pAvatar/pLevel/pExp/pNextExp`、`greetName`）供 UI 读取；`EditProfile.save()` 保存后调 `AppState.notifyProfileChanged()` 广播。**坑：`saveUser()` 里绝不能广播**，否则 `onProfileTick → syncUserState → saveUser → 广播` 会死循环。

**③ Web 端「同账号名称不同步」** — `auth.getNickname()` 读的是**登录那一刻**写进 localStorage 的会话快照，而它优先级高于刚拉下来的 `p.nickname`，于是把云端新名字又盖了回去。修法：`screenMe()` / `refreshUserChip()` 一律以本地档案为准（`p.nickname || auth.getNickname()`）；`store.cloudPull()` 合并完远端资料后把昵称回写登录态；另加 `focus` / `visibilitychange` 时强制拉取一次（开着弹窗或正在输入时跳过，避免刷掉用户输入）。

**④ 小程序端「无法修改」** — 登录态没持久化（`useState(false)`），原型一刷新就掉登录，「我的」页只剩登录门户，**连点卡片改资料的入口都不存在**。修法：登录态与账号落 `localStorage`（`qf:mp:login` / `qf:mp:acct`）；昵称/签名提升到 App 级，改完首页问候语也立刻跟着变。

**⑤ 小程序端真正接上同一套云端** — 原型原先纯 localStorage，天然不可能与另两端同步。新增模块级 `QF_CLOUD` / `QF_LS` / `qfCloudCall()`（与 `web/api.js` 同构：`POST {action,userId,platform,...}` → `{success,data}`，6 秒超时，失败一律返回 `null` 静默降级）；登录后 `data.pull` 拉资料，保存时「先拉 → 合并 → 再推」`data.saveProfile`；身份统一用手机号，三端落在 `user_data_self` 同一行。离线时提示「仅本机生效」而非静默无反馈。

**⑥ 云函数 `data.js` 的 `saveProfile` 改为字段级合并** — 原来是整体覆盖，而小程序端只推昵称/签名，会把另两端写进去的等级/经验等字段抹掉；改为 `Object.assign(旧值, 新值)`。**此项需重新部署 `studyRoomFunctions` 才生效**（未部署也不影响：客户端已做「先拉后合并再推」）。

**验证**（均驱动真实运行页面）：
| 端 | 方式 | 结果 |
|---|---|---|
| 小程序端 | 同源 iframe + 受控 fetch 桩（云端有值 / 离线两套副本） | **27/27 PASS**：云端拉取生效、编辑后推送含字段保全（level/exp 未被抹）、localStorage 落盘、刷新后仍登录、离线降级提示、首页问候语跟随 |
| Web 端 | 受控 fetch 桩 + 预置「会话里是旧昵称」 | **20/20 PASS**：卡片与首页都显示云端新昵称、登录态昵称被回写、自己改完推送且未把等级抹空、本地档案持久化 |
| 鸿蒙端 | `assembleHap` 命令行构建 | **BUILD SUCCESSFUL**，产出新 HAP；仅剩既有的 `replaceUrl/px2vp/pushUrl/showToast` 弃用告警，改动文件无 WARN/ERROR |
| 云函数 | Node 桩验证 merge 语义 | 只推昵称+签名时，`level:7 / exp:320` 未被抹掉 |

产出对比图 `.workbuddy/profile_sync_verify_2026-10-12.png`（Web 端与小程序端「我的」页均显示云端同步过来的昵称/签名）。临时测试文件与副本已全部清理。

---

## 小程序端「点头像即改资料」（2026-10-13）

用户要求：小程序端改昵称 / 个性签名，在「我的」页**点一下头像**就能改。

- 排查结论：原实现是「点整张等级卡」触发编辑弹窗——头像虽在卡内、点它其实也生效，但没有独立的可点语义，也没有任何「这里能点」的提示。
- 本轮改动（`design/miniprogram.html` 的 `ScreenMe`）：
  1. 头像单独包一层 `.qf-avatar-tap` 容器并显式绑定 `onClick`（先 `e.stopPropagation()` 再调 `openEdit()`），补 `role=button` / `tabIndex` / `title` 提示；Lv 徽章与新增角标均设 `pointerEvents:none`，不抢点击。
  2. 头像**右上角新增 20px 白底铅笔角标**（沿用 Lv 徽章的 2px 白边风格），让「头像可点」一眼可见；Lv 徽章仍在右下角，两者不重叠。
  3. `<style>` 补 `.qf-avatar-tap:active { transform: scale(0.93) }`——触屏没有 hover，按下要有即时反馈。
  4. 整卡点击入口**保留**（点昵称 / 经验条同样可进编辑），头像只是新增的更明确的入口。
- **验证**：同源 iframe 驱动真实页面（跳过引导 → 我的 → 点头像），**21/21 PASS**：头像被可点容器包裹、角标与 `title` 就位、点头像弹出「编辑资料」、弹窗内两个输入框 + `n / 12`、`n / 30` 计数、改名改签名保存后弹窗关闭且等级卡即时更新、写入 localStorage、二次点击仍可打开、取消关闭、点昵称同样可开、空昵称拦截提示。测试用 `--host-resolver-rules` 把云函数域名指到 `127.0.0.1`，**全程零云端写入**。
- 产出对比图 `.workbuddy/avatar_edit_verify_2026-10-13.png`（左：带铅笔角标的「我的」页；右：点头像后弹出的编辑弹窗）。
- **遗留提示**：鸿蒙原型 `design/index.html`、Web 原型 `design/web.html`、鸿蒙端 `Me.ets` 目前仍是「点整卡」入口，未加头像角标——本轮按用户只提「小程序端」的范围未动，待确认是否同步。

---

## 三端统一：升级经验公式 + 徽章口径（2026-10-13 下午）

用户要求：**三端「升级所需经验」统一**；**Web 端徽章功能仿照鸿蒙端与小程序端改善**。

### 统一后的唯一口径（三端改动前先看这里）

- **升级所需经验**：`expForLevel(level) = 200 + (level - 1) * 100`。参数 = **当前等级**，返回 = **当前等级 → 下一级所需经验**（L1→L2 = 200，L7→L8 = 800，L10→L11 = 1100）。三处同式：鸿蒙 `Types.ets` / 小程序 `utils/state.js` / Web `store.js:nextLevelExp`。
- **旧档归一** `normalizeLevel()`：等级保留，`exp` 按进度百分比折算（`exp / oldNext * newNext`，仅在 `exp <= oldNext` 时折算），再 while 进位；**幂等**，可反复调用。
- **徽章四类进度与阈值**：b1 连续签到天数 `7/14/30/60`；b2 累计番茄**个数** `10/50/200/500`；b3 累计专注**分钟** `6000/12000/30000/60000`；b4 月度冠军**次数** `1/2/3/5`。阶段名统一 `未解锁/青铜/白银/黄金/钻石`，**解锁条件统一为「达到第一档」**，四枚徽章统一命名 `连续 7 天 / 番茄丰收 / 专注达人 / 月度冠军`。

### 各端改动

| 端 | 文件 | 改动 |
|---|---|---|
| 鸿蒙 | `model/Types.ets` | `expForLevel` 语义注释；新增 `gainExp(u,n)` 与 `normalizeLevel(u)` |
| 鸿蒙 | `model/AppState.ets` | 读档 / 云端同步后归一经验；`signInToday` 改用 `gainExp`；**新增 `static recalcBadges(): boolean`**（仅变化时落盘） |
| 鸿蒙 | `pages/Home.ets` / `pages/Focus.ets` | 修掉 `u.exp += 20` 后按 `expForLevel(level + 1)` 写门槛的 **off-by-one**（多算 100） |
| 鸿蒙 | `pages/Badges.ets` | 重算委托 `AppState.recalcBadges()`，消除两处口径漂移 |
| 鸿蒙 | `pages/Me.ets` | `syncUserState()` 增加 `AppState.recalcBadges()`；`ForEach` key 并入 `tier/unlocked`（原 key 只有 `b.id`，状态变化不重绘） |
| Web | `store.js` | 新增材质/阶段常量与 `badgeProgress/badgeValueText/badgePct/badgeList`；`getProfile()` 按公式**现算**并写回 `nextLevelExp` |
| Web | `app.js` | 新增 `badgeSection()`；`openBadgeCoin()` 重写为按材质绘制 3D 奖章（厚度带 + 径向渐变 + 阶段胶囊 + 下一等级预览 + 进度条），自动摆动改 `setInterval(33ms)` 并自清理 |
| Web | `app.css` | 徽章卡 / 五级材质令牌 / 弹窗阶段与进度条样式；**徽章改为一行 4 张等宽**（对齐鸿蒙 `Row(layoutWeight 1)`、小程序 `.badge-item{flex:1}`） |
| 小程序 | `utils/state.js` | 旧标尺（`3000` + `×1.5`）改统一公式 + `normalizeLevel` 归一；`addExp` 改 while 进位 |
| 小程序 | `pages/me/index.js` | `BADGE_CATALOG` 改统一口径；阶段名走 `BADGE_LEVEL_NAMES` |

### 验证

| 端 | 方式 | 结果 |
|---|---|---|
| Web | 同源 iframe 驱动真实页面（`_badge_test.html`） | **43/43 PASS**（经验公式、残留值校正、徽章进度/阶段/文案/进度条、卡片着色、3D 奖章材质冷暖与自动摆动、下一等级预览、未解锁态） |
| Web | 无头 Chrome CDP 播种后真实渲染截图 | 徽章 `黄金/白银/青铜/未解锁`、`已获得 3 / 4`、等级卡 `320 / 800` |
| 小程序 | `wx`/`Page` 桩驱动真实页面对象 | **ALL PASS** |
| 鸿蒙 | `assembleHap` 命令行构建 | **BUILD SUCCESSFUL**，产出 `entry-default-signed.hap`（仅剩既有弃用告警） |

验证图：`.workbuddy/web_badge_verify_2026-10-13.png`。

**遗留提示**：`cloudfunctions/studyRoomFunctions/data.js` 的 `saveProfile` 字段级合并**需重新部署云函数才生效**。

---

## 桌面卡片空白修复（2026-10-13 下午）

用户反馈：**鸿蒙端添加桌面卡片后，卡片只有空白、不显示内容。**

### 根因

**① 致命：`WidgetCard.ets` 在 `@Component struct` 里写了 `private get theme()`。**
ArkTS 编译器会**静默丢弃** struct 中的 `get`/`set` 访问器——生成的 `WidgetCard` 类里没有 `theme` 成员，
而 `initialRender()` 第一句就是 `Column.backgroundColor(this.theme.cardBg)`，
运行时 `this.theme` 为 `undefined` → 抛 `TypeError` → `initialRender()` 中断 → **整块卡片空白**。
全程 **BUILD SUCCESSFUL、零报错零告警**（官方口径：「ArkTS 自定义组件 struct 中不支持成员变量的 get/set 方法，
编译构建后不会生成对应逻辑，运行会报错」）。项目内**仅此一处**用了 getter，其余页面都写 `private t: ThemeDef = themeOf(...)`。
→ 修复：改为普通字段 `private theme: ThemeDef = themeOf('green');`。

**② 尺寸全错：`QfWidgetAbility.dimensionOf()` 在等字符串 `'2*2'`，而系统下发的是数字。**
key 为 `ohos.extra.param.key.form_dimension`，值是 `FormDimension` 枚举
（`Dimension_1_2=1 / 2_2=2 / 2_4=3 / 4_4=4`，SDK 注释即 `DIMENSION_KEY: FormDimension.Dimension_1_2`）；
`WidgetPicker.addToDesktop()` 经 `openFormManager` 传的同样是数字。
→ 数字永远匹配不上字符串分支，**永远回退 `'2*2'`**，2×4 / 4×4 卡片全按 2×2 布局渲染。
→ 修复：加 `typeof d === 'number'` 分支 + `dimNameOf(code)` 枚举映射，保留字符串容错。

**③ 载荷按尺寸少发 key**：原来只有 4×4 才下发 `min / streak / trees / progressPct`，
其余尺寸下卡片页对应的 `@LocalStorageProp` 只能退回声明处的默认值 `'0'`（假数据）。
→ 修复：改为**全量下发** 8 个 key。

**④ 刷新时尺寸缓存丢失**：`onUpdateForm(formId)` 不携带尺寸，且系统定时刷新（`updateDuration: 1`，每 30 分钟）
时 FormExtensionAbility 可能已被回收重建、内存 `dimMap` 为空 → 4×4 卡片半小时后悄悄变回 2×2。
→ 修复：改为「内存 Map → Preferences(`this.context`, `qf_widget_dims`) → 2*2」逐级回退，`onAddForm` 落盘、`onRemoveForm` 清理。

### 改动的文件

| 文件 | 改动 |
|---|---|
| `entry/src/main/ets/widget/pages/WidgetCard.ets` | `get theme()` → 普通字段 `private theme: ThemeDef = themeOf('green');`（附排查说明注释） |
| `entry/src/main/ets/widget/QfWidgetAbility.ets` | 尺寸改按 `FormDimension` 数字映射 + 字符串容错；载荷全量下发；`formId→尺寸` 用 Preferences 持久化；`onUpdateForm` 逐级回退 |

### 验证

- `assembleHap` → **BUILD SUCCESSFUL**，产出 `entry-default-signed.hap`。
- 新增自检脚本 **`.workbuddy/check_widget_card.js`**：扫描生成产物里所有 `this.X` 引用，
  比对「已声明成员 + ViewPU 继承成员」，专抓「声明了但被编译器静默丢弃」的成员；
  同时校验 `@Entry` 是否绑定 `new LocalStorage()`。
  结果：`undeclaredThisRefs: []`、8 个 `LocalStorageProp` key 齐全、`@Entry` 绑定正常 → **PASS**。
- **反向验证**（证明自检非空跑）：抹掉生成产物里的 `theme` 声明再跑 → 正确报出 `{"name":"theme","line":114}` ✅。
- 尺寸映射逐项核对 **10/10 PASS**（数字 2/3/4 → 2*2/2*4/4*4；1 → 回退；字符串 `'2*4'` 容错；缺参 → 2*2）。

### 用户需知

需重新安装 `entry-default-signed.hap`，并**把已添加的卡片删掉重新添加一次**——
旧卡片是在修复前的代码下创建的、尺寸没被记录，刷新时只能回退 2×2。

---

## 2026-10-13 · 桌面卡片形态改版（2×2 多邻国风 / 4×4 并入 2×4）

**需求**：① 2×2 卡片改成类似多邻国（Duolingo）小组件的样式；② 4×4 卡片缩小成 2×4，但内容一项都不能删。

**参照物**：多邻国的 streak 小组件只讲一件事 —— 一个突出的吉祥物（猫头鹰 Duo）+ 一个大号数字 + 一句状态文案，
且表情随打卡进度变化（鼓励 → 催促）。2×2 据此重做骨架，不再堆小指标。

### 改动的文件

| 文件 | 改动 |
|---|---|
| `resources/base/profile/form_config.json` | `supportDimensions`：`["2*2","2*4","4*4"]` → `["2*2","2*4"]`（4×4 下架）；`defaultDimension` 仍为 `2*2` |
| `widget/pages/WidgetCard.ets` | 2×2 → 多邻国式（吉祥物 emoji + 大数字 + 状态文案 + 细完成度条）；2×4 → 左右两栏，承接原 4×4 全部信息；`2*4/4*2/4*4` 统一走 `wideLayout()`（**4×4 分支刻意保留**，防桌面残留旧卡片掉进窄卡丢内容） |
| `widget/QfWidgetAbility.ets` | 仅更新注释（规格说明 + 为何保留 4×4 映射），逻辑未动 |
| `pages/WidgetPicker.ets` | `sizes` 去掉 4×4；2×2 / 2×4 预览与真实卡片对齐；新增 `todayMinutes/streakDays/moodEmoji/moodText`，**预览与卡片共用同一套判据** |

### 2×2 的多邻国式状态机

`moodEmoji()` / `moodText()` 随今日进度切换：`🌱 今天还没开始`（0）→ `🍅 继续加油`（进行中）→ `🎉 今日目标达成`（达标）。
同一套判据在 `WidgetCard.ets` 与 `WidgetPicker.ets` 各有一份，两边必须同步。

### 内容映射（原 4×4 → 新 2×4，一项未删）

`🌿 青番` / `xx 分钟` / `🌳 n 棵树`（左栏）＋ `🍅 done/goal` / `🔥 连签 天` / 完成度条 / `日期` / `查看待办 ›`（右栏）。
`date` 此前下发但无布局使用，本次落到右栏左下角 —— 8 个下发 key 现已全部有落点。

### 验证

- `assembleHap` → **BUILD SUCCESSFUL**，产出 `entry-default-signed.hap`。
- `node .workbuddy/check_widget_card.js <生成产物>`：`undeclaredThisRefs: []`；生成类成员含
  `theme / compactLayout / wideLayout / moodEmoji / moodText`；`@Entry` 绑定 LocalStorage 正常；8 个 `@LocalStorageProp` key 齐全。
- 打包核对：`intermediates/res/default/resources/base/profile/form_config.json` 的 `supportDimensions` 只剩 `2*2 / 2*4`。
- 预览图 `.workbuddy/card_preview_2026-10-13.png`：按 2 倍渲染真实 vp 比例（2×2 = 155×155、2×4 = 329×155），含 2×2 三种状态。

### 用户需知

重新安装 HAP，并**把桌面上原有的 4×4 卡片删掉**（该规格已下架；重新添加时只能选 2×2 / 2×4）。

---

## 卡片点击 → 直达「今日待办」

### 交互链路

整张卡片即按钮：根 `Stack.onClick` → `postCardAction(this, { action: 'router', abilityName: 'EntryAbility',
params: { qfPage: 'pages/Home' } })`（官方约束：`postCardAction` 只能在卡片控件的点击事件里调用）。

两条落地路径都在 `EntryAbility.ets`：

| 场景 | 生命周期 | 做法 |
|---|---|---|
| 应用未运行 | `onCreate` | 写 `AppStorage('qfLaunchTarget')` → `pages/Index` 首屏优先采用（读后即删） |
| 应用已在运行 | `onNewWant` | `getMainWindowSync().getUIContext().getRouter().pushUrl()`；`getState().path` 已是目标页则跳过 |

`launchPageOf()` 兼容「参数平铺在 `want.parameters` 顶层」与「收纳在 `want.parameters.params`（JSON 字符串 / 对象）」
两种形态，且只放行 `pages/` 前缀，避免外部传参越权跳转。宽卡右下角文案改为 `查看待办 ›`，与点击落点一致。

### 验证

- `.workbuddy/check_card_click.js` → **23/23 PASS**（参数解析 12 例 + 卡片页静态 5 项 + 跨文件常量 4 项 + 目标页注册 2 项）。
  参数解析是**从 `EntryAbility.ets` 源码正则抽取方法、剥类型注解后执行**，测的是源码本身。
- `assembleHap` → **BUILD SUCCESSFUL**；生成产物含 `openTodo` 成员与 `Stack.onClick(...)`；
  `check_widget_card.js` → `undeclaredThisRefs: []`。
- 预览图 `.workbuddy/card_click_preview_2026-10-13.png`。

### 用户需知

重新安装 `entry-default-signed.hap` 即可，**卡片无需删除重加**（点击行为属于卡片 UI，与尺寸记录无关）。

---

## 19:5x 应用图标：奶油底 + 扁平番茄（分层图标）

参照用户给的截图（奶油色圆角方 + 扁平番茄）重做应用图标。截图里图标区只有 44px，
直接放大必糊，所以是**逐像素测量后用 PIL 重绘**（不是抠图）。

### 几何与配色（`.workbuddy/make_app_icon.py`，可调 `CONTENT_H` / `N_BODY`）

| 元素 | 参数（参考图单位，图标方框 = 42） | 色值 |
|---|---|---|
| 主体 | 超椭圆 n=2.5，中心 (22.5, 25.5)，半径 (13.5, 10.5) | `#C9536C` |
| 高光 | 柔边椭圆，中心 (15.8, 21.0)，半径 (4.5, 2.6) | `#D66F86` |
| 茎 | 细叶，尖端 (22.5, 4.0) → 底 (22.5, 14.6)，半宽 1.55 | `#7BAD51` |
| 左 / 右叶 | 尖端 (11.2 / 33.8, 10.4) → 底 (21.6 / 23.4, 14.0)，半宽 1.35 | `#8EC05D` |
| 背景 | 实色铺满整张画布，不裁圆角、不加内边距 | `#EEE8D8` |

绘制顺序：叶 → 茎 → 主体 → 高光（叶茎根部被主体压住，接缝自然）。

### 产出文件

- `AppScope/resources/base/media/background.png` / `foreground.png` —— 应用图标（`app.json5`）
- `entry/src/main/resources/base/media/background.png` / `foreground.png` —— EntryAbility 图标（`module.json5`）
- `entry/src/main/resources/base/media/startIcon.png` —— 启动页图标（奶油圆角方 + 番茄，144×144）

前景内容占画布 **71.8%**（参考图为 76%，刻意收 6% 给「系统若缩放前景层」留余量，蒙版只取中央 2/3 也不裁到番茄）。
背景 alpha 最小值 255，符合「背景不得含透明像素」；原图标备份于 `.workbuddy/icon_backup_2026-10-13/`。

### 验证

- `assembleHap` → **BUILD SUCCESSFUL**；解包 HAP 复核：3 个 PNG + `layered_image.json` 均在，
  前景内容 bbox 占比 0.719、主色与设计一致。
- 构建期会将 `media` 下大图压缩到 512×512（1024→512），属平台正常行为，源文件仍保持规范要求的 1024。
- 预览图 `.workbuddy/app_icon_preview_2026-10-13.png`（合成 4 档尺寸 / 浅深壁纸 / 两层源文件 / 启动页图标 / 两种蒙版口径）。

### 踩坑记录

小图取形不能只看像素数值：44px 截图的边缘有 1~1.5px 抗锯齿，会把轮廓极值处的宽度撑大，
按逐行宽度硬算得到 n≈3.1（渲染出来像圆角矩形）；用**同尺度并排对比图**复核后改为 n=2.5 才与参考图一致。

### 用户需知

重新安装 `entry-default-signed.hap` 后，桌面图标即为新样式。

---

## 22:0x 图标修正：图形源改为 Web 端 `favicon.svg`

上面 19:5x 那版是「按截图用 PIL 逐像素重绘」。后来核对发现**那张截图就是 Web 端 logo 的模糊截图**：
把 `qingfan(web)/favicon.svg` 的番茄渲染到 44px 与截图逐行比对 —— 主体行范围、最大宽、各相对宽度序列完全一致。

于是 `.workbuddy/make_app_icon.py` 改为「无头 Chrome 栅格化 `favicon.svg` 的番茄（`viewBox="2 2 60 60"`）→
按 `CONTENT_H` / `CONTENT_CY` 摆到 1024 画布」，`N_BODY` 等自绘参数废弃。**三端 logo 从此同源**。

| 项 | 自绘版（作废） | 现在 |
|---|---|---|
| 背景 | `#EEE8D8` | `#EFE8D6` |
| 主体 / 高光 | `#C9536C` / `#D66F86` | `#D9486B` / `#EE7C98` |
| 叶 / 茎 | `#8EC05D` / `#7BAD51` | `#7FC24D` / `#6BAF42` |
| 前景占比 | 71.8% | 76.8% |

重新 `assembleHap` → **BUILD SUCCESSFUL**；解包 HAP 复核：`foreground.png` 512×512（内容高占 0.771）、
`background.png` 512×512（alpha 最低 254）、`startIcon.png` 144×144、`layered_image.json` 在位。

---

## 22:0x 原型与文档同步（三端「我的」页大改版）

代码侧「我的」页已从「森林 + 旧徽章」换成「番茄园 + b1-b4 稀有度徽章 + 3D 奖章」，
本轮把三端高保真原型与 `memory-bank` 文档补齐到与代码一致。

### 三端原型 `design/{index,web,miniprogram}.html`

| 项 | 改前 | 改后 |
|---|---|---|
| 我的森林 | 小树苗 / 青葱密林 / 古老森林 / 梦幻森林（按 5/15/30 棵） | **我的番茄园**：番茄幼苗 / 小番茄园 / 茂盛番茄园 / 番茄农场（按 10/50/150 棵）；🍅 网格；枯萎格角标 `×2`；提示「再收获 N 个番茄，升级到「X」」+「点击枯萎番茄消耗 2 个专注番茄清除」 |
| 徽章 | 4 张（连续 7 天 / 森林新芽 / 专注达人 / 月度冠军；`got` 布尔 + 整体 50% 透明） | **b1-b4 口径**（连续 7 天 / 番茄丰收 / 专注达人 / 月度冠军）+ **稀有度材质**（未解锁灰 / 青铜 / 白银 / 黄金 / 钻石）+ 阶段名胶囊 + 锁角标；标题栏加「已解锁 N / 4」 |
| 徽章详情 | 方形图标 + 「已获得 / 未解锁」 | **3D 奖章**：风车纹圆环 + 白色币心 + 中心图标，`@keyframes coinSwing` ±30°、3.5s 摆动；阶段名胶囊 + 升阶进度条 + 「再积累 N，升到「X」」 |
| 编辑资料 | 无字数提示 | 昵称 / 签名右上角**实时字数计数**（满格转番茄红），输入按码点截断（emoji 不被劈开） |
| 设置 | 账号 / 提醒 / 隐私 / 关于 | 加 **意见反馈**（textarea + 联系方式 + 提交按钮）；关于页加 **用户协议 / 隐私政策** 入口与新页；品牌语「种成一片森林」→「种成一片番茄园」 |

- 三端保持同构（仅外壳不同）：`index`=手机框、`web`=桌面浏览器框 + 左侧导航、`miniprogram`=微信小程序框。
- 顺带清掉原型里所有旧「森林 / 种树」文案（侧栏模块名、引导页标语、小组件标签、中断 toast、操作提示等），
  仅保留 **等级名「森林守护」** 与 **白噪音「森林」**（与代码一致）。
- **验证**：无头 Chrome 渲染三端「我的」页 + 3D 奖章弹窗，均正常（截图 `.workbuddy/proto_me_2026-10-13.png` / `proto_badge_2026-10-13.png`）。
- **踩坑**：批量脚本替换时 3D 奖章弹窗的收尾少写了一个 `}`（写成 `})()` 而非 `})()}`），
  导致 web / miniprogram 两端 Babel 编译失败、整页白屏（index 是手工改的，没问题）。
  用 `--enable-logging=stderr --v=1` 抓到 `Unexpected token, expected "}"` 后定位修复。

### 文档 `memory-bank/`

- `PRD.md`：FR-5 补等级公式 / 6 段称号 / 番茄园等级 / 徽章稀有度 / 编辑资料；FR-8 补整卡点击跳转；
  页面清单加 `About` / `Agreement` / `Feedback`；验收标准 5、8 修正；6.1 与 6.2 表格同步。
- `DESIGN.md`：组件规范新增「等级卡（仿小黑盒）/ 徽章墙 / 3D 奖章 / 番茄园 / 编辑资料弹窗」；
  「我的」页结构改为番茄园 + 徽章墙；小组件 2×4 描述里的「森林」改「番茄园」。
- `ARCHITECTURE.md`：分层补 `BadgeIcon` / `CoinBadge`；路由补三个新页与卡片点击两条落地链路；
  关键机制补 `tomatoStats()` / `expForLevel` / `recalcBadges`；组件职责表与 actions 列表更新。
- `DATA_MODEL.md`：`BadgeItem` 加 `iconKey` / `tier`、新增 `TomatoStats`；常量表补成长体系常量；
  存储 key 补 `qf_feedback_<userKey>`；action 表补 `data.*`（含 `saveProfile` 字段级合并）；云表补 `user_data_self`；校验规则「森林」改番茄园。
- `TASKS.md`：A7 / A8 / A10 / A11 / C4 措辞更新；新增 A17（等级经验公式统一）/ A18（徽章稀有度 + 3D 奖章）/ A19（关于 / 协议 / 反馈 + 编辑资料计数）。

