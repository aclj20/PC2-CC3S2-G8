# Bitácora — Sprint 2

## 1) Objetivo del Sprint
Ampliar casos **negativos** y mantener **AAA/RGR** con **reportes legibles**:
- Negativos: estructura inválida en `/metrics`, status incorrecto en `/health`, latencia por encima de `BUDGET_MS`.
- Positivos: se mantienen los del Sprint 1.
- Evidencias: guardar headers, body recortado y tiempos en `out/`.

## 2) Cambios
- `tests/health_metrics.bats`:
  - Positivos (200/Content-Type/campos/métricas y latencia).
  - **Negativos ampliados**:
    - `/metrics` con estructura inválida → **detectado** (si ocurre). Si no ocurre, `skip`.
    - `/health` con `status != "ok"` → **detectado** (si ocurre). Si no ocurre, `skip`.
    - Latencia por encima del presupuesto → **simulada** con `STRICT_MS=1` para validar el detector sin afectar verdes.
  - **Reportes legibles**: `out/<timestamp>-<nombre>/` con:
    - `headers.txt`
    - `body_excerpt.txt` (primeros 4 KB)
    - `meta.txt` (URL, budget, http_code, tiempo total, content-type)

## 3) Evidencias
Tras ejecutar la suite:
- Se generan directorios `out/20251001-153000-health-200`, `out/...-metrics-minimas`, etc.
- Cada carpeta contiene headers, extracto de body y metadatos; facilitan revisión rápida en PR/CI.

## 4) Decisiones
- Los negativos dependientes del estado real del servicio (`/metrics` inválido, `status` incorrecto) se marcan **skip** si la precondición no se cumple. Evita falsos rojos en CI y respeta AAA/RGR.
- La latencia sobre presupuesto se valida con **umbral local estricto** para probar el detector de SLA sin acoplarse al entorno.

## 5) Cómo correr
```bash
# Variables
export BASE_URL=http://127.0.0.1:8080
export BUDGET_MS=200

# Ejecutar
bats tests/health_metrics.bats
```

## 6) Resultados esperados
- Con un servicio sano: positivos ok; negativos de estructura/status → skip; negativo de latencia simulada → ok (detector funciona).
- Con un servicio defectuoso: los negativos correspondientes pasarán al detectar el fallo, dejando trazas en out/.
