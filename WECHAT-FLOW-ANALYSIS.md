# 微信扫码使用流程分析

> 目标：确保 98 名团建参与者能通过微信扫码顺畅进入游戏

---

## 用户旅程（当前设计）

```
组织者PC                    参与者手机(微信)
─────────                   ────────────────
1. 运行 start-public.bat
2. HTTP服务 :8080 启动
3. SSH隧道 → localhost.run
   获得 URL: https://xxx.lhr.life
4. 生成 qrcode-public.png
5. 发二维码到微信群 ──────────→ 6. 微信内长按扫码
                                7. 微信内置浏览器打开URL
                                8. 加载 index.html
                                9. 输入姓名、选大巴
                                10. 进入游戏
```

---

## 发现的问题

### P0 — 阻断性问题

| # | 问题 | 影响 | 修复 |
|---|------|------|------|
| 1 | **Python `qrcode` 包未安装** | `start-public.bat` 运行时导入失败，QR码不生成，用户无码可扫 | `pip install qrcode Pillow` |
| 2 | **局域网版也未生成 QR 码** | `start-server.bat` 提示语提到 `qrcode-local.png` 但脚本中无生成逻辑 | 补全局域网 QR 码生成 |

### P1 — 高风险问题

| # | 问题 | 影响 |
|---|------|------|
| 3 | **SSH 隧道断开后 URL 会变** | `localhost.run` 重连后分配新子域名，旧 QR 码失效，需重新分发 |
| 4 | **localhost.run 在国内不稳定** | SSH 出境连接可能被干扰，隧道频繁断开 |
| 5 | **QR 码分发是手动的** | 组织者需截图/发送文件到微信群，多一步操作 |

### P2 — 体验问题

| # | 问题 | 影响 |
|---|------|------|
| 6 | **微信内置浏览器兼容性检测不完整** | 代码检测到微信 UA 但只 `console.log`，未做微信特化处理 |
| 7 | **微信缓存策略** | 微信内置浏览器可能缓存旧版 HTML，修复 Bug 后参与者可能仍用旧版 |
| 8 | **无备用访问方案** | 如果 localhost.run 完全不可用，没有备选公网方案 |

---

## 微信内置浏览器兼容性矩阵

| 功能 | iOS 微信 (WKWebView) | Android 微信 (X5) | 评估 |
|------|---------------------|-------------------|------|
| CSS Grid (Bingo 5×5) | ✅ iOS 12+ | ✅ Android 7+ | 通过（有 compat check） |
| localStorage | ✅ | ✅ (5MB) | 通过（图片存 base64 有溢出风险） |
| FileReader + Camera | ✅ | ✅ | 通过（`capture="environment"`） |
| Canvas (照片压缩) | ✅ | ✅ | 通过（有 compat check） |
| Fetch API | ✅ | ✅ | 通过 |
| WebSocket | ✅ | 部分版本有 Bug | 当前无服务端，不影响 |
| `storage` 事件（跨标签页） | ❌ 微信单标签页 | ❌ 微信单标签页 | **主持人推送依赖此功能，在微信中完全不可用** |
| `-webkit-fill-available` | ✅ | N/A | 已处理（line 425） |
| iOS 输入框缩放 | ⚠️ | N/A | 已处理 `font-size:16px!important`（line 426） |

---

## 关键发现：主持人推送在微信中完全不可用

当前"主持控制台"推送题目的机制依赖 `window.addEventListener('storage', ...)`，该事件只在**同一浏览器不同标签页间**触发。

**在微信中**：微信内置浏览器是单标签页的，`storage` 事件永远收不到。这意味着：
- 主持人在 PC 推送题目 → 参与者手机微信**收不到**
- WebSocket 服务端也未实现 → 实际无法跨设备同步

**这导致"大巴抢答赛"的核心功能（主持人推送题目到全员）在当前架构下无法工作。**

---

## 建议修复方案

### 立即修复（P0）

```
1. pip install qrcode Pillow
2. 补全 start-server.bat 的局域网 QR 码生成
```

### 短期修复（P1 — 活动前）

```
3. 实现 WebSocket 服务端 (替换 storage 事件)
4. 添加缓存破坏参数 (?v=timestamp) 防微信缓存
5. 准备备选方案：GitHub Pages 作为静态托管 + Cloudflare Tunnel
```

### 活动前验证清单

- [ ] 在多种安卓手机微信中实测扫码 → 载入 → 拍照上传
- [ ] 在 iPhone 微信中实测（iOS 12/13/14/15+）
- [ ] 实测 localhost.run 隧道稳定性和重连速度
- [ ] 准备纸质打印二维码作为终极备份
