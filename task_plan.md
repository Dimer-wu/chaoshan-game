# Task: 潮汕奇遇记 工程化改造

## Status: In Progress

## 阶段一：紧急 BUG 修复（P0 — 阻塞性问题）

- [ ] **Step 1: 修复 `const missionS` 重复声明** (index.html:1109-1110)
  - 删除重复行，合并为单一声明。**这是 SyntaxError，JS 无法执行。**
- [ ] **Step 2: 修复 Quiz 回合双重递增** (index.html:1173 + :1283)
  - `quizNextQuestion()` 改为 `showRoundComplete()`，不在内部递增 `currentRoundIdx`
  - 仅在 `continueNextRound()` 中递增一次
- [ ] **Step 3: 修复主持推送被 startQuiz 重置** (index.html:1793-1803)
  - `handleHostQuestion()` 在 `startQuiz()` 之后恢复推送指定的状态
  - 或在 `navTo` 中跳过 quiz 的自动 `startQuiz()` 当有主持人推送 active

## 阶段二：代码拆分（工程化核心）

- [ ] **Step 4: 拆分 HTML/CSS/JS** ← CURRENT
  - `index.html` — 仅 HTML 结构（~250 行）
  - `css/style.css` — 全部样式（~250 行）
  - `js/data.js` — 题目/任务/Bingo/玩家数据（~200 行）
  - `js/state.js` — 全局状态 + localStorage 管理
  - `js/quiz.js` — 抢答模块
  - `js/missions.js` — 打卡模块
  - `js/bingo.js` — Bingo 模块
  - `js/leaderboard.js` — 排行榜
  - `js/host.js` — 主持控制台
  - `js/app.js` — 入口/路由/WebSocket/兼容性

- [ ] **Step 5: CSS 修复 + 优化**
  - 补全 `.question-box` 选择器
  - 统一 CSS 变量体系
  - 移除冗余样式

- [ ] **Step 6: JS 模块化**
  - 修复 `playerData` 全局变量（显式 `var` 声明）
  - 抽取 localStorage 工具函数（get/set/remove 统一接口）
  - 添加 try-catch 包裹所有 JSON.parse

## 阶段三：数据层改造

- [ ] **Step 7: 图片迁移到 IndexedDB**
  - 所有照片从 localStorage base64 → IndexedDB
  - localStorage 仅存元数据指针
  - 解决 5MB 容量瓶颈

- [ ] **Step 8: 玩家名单外部化**
  - `EMBEDDED_PLAYERS` → `data/players.json`
  - init() 加载逻辑保留 fallback

- [ ] **Step 9: 数据修复工具**
  - 测试/正式数据迁移
  - 清理工具（清除单玩家/全部数据）

## 阶段四：服务端实现

- [ ] **Step 10: Python WebSocket 服务端**
  - 主持人推送题目 → 全员广播
  - 实时答题结果收集
  - 排行榜实时更新
  - 替换 `hostSimAnswers` 中的 Math.random()

- [ ] **Step 11: 服务端持久化**
  - SQLite 存储玩家分数
  - 支持导出/备份

## 阶段五：质量与安全

- [ ] **Step 12: XSS 修复**
  - 所有 innerHTML 拼接用户输入处 → textContent 或 HTML 转义

- [ ] **Step 13: Bingo 连线取消扣分修复**
  - `checkBingoLines()` 改为完全重算，而非仅检测新增

- [ ] **Step 14: 图片上传校验**
  - 类型限制（仅 image/*）
  - 大小限制（压缩前 ≤ 10MB）

## Key Files

| 文件 | 操作 | 说明 |
|------|------|------|
| `index.html` | 重写 | 拆分后仅剩 HTML 结构 |
| `css/style.css` | 新建 | CSS 变量 + 移动端样式 |
| `js/data.js` | 新建 | 题库/任务/Bingo/玩家数据 |
| `js/state.js` | 新建 | 状态管理 + localStorage 抽象 |
| `js/quiz.js` | 新建 | 抢答模块 |
| `js/missions.js` | 新建 | 打卡模块 |
| `js/bingo.js` | 新建 | Bingo 模块 |
| `js/leaderboard.js` | 新建 | 排行榜 |
| `js/host.js` | 新建 | 主持控制台 |
| `js/app.js` | 新建 | 入口/路由/WebSocket |
| `server/server.py` | 新建 | WebSocket 服务端 |
| `data/players.json` | 新建 | 外部化玩家名单 |

## Decisions Made

1. **不引入构建工具** — 保持纯静态，零依赖，符合无网络部署场景
2. **模块化用 IIFE + 全局命名空间** — 不使用 ES modules（需要服务器且兼容性差）
3. **服务端用 Python** — 与现有 `start-server.bat` 一致
4. **IndexedDB 优于 localStorage** — 图片存储无容量限制

## Blockers

- 无
