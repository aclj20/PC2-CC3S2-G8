# Bitácora — Sprint 3

### 1) Objetivos
- Refactor de pruebas: limpieza, nombres claros, helpers reutilizables.
- Añadir test de **idempotencia**: dos corridas seguidas sin “trabajo extra” (payload estable; contador de métricas aumenta solo lo esperado).
- Mantener AAA/RGR y evidencias legibles.
- Mejorar escritura de logs en el servicio Flask.

### 2) Cambios principales
-`src/service.py`
  - **Logging** a `out/service.log` (configurable con `LOG_PATH`).
  - **Nueva métrica global** `http_requests_total` (todas las requests) además de `http_requests_total{path="/health"}`.
  - **Hook** `@before_request` para contar cada request entrante.
  - **Concurrencia**: contadores protegidos con `threading.Lock`.
  - **Robustez**: manejo de errores con `try/except` en `/health` y `/metrics`, con `logging.exception`.
  - **Sin cambios de contrato**: `/health` sigue respondiendo `{"status":"ok"}` y `/metrics` mantiene `process_uptime_seconds` y el contador de `/health`.


- `tests/health_metrics.bats`:
  - Helpers: `curl_json`, `curl_plain`, `metric_value`, `normalize_health_body`, `save_evidence`.
  - Positivos: `/health` (200/json/ok/latencia), `/metrics` (text/plain + mínimas).
  - Negativos estables: estructura inválida en `/metrics`, `status` incorrecto en `/health`, detector de latencia.
  - **Nuevo**: test `idempotencia-health-2x`.

### 3) Idempotencia
- **Payload**: se enmascara el campo volátil `"time"` y se comparan hashes SHA-256 de los cuerpos normalizados en dos llamadas consecutivas a `/health`.
- **Métrica**: se lee `http_requests_total{path="/health"}` antes y después; se exige `delta == 2`.

### 4) Evidencias
Tras ejecutar:
```bash
bats tests/health_metrics.bats
```

Se generan directorios `out/` con:

* `.../idempotencia-health-2x/headers.txt`
* `.../idempotencia-health-2x/body_excerpt.txt`
* `.../idempotencia-health-2x/meta.txt`

**Ejemplo de `meta.txt`:**

```
base_url=http://127.0.0.1:8080
budget_ms=200
http_code=200
time_total_s=0.041,0.039
content_type=Content-Type: application/json
```

### 5) Cómo interpretar

* **Idempotente**: si `norm1 == norm2` y el delta del contador es `2`, la operación GET no introduce trabajo extra ni efectos colaterales inesperados.
* Si falla:
  * Revisa `headers.txt` y `body_excerpt.txt`.
  * Verifica que `/metrics` reporte `http_requests_total{path="/health"}`.

### 4) Ejecución rápida

> Requisitos: Python 3, `bats` instalado, y puerto `8080` libre.

**1) Preparar entorno**
```bash
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
```

```bash
# Valores por defecto:
# BASE_URL=http://127.0.0.1:8080
# BUDGET_MS=200

bats tests/health_metrics.bats
```
