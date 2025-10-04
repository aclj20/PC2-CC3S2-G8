#!/usr/bin/env bats

setup() {
  set -euo pipefail
  BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
  BUDGET_MS="${BUDGET_MS:-200}"

  TMP_H="$(mktemp)"
  TMP_B="$(mktemp)"
}

teardown() {
  rm -f "${TMP_H:-}" "${TMP_B:-}" || true
}

@test "GET /health -> 200 y Content-Type application/json (contrato mínimo)" {
  # Arrange: URL objetivo en BASE_URL
  # Act: ejecutar curl y capturar headers/body/código
  run bash -c '
    read -r code ttotal < <(curl -sS -D "$TMP_H" -o "$TMP_B" -w "%{http_code} %{time_total}" "'"$BASE_URL"'/health");
    echo "$code $ttotal"
  '
  # Assert: código 200 y content-type JSON
  [ "$status" -eq 0 ]  # curl debe haber retornado ok
  read -r code ttotal <<<"${output}"
  [ "$code" -eq 200 ]
  run grep -iq "^content-type: *application/json" "$TMP_H"
  [ "$status" -eq 0 ]
}

@test "GET /health -> cuerpo JSON con status=\"ok\" y latencia <= BUDGET_MS" {
  # Arrange/Act
  run bash -c '
    read -r code ttotal < <(curl -sS -D "$TMP_H" -o "$TMP_B" -w "%{http_code} %{time_total}" "'"$BASE_URL"'/health");
    echo "$code $ttotal"
  '
  [ "$status" -eq 0 ]
  read -r code ttotal <<<"${output}"
  [ "$code" -eq 200 ]

  # Assert: contiene "status":"ok"
  run grep -q "\"status\"[[:space:]]*:[[:space:]]*\"ok\"" "$TMP_B"
  [ "$status" -eq 0 ]

  # Assert: latencia (s) * 1000 <= BUDGET_MS
  run awk -v t="$ttotal" -v ms="$BUDGET_MS" "BEGIN{exit !(t*1000 <= ms)}"
  [ "$status" -eq 0 ]
}

@test "GET /metrics -> 200, text/plain y métricas mínimas (uptime + requests a /health)" {
  # Arrange/Act
  run bash -c '
    read -r code _ < <(curl -sS -D "$TMP_H" -o "$TMP_B" -w "%{http_code} %{content_type}\n" "'"$BASE_URL"'/metrics");
    echo "$code"
  '
  [ "$status" -eq 0 ]
  [ "${output}" -eq 200 ]

  # Assert: Content-Type text/plain (se acepta con parámetros)
  run grep -iq "^content-type: *text/plain" "$TMP_H"
  [ "$status" -eq 0 ]

  # Assert: métricas mínimas con valor numérico
  run grep -E "^process_uptime_seconds([[:space:]]|{).* [0-9.eE+-]+$" "$TMP_B"
  [ "$status" -eq 0 ]
  run grep -E "^http_requests_total\{.*path=\"/health\".*\} [0-9.eE+-]+$" "$TMP_B"
  [ "$status" -eq 0 ]
}
