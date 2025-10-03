#!/usr/bin/env python3
import os
from flask import Flask, jsonify, Response

app = Flask(__name__)

PORT = int(os.getenv("PORT", "18080"))
BIND_ADDR = os.getenv("BIND_ADDR", "127.0.0.1")

@app.get("/health")
def health():
    return jsonify(status="dummy", uptime="0s"), 200, {"Content-Type": "application/json"}

@app.get("/metrics")
def metrics():
    body = "requests_total 0\nlatency_ms_p50 0\n"
    return Response(body, status=200, mimetype="text/plain")

@app.get("/", defaults={"path": ""})
@app.get("/<path:path>")
def not_found(path):
    return jsonify(error="not found"), 404, {"Content-Type": "application/json"}

if __name__ == "__main__":
    app.run(host=BIND_ADDR, port=PORT, debug=False, use_reloader=False)
