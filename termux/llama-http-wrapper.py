#!/usr/bin/env python3
"""
简单的 HTTP wrapper，包装 llama-batched 提供 /v1/chat/completions 接口
作为 llama-server 在 ARM/Termux 上 segfault 的临时替代方案
"""
import subprocess
import json
import sys
import os
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse

LLAMA_BATCHED = os.path.expanduser("~/llama.cpp/build/bin/llama-batched")
MODEL_PATH = os.path.expanduser("~/cuoti/models/qwen2.5-3b-instruct-q4_k_m.gguf")

class LlamaHandler(BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET,POST,OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type,Authorization')
        self.end_headers()

    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(b'{"status":"ok"}')
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        if self.path != '/v1/chat/completions':
            self.send_response(404)
            self.end_headers()
            return

        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length).decode('utf-8')
        try:
            req = json.loads(body)
        except:
            self.send_response(400)
            self.end_headers()
            return

        messages = req.get('messages', [])
        max_tokens = req.get('max_tokens', 512)
        temperature = req.get('temperature', 0.7)

        # 构建 prompt
        prompt = ""
        for msg in messages:
            role = msg.get('role', 'user')
            content = msg.get('content', '')
            if role == 'system':
                prompt += f"<<SYS>>\n{content}\n<</SYS>>\n\n"
            elif role == 'user':
                prompt += f"{content}\n\n"
            elif role == 'assistant':
                prompt += f"{content}\n\n"

        # 调用 llama-batched
        cmd = [
            os.path.expanduser("~/llama.cpp/build/bin/llama-batched"),
            "-m", MODEL_PATH,
            "-p", prompt.strip(),
            "-n", str(max_tokens),
            "-t", "4",
            "--temp", str(temperature),
        ]

        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
            # 提取生成的文本（去掉 prompt 部分）
            output = result.stdout
            if prompt.strip() in output:
                generated = output.split(prompt.strip())[-1].strip()
            else:
                generated = output.strip()

            response = {
                "id": "chatcmpl-1",
                "object": "chat.completion",
                "created": int(__import__('time').time()),
                "model": "qwen2.5-3b-instruct",
                "choices": [{
                    "index": 0,
                    "message": {"role": "assistant", "content": generated},
                    "finish_reason": "stop"
                }],
                "usage": {"prompt_tokens": len(prompt.split()), "completion_tokens": len(generated.split()), "total_tokens": len(prompt.split()) + len(generated.split())}
            }

            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps(response).encode())

        except subprocess.TimeoutExpired:
            self.send_response(504)
            self.end_headers()
        except Exception as e:
            self.send_response(500)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"error": str(e)}).encode())

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', 8080), LlamaHandler)
    print("Starting llama-batched HTTP wrapper on port 8080...")
    server.serve_forever()
