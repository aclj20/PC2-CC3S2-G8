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

### 3) Entregables producidos

* `docs/contrato-salidas.md`
  Contiene los contratos verificables de `/health` (JSON) y `/metrics` (Prometheus text format), con ejemplos de validación mediante `curl`, `grep`, `awk`.
* `tests/health_metrics.bats`
  Suite de pruebas Bats (AAA + RGR) para `/health` y `/metrics`, incluyendo un negativo simple para métricas mínimas.

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

### 6) Evidencias de ejecución (Sprint 1)

Dado que el servicio aún **no** está implementado, se obtuvieron fallos esperados:

* `GET /health` → **falla** por ausencia de servicio o por no cumplir Content-Type/JSON mínimo.
* `GET /metrics` → **falla** por Content-Type incorrecto o ausencia de métricas mínimas.

Salida:

```
 ✗ GET /health -> 200 y Content-Type application/json (contrato mínimo)
   (in test file tests/health_metric.bats, line 26)
     `[ "$code" -eq 200 ]' failed with status 2

     ...

 ✗ GET /health -> cuerpo JSON con status="ok" y latencia <= BUDGET_MS
   (in test file tests/health_metric.bats, line 39)
     `[ "$code" -eq 200 ]' failed with status 2

     ...

 ✗ GET /metrics -> 200, text/plain y métricas mínimas (uptime + requests a /health)
   (in test file tests/health_metric.bats, line 57)
     `[ "${output}" -eq 200 ]' failed with status 2

     ...
```


### 7) Decisiones de diseño

* **/metrics** seguirá el **formato Prometheus** (texto plano) por ser un formato estandarizado.
* Se exige **latencia** máxima configurable (`BUDGET_MS`, por defecto 200 ms) en `/health`, puesto que se espera una respuesta rápida en este endpoint.
* Contratos escritos con **criterios observables** desde CLI (sin frameworks adicionales).
* **Tolerancia** de parámetros en `Content-Type` de `/metrics` (compatibilidad con `version=0.0.4`).

