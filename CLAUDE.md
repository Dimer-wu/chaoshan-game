# chaoshan-game — 潮汕奇遇记

TCL 云锋科技园汕头 & 南澳岛 3 天 2 夜团建互动游戏。纯前端单文件移动端 Web 应用，98 名玩家 + 主持人模式，通过拍照打卡、抢答、Bingo 互动获取积分。

## 技术栈

- 纯静态 HTML/CSS/JS（单文件 ~2000 行）
- 数据存储：localStorage（按玩家名分 key，base64 图片）
- 部署：Python HTTP Server（`:8080`）+ 可选的 SSH 隧道（localhost.run）
- 多设备同步：localStorage `storage` 事件（同源）+ WebSocket（预留，无服务端）
- GitHub Pages：已启用

## 部署方式

| 方式 | 脚本 | 说明 |
|------|------|------|
| 局域网 | `start-server.bat` | Python HTTP Server，端口 8080，手机连同一 WiFi |
| 公网 | `start-public.bat` | SSH 反向隧道到 localhost.run，自动生成 QR 码 |
| 静态 | `index.html` | 直接打开或部署到任意静态服务器 |

## 功能模块

```
登录 → 首页（积分/排名概览）
       ├── ⚡ 大巴抢答赛（5 回合 × 8 题，10 秒倒计时，答对 +10+速度奖励）
       ├── 📸 打卡密令（Day1/2/3 每日拍照任务，完成加分）
       ├── 🎯 旅程 Bingo（5×5 格子，拍照证明，连线 +50 分）
       ├── 🏆 排行榜（个人榜 / 团队人均榜）
       ├── 📖 使用指南（规则说明 + 兼容性检测）
       └── 🎤 主持控制台（主持人选回合推送题目，HOST 身份）
```

## 活动时间门控

- `EVENT_START = 2026-06-12T08:00:00+08:00`
- 活动开始前：积分榜隐藏，显示倒计时，数据写 `test_` 前缀 key
- 活动开始后：自动切换正式模式（`isEventActive()` 判断）

## 关键数据结构

- `EMBEDDED_PLAYERS`：98 人名单（含姓名、大巴、座位、桌号、队伍）
- `quizData[5]`：5 回合 × 8 道选择题（潮汕美食/冷知识/趣味/公司专场/潮汕通）
- `missionsData{1,2,3}`：3 天拍照打卡任务
- `bingoData[25]`：5×5 Bingo 格子（index 12 = FREE）
- localStorage key 约定：`{prefix}quiz_score_{name}`, `{prefix}mission_score_{name}`, `{prefix}bingo_checked`, `{prefix}bingo_lines`, `{prefix}mission_photos_{name}`, `{prefix}bingo_photos_{name}`

## 工程约束

- 不主动启动服务（`start-server.bat` / `start-public.bat` 需用户手动执行）
- 中国大陆网络环境，CDN 不可用（项目无外部依赖）
- 玩家数据嵌入在 HTML 中，修改名单需直接编辑 `EMBEDDED_PLAYERS` 数组
- 活动日期 2026-06-12，此日期前处于测试模式
