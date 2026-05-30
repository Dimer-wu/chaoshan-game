"""
潮汕奇遇记 — HTTP + WebSocket 服务端
HTTP :8080（静态文件）+ WebSocket :8081（实时通信）
"""
import asyncio
import json
import os
import time
from http import HTTPStatus
from pathlib import Path

try:
    from websockets.asyncio.server import serve
except ImportError:
    print("[!] 请安装 websockets: pip install websockets")
    import sys; sys.exit(1)

HTTP_PORT = int(os.environ.get("PORT", 8080))
WS_PORT = HTTP_PORT + 1  # 8081
ROOT = Path(__file__).resolve().parent.parent

MIME = {
    ".html": "text/html; charset=utf-8",
    ".js":   "application/javascript",
    ".css":  "text/css",
    ".json": "application/json",
    ".png":  "image/png",
    ".jpg":  "image/jpeg",
    ".jpeg": "image/jpeg",
    ".gif":  "image/gif",
    ".svg":  "image/svg+xml",
    ".ico":  "image/x-icon",
}

# ========== Game State ==========
connected = {}        # websocket → player_info
host_ws = None
active_round = -1
active_question = -1
current_answers = {}

def broadcast(msg):
    dead = []
    for ws in connected:
        try:
            asyncio.ensure_future(ws.send(msg))
        except Exception:
            dead.append(ws)
    for ws in dead:
        if ws in connected:
            del connected[ws]

async def notify_host(data):
    if host_ws and host_ws in connected:
        try:
            await host_ws.send(json.dumps(data, default=str))
        except Exception:
            pass

# ========== HTTP Server ==========
async def http_handler(reader, writer):
    """简易异步 HTTP 静态文件服务"""
    try:
        data = await asyncio.wait_for(reader.readuntil(b"\r\n\r\n"), timeout=10)
    except (asyncio.TimeoutError, ConnectionError):
        writer.close(); return

    request = data.decode("utf-8", errors="replace")
    lines = request.split("\r\n")
    if not lines:
        writer.close(); return

    method, path, *_ = lines[0].split(" ")
    path = (path or "/").split("?")[0]
    if path == "/":
        path = "/index.html"

    file_path = (ROOT / path.lstrip("/")).resolve()
    if not str(file_path).startswith(str(ROOT.resolve())):
        writer.write(b"HTTP/1.1 403 Forbidden\r\n\r\n"); writer.close(); return
    if not file_path.is_file():
        writer.write(b"HTTP/1.1 404 Not Found\r\n\r\n"); writer.close(); return

    ext = file_path.suffix.lower()
    content_type = MIME.get(ext, "application/octet-stream")

    body = file_path.read_bytes()

    if ext == ".html":
        cache = "Cache-Control: no-cache, no-store, must-revalidate\r\nPragma: no-cache\r\nExpires: 0\r\n"
    else:
        cache = "Cache-Control: public, max-age=3600\r\n"

    resp = (
        f"HTTP/1.1 200 OK\r\nContent-Type: {content_type}\r\n"
        f"{cache}Content-Length: {len(body)}\r\nConnection: close\r\n\r\n"
    ).encode("utf-8") + body

    writer.write(resp)
    await writer.drain()
    writer.close()

# ========== WebSocket Handler ==========
async def ws_handler(websocket):
    global host_ws, active_round, active_question, current_answers

    player_info = {"name": "unknown", "bus": "", "isHost": False}
    connected[websocket] = player_info

    try:
        async for raw in websocket:
            try:
                msg = json.loads(raw)
            except json.JSONDecodeError:
                continue

            msg_type = msg.get("type", "")
            if not msg_type:
                continue

            if msg_type == "register":
                player_info["name"] = msg.get("name", "unknown")
                player_info["bus"] = msg.get("bus", "")
                player_info["isHost"] = msg.get("isHost", False)
                connected[websocket] = player_info
                print(f"[+] {player_info['name']} ({player_info['bus']}) (在线:{len(connected)})")

                if player_info["isHost"]:
                    host_ws = websocket
                    print("[HOST] 主持人已上线")

                broadcast(json.dumps({"type": "players_update", "online": len(connected)}))

            elif msg_type == "host_select_round":
                if not player_info.get("isHost"): continue
                active_round = msg.get("round", -1)
                active_question = -1
                current_answers = {}
                print(f"[HOST] 选择回合 {active_round}")
                broadcast(json.dumps({"type": "round_selected", "round": active_round}))

            elif msg_type == "host_push_question":
                if not player_info.get("isHost"): continue
                r, q = msg.get("round", active_round), msg.get("question", 0)
                active_round, active_question = r, q
                current_answers = {}
                print(f"[HOST] 推送题目 round={r} q={q}")
                broadcast(json.dumps({"type": "question", "round": r, "question": q}))

            elif msg_type == "player_answer":
                current_answers[player_info["name"]] = {
                    "answer": msg.get("answer", -1),
                    "correct": msg.get("correct", False),
                }
                total = max(len(connected) - (1 if host_ws else 0), 1)
                answered = len(current_answers)
                correct_n = sum(1 for a in current_answers.values() if a["correct"])
                await notify_host({
                    "type": "answers_update",
                    "answered": answered,
                    "online": total,
                    "total": total,
                    "correctRate": round(correct_n / max(answered, 1) * 100)
                })

    except Exception as e:
        print(f"[!] {player_info.get('name','?')}: {e}")
    finally:
        if websocket in connected:
            del connected[websocket]
        if websocket == host_ws:
            host_ws = None
            print("[HOST] 主持人已离线")
        print(f"[-] {player_info.get('name','?')} 断开 (在线:{len(connected)})")
        broadcast(json.dumps({"type": "players_update", "online": len(connected)}))

# ========== Main ==========
async def main():
    print("=" * 48)
    print("  潮汕奇遇记 — 服务端启动")
    print(f"  HTTP       :{HTTP_PORT} (静态文件)")
    print(f"  WebSocket  :{WS_PORT} (实时通信)")
    print("  按 Ctrl+C 停止")
    print("=" * 48)
    print()

    http_server = await asyncio.start_server(http_handler, "0.0.0.0", HTTP_PORT)

    async with serve(ws_handler, "0.0.0.0", WS_PORT) as ws_server:
        await asyncio.gather(http_server.serve_forever(), ws_server.serve_forever())

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n服务已停止")
