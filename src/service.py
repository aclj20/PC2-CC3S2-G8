#!/usr/bin/env python3
import os
import time
import threading
import logging
from flask import Flask, jsonify, Response, request

app = Flask(__name__)

# --- Configuración ---
PORT = int(os.getenv("PORT", "8080"))
BIND_ADDR = os.getenv("BIND_ADDR", "127.0.0.1")
LOG_PATH = os.getenv("LOG_PATH", "out/service.log")

# --- Logging básico ---
os.makedirs(os.path.dirname(LOG_PATH), exist_ok=True)
logging.basicConfig(
    filename=LOG_PATH,
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)

# --- Métricas internas ---
START_TIME = time.time()
_health_requests = 0
_total_requests = 0
_lock = threading.Lock()

def inc_health():
    global _health_requests
    with _lock:
        _health_requests += 1
        logging.info("/health called (%d total)", _health_requests)

def inc_total():
    global _total_requests
    with _lock:
        _total_requests += 1

def uptime_seconds():
    return max(0.0, time.time() - START_TIME)

@app.before_request
def before_request():
    inc_total()

@app.get("/health")
def health():
    try:
        inc_health()
        return jsonify(status="ok"), 200, {"Content-Type": "application/json"}
    except Exception as e:
        logging.exception("Error en /health: %s", e)
        return jsonify(status="error", message=str(e)), 500

@app.get("/metrics")
def metrics():
    try:
        lines = [
            f"process_uptime_seconds {uptime_seconds():.6f}",
            f'http_requests_total{{path="/health"}} {_health_requests}',
            f"http_requests_total {_total_requests}",
        ]
        body = "\n".join(lines) + "\n"
        return Response(body, status=200, mimetype="text/plain")
    except Exception as e:
        logging.exception("Error en /metrics: %s", e)
        return Response(f"# error: {e}\n", status=500, mimetype="text/plain")

@app.get("/", defaults={"path": ""})
@app.get("/<path:path>")
def not_found(path):
    return jsonify(error="not found"), 404, {"Content-Type": "application/json"}

if __name__ == "__main__":
    logging.info("Servicio iniciado en %s:%s", BIND_ADDR, PORT)
    app.run(host=BIND_ADDR, port=PORT, debug=False, use_reloader=False)
