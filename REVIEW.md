# 潮汕奇遇记 — 代码审查报告

> 审查日期：2026-05-29 | 审查范围：`index.html`（1997 行）

---

## 一、项目结构问题

### 1.1 单文件巨石架构
**现状**：全部 CSS + HTML + JS（~2000 行）混在一个 `index.html` 中。
**风险**：
- 无法单独定位样式/逻辑问题
- 多人协作冲突概率高
- 没有模块边界，新增功能容易引入回归

**建议拆分**：
```
chaoshan-game/
├── index.html           # 仅 HTML 结构（~250 行）
├── css/
│   └── style.css        # 全部样式（~250 行）
├── js/
│   ├── data.js          # 题目/任务/Bingo/玩家数据（~200 行）
│   ├── state.js         # 全局状态 + localStorage 管理
│   ├── quiz.js          # 抢答模块
│   ├── missions.js      # 打卡模块
│   ├── bingo.js         # Bingo 模块
│   ├── leaderboard.js   # 排行榜
│   ├── host.js          # 主持控制台
│   └── app.js           # 入口/路由/WebSocket/兼容性检测
├── server/
│   └── server.py        # Python WebSocket + HTTP 服务端
└── data/
    └── players.json     # 玩家名单（外部化）
```

### 1.2 缺少服务端
- WebSocket 客户端已写（line 1893-1934），但没有对应的服务端实现
- 排行榜、主持人推送等功能实际上依赖 localStorage 跨标签页同步，无法跨设备工作
- 主持人面板的统计（line 1767-1774）使用 `Math.random()` 模拟数据，上线后无效

### 1.3 玩家名单硬编码
- 98 人姓名、座位号硬编码在 `EMBEDDED_PLAYERS`（line 697-796）
- 修改名单需要编辑 HTML 源码，对非技术人员不友好
- 个人隐私数据暴露在源码中

---

## 二、确认 BUG 清单

### BUG-1 (P0) `getAllPlayerScores()` 重复 const 声明 → SyntaxError
**位置**：`index.html:1109-1110`
```js
const missionS = JSON.parse(...);  // line 1109
const missionS = JSON.parse(...);  // line 1110 ← 重复声明！
```
`const` 不允许在同一块级作用域中重复声明，这是 **SyntaxError**，会导致整个 `<script>` 解析失败，所有 JS 功能瘫痪。当前如有正常工作的版本，可能该函数路径尚未被触发（活动门控下排行榜不渲染）。**这是最严重的 BUG，必须最先修复。**

### BUG-2 (P0) Quiz 回合索引双重递增 → 回合跳过
**位置**：`index.html:1283` + `:1173`
- `quizNextQuestion()` 在回合结束时执行 `currentRoundIdx++`（line 1283）
- `continueNextRound()` 被调用时再次 `currentRoundIdx++`（line 1173）
- **后果**：每完成一个回合就跳过一个回合，"第二回合"等内容永远不可达。

### BUG-3 (P0) 主持推送题目被 `startQuiz()` 重置
**位置**：`index.html:1793-1803`
- `handleHostQuestion()` 设置 `quizRounds`/`currentQIdx` 为特定题目后调用 `navTo('quiz')`
- `navTo('quiz')` → `startQuiz()` 立即将上述状态全部重置为默认值
- **后果**：WebSocket/跨设备推送功能完全失效，玩家永远看到第一题而非主持人推送的题目。

### BUG-4 (P1) CSS 选择器缺失 → `.question-box` 无样式
**位置**：`index.html:167-169`
孤立 CSS 属性块（缺少 `.question-box` 选择器），导致题目卡片无白色背景、圆角、阴影。

### BUG-5 (P1) `playerData` 未声明 → 隐式全局变量
**位置**：`index.html:956, 959, 961`
`init()` 中 `playerData = ...` 未用 `let`/`var`/`const` 声明，污染全局命名空间，若加 `"use strict"` 将报 `ReferenceError`。

---

## 三、代码质量问题

### 3.1 `getTeamScores()` 性能问题（严重）
```js
// line 1118-1129
function getTeamScores() {
  const map = {};
  playerData.forEach(p => {
    const scores = getAllPlayerScores();  // ← 每个玩家重算一次！
    const s = scores.find(x => x.name === p.name);
    ...
  });
}
```
`getAllPlayerScores()` 遍历 98 人并读取每个玩家的 localStorage，`getTeamScores()` 又对每个玩家调用一次，复杂度 O(n²)。每次首页渲染都会执行。

**修复**：缓存 `getAllPlayerScores()` 结果，或使用单次遍历。

### 2.2 隐式全局变量
```js
// line 957
let playerData = EMBEDDED_PLAYERS;  // 在 init() 中声明，line 1107 等处直接使用
```
`playerData` 在 `init()` 中用 `let` 声明，但 `getAllPlayerScores()`、`getTeamScores()` 等函数直接引用它。由于 `init()` 先于其他函数执行且 `let` 在函数作用域中存在变量提升的误用风险，当前仅在 `init()` 未失败时有效。如果 `init()` 中 `fetch` 异常导致提前返回，`playerData` 会是 `undefined`。

**修复**：在顶层显式声明 `var playerData = EMBEDDED_PLAYERS;`

### 2.3 重复变量声明（BUG）
```js
// line 1108-1110
const missionS = JSON.parse(localStorage.getItem(getScoreKey('mission_score_' + p.name)) || '0');
const missionS = JSON.parse(localStorage.getItem(getScoreKey('mission_score_' + p.name)) || '0');  // 重复！
```
第二行是重复语句，虽然不会导致报错（`const` 重复声明会抛出 `SyntaxError`），但这段代码实际上在函数体内，如果浏览器严格模式下会报错。

等等，让我重新确认：这段代码在 `getAllPlayerScores()` 的 map 回调中。在非严格模式下，`const` 重复声明应该会报 SyntaxError…但实际上要看浏览器实现。无论如何这是一个明显的 BUG。

### 2.4 BUG：CSS 缺少选择器（line 167-169）
```css
/* line 160-166: .countdown-banner 正常 */
.countdown-banner { ... }

/* line 167-169: 这些规则没有选择器！ */
  background:var(--white); border-radius:var(--radius); padding:24px 20px;
  box-shadow:var(--shadow); text-align:center; margin-bottom:16px;
}
```
从上下文推断，这应该是 `.question-box` 的样式，但由于选择器丢失，这些规则被当作无效 CSS 丢弃，导致题目卡片的样式缺失。

### 2.5 CSS 关键帧动画语法（line 165）
```css
@keyframes pulse { 0%,100%{opacity:1} 50%{opacity:0.75} }
```
应该使用完整的百分比选择器写法。虽然多数浏览器能容错，但严格的 CSS 解析器可能拒绝此写法。建议改为：
```css
@keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.75; } }
```

---

## 三、数据与存储问题

### 3.1 localStorage 容量溢出风险（严重）
照片以 base64 存储在 localStorage 中。localStorage 通常限制 5-10MB：
- 一张压缩后的照片约 50-100KB base64
- 98 人 × 13 个打卡任务 + 24 个 Bingo 格子 ≈ 每人可上传约 37 张照片
- 理论最大使用量远超 5MB 限制

**修复**：使用 IndexedDB 存储图片（无限容量），localStorage 仅存元数据。

### 3.2 测试/正式数据不隔离（中等）
活动前数据用 `test_` 前缀 key，活动开始后自动切换正式 key。但：
- 测试数据不会自动迁移到正式 key
- 活动开始后用户之前测试的数据"丢失"
- 没有手动切换/清除机制

### 3.3 同一设备多玩家问题
localStorage 是设备级别，如果多人共用一台手机（虽然有手机的人基本不会共用），后者登录会看到前者的数据。

---

## 四、业务逻辑问题

### 4.1 Bingo 连线取消不扣分
`checkBingoLines()` 只检测新增连线，不会移除已断开的连线：
```js
// line 1586
if (newLines.size > bingoLines.size) {
  // 只处理新增
}
```
如果用户取消一个 Bingo 格子导致连线断开，`bingoLines` 不会更新，积分不会减少。

### 4.2 打卡任务无审核机制
- 任务拍照后直接加分，无投票/审核流程（虽然有"全员投票"的 UI 文案）
- 用户可以上传任意照片完成任务

### 4.3 主持人推送在同一设备无效
```js
// line 1777
window.addEventListener('storage', function(e) {
  // storage 事件不会在触发 setItem 的同一页面触发
});
```
`storage` 事件只在**其他**标签页触发，主持人自己的设备收不到推送。这在"主持人在大屏推送，自己手机答题"的场景下会出问题——主持人需要两个不同浏览器窗口。

### 4.4 排行榜团队分计算方式
```js
// line 1120-1128
playerData.forEach(p => {
  const scores = getAllPlayerScores(); // 每次 forEach 都重算！
});
```
除了性能问题，团队人均分计算可能不符合预期：如果某队有更多人参与游戏（更多人有 local 数据），分母 `count` 会变大，拉低人均。

---

## 五、安全问题

### 5.1 XSS 风险（中等）
多处使用 innerHTML 直接拼接用户输入：
```js
// line 1053-1054
document.getElementById('greeting-text').innerHTML =
  `你好，<b>${currentPlayer.name}</b>！...`;
```
虽然 `currentPlayer.name` 来自 `EMBEDDED_PLAYERS` 或 input 的 `maxlength="10"` 限制，但没有 HTML 转义。如果手动修改 HTML 中的玩家名注入 `<script>` 标签，可触发 XSS。

### 5.2 base64 图片无校验
上传的图片没有类型/大小校验，可上传任意文件转 base64 存入 localStorage。

---

## 六、优化建议汇总

| 优先级 | 类别 | 问题 | 建议 |
|--------|------|------|------|
| P0 | BUG | CSS 缺少 `.question-box` 选择器 | 补全选择器 |
| P0 | BUG | `getAllPlayerScores()` 重复变量声明 | 删除重复行 |
| P0 | 存储 | localStorage 容量溢出 | IndexedDB 存储图片 |
| P1 | 数据 | `playerData` 隐式全局变量 | 顶层显式声明 |
| P1 | 性能 | `getTeamScores()` O(n²) | 缓存结果 |
| P1 | 逻辑 | Bingo 取消不清除连线 | 修复 `checkBingoLines` |
| P1 | 架构 | 无服务端，多设备无法同步 | 实现 WebSocket 服务端 |
| P2 | 架构 | 单文件巨石 | 按模块拆分 CSS/JS/HTML |
| P2 | 数据 | 测试/正式数据隔离 | 添加数据迁移机制 |
| P2 | 安全 | innerHTML XSS | 使用 textContent 或转义 |
| P3 | 安全 | 图片无校验 | 添加类型/大小校验 |
| P3 | 体验 | 打卡无审核 | 添加投票或至少时间戳 |
