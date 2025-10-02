# Contrato de salidas: /health y /metrics

Este documento define contratos **verificables con herramientas de línea de comando** y establece los **campos mínimos** esperados.

## Variables de entorno (por ahora, para pruebas)
- `BASE_URL` (Por defecto: `http://127.0.0.1:8080`)
- `BUDGET_MS` (límite de latencia total por request). Por defecto: `200` ms para /health.

---

## Contrato: `GET /health`

### Requisitos mínimos
1. **Código**: `200 OK`.
2. **Header**: `Content-Type: application/json`
3. **Body (JSON)** con **campos mínimos**:
   - `status`: string **"ok"**
   - `time`: timestamp ISO-8601 (por ejemplo, `2025-09-29T12:34:56Z`)
4. **Latencia**: tiempo total (`time_total` de curl) **≤ `BUDGET_MS`** (200 ms por defecto).

### Criterios de validación
```bash
BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
BUDGET_MS="${BUDGET_MS:-200}"

# Descargar respuesta, headers y tiempos
tmp_h=$(mktemp); tmp_b=$(mktemp)
read -r code ttotal < <(curl -sS -D "$tmp_h" -o "$tmp_b" -w "%{http_code} %{time_total}" "$BASE_URL/health")

# Verificaciones:
test "$code" -eq 200
grep -iq '^content-type: *application/json' "$tmp_h"
grep -q '"status"[[:space:]]*:[[:space:]]*"ok"' "$tmp_b"

# latencia <= presupuesto
awk -v t="$ttotal" -v ms="$BUDGET_MS" 'BEGIN{exit !(t*1000 <= ms)}'
```

---

## Contrato: `GET /metrics`

Se adopta el formato de exposición de Prometheus (texto plano) mínimo.

### Requisitos mínimos

1. **Código**: `200 OK`.
2. **Header**: `Content-Type: text/plain` (se tolera `text/plain; version=0.0.4`).
3. **Cuerpo**: Debe incluir, al menos:
   * Una métrica de **uptime**: `process_uptime_seconds` con un valor numérico.
   * Un contador de requests a `/health`: `http_requests_total{path="/health"}` con valor numérico.

### Criterios de validación

```bash
BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
tmp_h=$(mktemp); tmp_b=$(mktemp)
read -r code _ < <(curl -sS -D "$tmp_h" -o "$tmp_b" -w "%{http_code} %{content_type}\n" "$BASE_URL/metrics")

test "$code" -eq 200
grep -iq '^content-type: *text/plain' "$tmp_h"

# Debe existir una línea con la métrica de uptime y otra con el contador de /health
grep -E '^process_uptime_seconds([[:space:]]|{).* [0-9.eE+-]+$' "$tmp_b"
grep -E '^http_requests_total\{.*path="/health".*\} [0-9.eE+-]+$' "$tmp_b"
```

---

## Fallos esperados (negativos simples) que invalidan el contrato

- `/health` sin `Content-Type: application/json`
- `/health` sin `"status":"ok"` o con tiempo total > `BUDGET_MS`.
- `/metrics` sin `text/plain`, o que no incluya ambas métricas mínimas anteriores.
