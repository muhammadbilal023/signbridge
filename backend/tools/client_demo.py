"""Tiny command-line client: logs in and streams fake hand frames to /ws/sign.
    python tools/client_demo.py http://localhost:8000 me@example.com password123
Needs: pip install websockets httpx"""
import asyncio
import json
import sys

import httpx
import websockets


async def main(base: str, email: str, password: str):
    r = httpx.post(f"{base}/auth/login", json={"email": email, "password": password})
    if r.status_code == 401:
        r = httpx.post(f"{base}/auth/register", json={"full_name": "Demo User", "email": email, "password": password})
    token = r.json()["access_token"]
    async with websockets.connect(base.replace("http", "ws") + f"/ws/sign?token={token}&lang=en") as ws:
        print(await ws.recv())
        t = 0
        for _word in range(2):                       # two "signs"
            for _ in range(12):                      # 12 frames with a hand
                t += 66
                await ws.send(json.dumps({"type": "landmarks", "data": [0.5] * 126, "t": t}))
            for _ in range(10):                      # pause (no hand)
                t += 100
                await ws.send(json.dumps({"type": "landmarks", "data": [0.0] * 126, "t": t}))
        await ws.send(json.dumps({"type": "finish"}))
        for _ in range(4):
            try:
                print(await asyncio.wait_for(ws.recv(), 2))
            except asyncio.TimeoutError:
                break


if __name__ == "__main__":
    asyncio.run(main(*sys.argv[1:4]))
