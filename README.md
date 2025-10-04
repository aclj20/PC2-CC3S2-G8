# Proyecto 7: Contratos para /health y /metrics
**Práctica Calificada 2 – Sección B**

## Descripción general
En el presente proyecto se definen contratos mínimos para los endpoints /health y /metrics, y se construye una suite de pruebas automatizadas con Bats siguiendo el ciclo RGR. Se utiliza curl, parsers simples y Make para automatizar la ejecución y validación, incluyendo casos negativos como estructuras inválidas o latencia excesiva, y se generan reportes de cumplimiento en la carpeta out/.


## Instrucciones de uso

1. **Instalar dependencias**  
   Se requiere [bats-core](https://github.com/bats-core/bats-core).

   ```bash
   # Ubuntu/Debian
   sudo apt-get update && sudo apt-get install -y bats
   ```

2. **Ejecutar pruebas**
   Las pruebas están en `tests/health_metrics.bats`.

   ```bash
   bats tests/health_metrics.bats
   ```

---

## Variables de entorno

| Variable    | Efecto                                                                    |
| ----------- | ------------------------------------------------------------------------- |
| `BASE_URL`  | URL base del servicio a testear. Por defecto `http://127.0.0.1:8080`.     |
| `BUDGET_MS` | Límite máximo de latencia (en milisegundos) para `/health`. Default: 200. |

Ejemplo de uso:

```bash
BASE_URL=http://localhost:5000 BUDGET_MS=300 bats tests/health_metrics.bats
```

---

## Contrato de salidas

### `/health`

* **200 OK**
* `Content-Type: application/json`
* **Body mínimo (JSON):**
* Latencia ≤ `BUDGET_MS`.

### `/metrics`

* **200 OK**
* `Content-Type: text/plain` (se acepta `text/plain; version=0.0.4`)
* **Cuerpo mínimo:**
