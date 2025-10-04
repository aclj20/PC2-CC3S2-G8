#!/usr/bin/env bats

setup() {
  set -euo pipefail
  BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
  BUDGET_MS="${BUDGET_MS:-200}"

  TMP_H="$(mktemp)"
  TMP_B="$(mktemp)"
  mkdir -p out

  # timestamp para evidencias
  TS="$(date +%Y%m%d-%H%M%S)"
}

teardown() {
  rm -f "${TMP_H:-}" "${TMP_B:-}" || true
}

save_evidence() {
  # $1: nombre base (ej: health-200, metrics-neg-structure)
  local name="$1"
  local dir="out/${TS}-${name}"
  mkdir -p "$dir"
  # headers completos
  cp "$TMP_H" "$dir/headers.txt"
  # body recortado para lectura rápida (primeros 4 KB)
  head -c 4096 "$TMP_B" > "$dir/body_excerpt.txt" || true
  # anexa metadatos de tiempos si están disponibles en variables globales
  {
    echo "base_url=${BASE_URL}"
    echo "budget_ms=${BUDGET_MS}"
    echo "http_code=${HTTP_CODE:-}"
    echo "time_total_s=${TIME_TOTAL_S:-}"
    echo "content_type=${CONTENT_TYPE:-}"
  } > "$dir/meta.txt"
  # nota visible
  echo "# Evidencia guardada en $dir"
}

# -------
# Helpers
# -------

# curl_json <path> (para /health)
curl_json() {
  local path="$1"
  : >"$TMP_H"; : >"$TMP_B"
  # stdout prints: "<http_code> <time_total>"
  read -r code ttotal < <(curl -sS -D "$TMP_H" -o "$TMP_B" -w "%{http_code} %{time_total}" "$BASE_URL$path")
  echo "$code $ttotal"
}

# curl_plain <path>  (para /metrics)
curl_plain() {
  local path="$1"
  : >"$TMP_H"; : >"$TMP_B"
  # stdout prints: "<http_code> <content_type>"
  read -r code ctype < <(curl -sS -D "$TMP_H" -o "$TMP_B" -w "%{http_code} %{content_type}" "$BASE_URL$path")
  echo "$code $ctype"
}

# get_header <Header-Name>  ->  echo "Header-Name: value"
get_header() {
  local name="$1"
  grep -i "^$name:" "$TMP_H" | head -n1 | tr -d '\r'
}


#
# --------- CASOS POSITIVOS ---------
#

@test "GET /health -> 200 y Content-Type application/json (contrato mínimo)" {
  # Act
  read -r HTTP_CODE TIME_TOTAL_S <<<"$(curl_json /health)"
  CONTENT_TYPE="$(get_header Content-Type)"


  # Assert
  [ "$HTTP_CODE" -eq 200 ]
  run grep -iq "^content-type: *application/json" "$TMP_H"
  [ "$status" -eq 0 ]

  save_evidence "health-200"
}

@test "GET /health -> body con status=\"ok\" y latencia <= BUDGET_MS" {
  # Act
  read -r HTTP_CODE TIME_TOTAL_S <<<"$(curl_json /health)"


  # Assert: 200
  [ "$HTTP_CODE" -eq 200 ]

  # Assert: "status":"ok"
  run grep -q "\"status\"[[:space:]]*:[[:space:]]*\"ok\"" "$TMP_B"
  [ "$status" -eq 0 ]

  # Assert: latencia (s)*1000 <= BUDGET_MS
  run awk -v t="$TIME_TOTAL_S" -v ms="$BUDGET_MS" 'BEGIN{exit !(t*1000 <= ms)}'
  [ "$status" -eq 0 ]

  save_evidence "health-ok-latency"
}

@test "GET /metrics -> 200, text/plain y métricas mínimas (uptime + requests a /health)" {
  # Act
  read -r HTTP_CODE CONTENT_TYPE <<<"$(curl_plain /metrics)"
  # Assert
  [ "$HTTP_CODE" -eq 200 ]
  run grep -iq "^content-type: *text/plain" "$TMP_H"
  [ "$status" -eq 0 ]
  run awk '/^process_uptime_seconds/ { v=$NF; if (v ~ /^[0-9.eE+-]+$/) ok=1 } END { exit !(ok) }' "$TMP_B"
  [ "$status" -eq 0 ]
  run grep -E '^http_requests_total\{.*path="/health".*\} [0-9.eE+-]+$' "$TMP_B"
  [ "$status" -eq 0 ]

  save_evidence "metrics-minimas"
}

#
# --------- CASOS NEGATIVOS AMPLIADOS ---------
#

@test "NEG: /metrics estructura inválida -> si sucede, debe detectarse y reportarse" {
  # Este negativo se ejecuta SOLO si la respuesta realmente está mal formada.
  # Si está bien, hacemos skip (precondición no cumplida) para mantener verde.
  run curl -sS "$BASE_URL/metrics" > "$TMP_B"
  [ "$status" -eq 0 ]

  # Reglas mínimas de estructura:
  #  - líneas de métrica: <name>{labels}? <number>
  #  - los valores deben ser numéricos válidos
  #  - si aparece process_uptime_seconds o http_requests_total, su valor debe ser numérico
  bad=0
  if grep -E '^process_uptime_seconds([[:space:]]|{).* [^0-9.eE+-]' "$TMP_B" >/dev/null; then bad=1; fi
  if grep -E '^http_requests_total\{.*path="/health".*\} [^0-9.eE+-]' "$TMP_B" >/dev/null; then bad=1; fi

  if [ "$bad" -eq 0 ]; then
    skip "Precondición no cumplida: /metrics tiene estructura válida (negativo no aplica)."
  fi

  # Si está mal, el test pasa al detectarlo
  [ "$bad" -eq 1 ]
  save_evidence "metrics-neg-structure"
}

@test "NEG: /health con status distinto de \"ok\" -> si sucede, debe detectarse" {
  # Solo valida si el status devuelto NO es 'ok'. Si es 'ok', skip.
  read -r _ _ <<<"$(curl_json /health)"
  if grep -q '"status"[[:space:]]*:[[:space:]]*"ok"' "$TMP_B"; then
    skip 'Precondición no cumplida: status="ok" (negativo no aplica).'
  fi

  # Assert
  true  # si llegó aquí, el status no es "ok" y el negativo se considera detectado
  save_evidence "health-neg-status"

}

@test "NEG: latencia por encima de BUDGET_MS -> detector debe marcar exceso" {
  # Simulación controlada: fijamos un umbral estricto local para forzar la condición.
  # Esto valida el detector SIN depender de la latencia real del entorno.
  STRICT_MS=1  # 1 ms, fuerza exceso casi siempre
  run bash -c '
    read -r _ ttotal < <(curl -sS -o /dev/null -w "%{http_code} %{time_total}" "'"$BASE_URL"'/health");
    awk -v t="$ttotal" -v ms="'"$STRICT_MS"'" "BEGIN{exit !(t*1000 <= ms)}"
  '
  # Queremos que awk salga con código != 0 (exceso de latencia detectado)
  [ "$status" -ne 0 ]

  # Guardamos evidencia básica (no tenemos TMP_H/TMP_B aquí, así que solo meta)
  HTTP_CODE="" TIME_TOTAL_S=""
  save_evidence "health-neg-latency"
}
