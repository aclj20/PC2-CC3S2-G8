#!/usr/bin/env python3
import os
import time
import threading
from flask import Flask, jsonify, Response, request

app = Flask(__name__)

PORT = int(os.getenv("PORT", "8080")) 
BIND_ADDR = os.getenv("BIND_ADDR", "127.0.0.1")

START_TIME = time.time()
_health_requests = 0
_lock = threading.Lock()

def inc_health():
    global _health_requests
    with _lock:
        _health_requests += 1

def get_health_requests():
    with _lock:
        return _health_requests

def uptime_seconds():
    return max(0.0, time.time() - START_TIME)

@app.get("/health")
def health():
    inc_health()
    return jsonify(status="ok"), 200, {"Content-Type": "application/json"}

@app.get("/metrics")
def metrics():
    lines = []
    lines.append(f"process_uptime_seconds {uptime_seconds():.6f}")
    lines.append(f'http_requests_total{{path="/health"}} {get_health_requests()}')
    body = "\n".join(lines) + "\n"

    return Response(body, status=200, mimetype="text/plain")

@app.get("/", defaults={"path": ""})
@app.get("/<path:path>")
def not_found(path):
    return jsonify(error="not found"), 404, {"Content-Type": "application/json"}

if __name__ == "__main__":
    app.run(host=BIND_ADDR, port=PORT, debug=False, use_reloader=False)
