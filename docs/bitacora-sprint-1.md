# Bitácora — Sprint 1

## Contratos `/health` y `/metrics`

### 1) Desarrollo de contrato `/health` y `/metrics` junto a 

Durante el Sprint 1 se definieron los **contratos formales** de las salidas `/health` y `/metrics`, y se implementaron pruebas **Bats** deliberadamente en **estado rojo** (RGR: Red → Green → Refactor) con **casos positivos mínimos** y **negativos simples**. Estas pruebas fallan deliberadamente por no tener el backend desarrollado aún, lo cual es de esperarse.

### 2) Alcance del Sprint 1

* Definir contratos formales: **status esperado, forma de payload y campos mínimos** para `/health` y `/metrics`.
* Crear pruebas **Bats** para `/health` y `/metrics` que **fallen inicialmente**:
  * Casos positivos mínimos (código 200, content-type correcto, presencia de campos/métricas requeridas).
  * Casos negativos simples (ausencia de métricas/campos rompe el contrato).
* Entregables:
  * `docs/contrato-salidas.md` con criterios verificables y **referencias de validación vía curl y toolkit de texto**.
  * `tests/health_metrics.bats` (estado **rojo**).
  * `src/service.py` (servicio mínimo)
  * `requirements.txt`

### 3) Entregables producidos

* `docs/contrato-salidas.md`
  Contiene los contratos verificables de `/health` (JSON) y `/metrics` (Prometheus text format), con ejemplos de validación mediante `curl`, `grep`, `awk`.
* `tests/health_metrics.bats`
  Suite de pruebas Bats (AAA + RGR) para `/health` y `/metrics`, incluyendo un negativo simple para métricas mínimas.
* `src/service.py`  
  Servicio mínimo implementado en **Flask**, que expone endpoints `/health` y `/metrics` con respuestas **dummy**:
  - `/health` → `200 OK`, `application/json`, body `{"status":"dummy","uptime":"0s"}`
  - `/metrics` → `200 OK`, `text/plain`, cuerpo con métricas ficticias (`requests_total 0`, `latency_ms_p50 0`)
  - Rutas no definidas → `404 Not Found`, JSON `{"error":"not found"}`  

### 4) Criterios de aceptación (contratos resumidos)

**GET `/health`**

* **200 OK**
* **Content-Type:** `application/json`
* **Body mínimo (JSON):**
* **Latencia:** `time_total` de `curl` ≤ **200 ms** (configurable vía `BUDGET_MS`).

**GET `/metrics`** (formato Prometheus – texto)

* **200 OK**
* **Content-Type:** `text/plain` (se acepta `text/plain; version=0.0.4`)

### 5) Actividades realizadas

1. Redacción de **contratos verificables** y documentados con comandos reproducibles (curl + toolkit de texto).
2. Implementación de **pruebas Bats**:

   * **Positivas mínimas**: validan 200/Content-Type correcto y contenido requerido.
   * **Negativa simple**: falla si las métricas mínimas están ausentes.
3. Parametrización con variables `BASE_URL` y `BUDGET_MS` para ejecutar tests contra distintos entornos.
4. Guía de ejecución local (instalación de Bats y comando `bats tests/health_metrics.bats`).
5. Configuración de entorno virtual en Python y **instalación de Flask** como dependencia mínima.  
6. Implementación de un **servicio dummy en Flask** (`src/service.py`) con endpoints:  
   - `/health` → retorna `200 OK`, JSON con `"status":"dummy"`.  
   - `/metrics` → retorna `200 OK`, texto plano con métricas ficticias.  
   - Cualquier otra ruta → `404 Not Found`.    
7. Verificación de que las pruebas Bats de A se mantienen en **estado rojo**, tanto si apuntan a `8080` (no alcanzan el servicio) como si se fuerzan contra `18080` (algunos asserts fallan por valores dummy).  


### 6) Evidencias de ejecución (Sprint 1)

Dado que estamos en la etapa **R** de RGR, las pruebas se mantienen en **estado rojo** de forma esperada:

* Con el **puerto por defecto (8080)**:
  - `GET /health` → **falla** por ausencia de servicio en esa dirección.
  - `GET /metrics` → **falla** por ausencia de servicio.
* Con el **fixture en Flask (18080)**:
  - `GET /health` → responde `200 OK` y `Content-Type: application/json`, pero **falla** la prueba que exige `"status":"ok"` (se devuelve `"status":"dummy"`).
  - `GET /metrics` → responde `200 OK` y `text/plain`, pero **falla** la prueba que exige métricas mínimas (`process_uptime_seconds`, `http_requests_total{path="/health"}`), ya que el fixture entrega métricas ficticias.

#### Evidencias de ejecución con pruebas Bats (BASE_URL=127.0.0.1:8080)

✗ GET /health -> 200 y Content-Type application/json (contrato mínimo)
(in test file tests/health_metrics.bats, line 26)
`[ "$code" -eq 200 ]' failed with status 2

✗ GET /health -> cuerpo JSON con status="ok" y latencia <= BUDGET_MS
(in test file tests/health_metrics.bats, line 39)
`[ "$code" -eq 200 ]' failed with status 2

✗ GET /metrics -> 200, text/plain y métricas mínimas (uptime + requests a /health)
(in test file tests/health_metrics.bats, line 57)
`[ "${output}" -eq 200 ]' failed with status 2


#### Evidencias de ejecución manual (fixture Flask en 18080)

```bash
$ curl -i http://127.0.0.1:18080/health
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 33
{"status":"dummy","uptime":"0s"}

$ curl -i http://127.0.0.1:18080/metrics
HTTP/1.0 200 OK
Content-Type: text/plain
Content-Length: 36
requests_total 0
latency_ms_p50 0

$ curl -i http://127.0.0.1:18080/ds
HTTP/1.0 404 NOT FOUND
Content-Type: application/json
{"error":"not found"}
```

### 7) Decisiones de diseño

* **/metrics** seguirá el **formato Prometheus** (texto plano) por ser un formato estandarizado.
* Se exige **latencia** máxima configurable (`BUDGET_MS`, por defecto 200 ms) en `/health`, puesto que se espera una respuesta rápida en este endpoint.
* Contratos escritos con **criterios observables** desde CLI (sin frameworks adicionales).
* **Tolerancia** de parámetros en `Content-Type` de `/metrics` (compatibilidad con `version=0.0.4`).

