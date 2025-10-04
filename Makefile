#Makefile

SHELL := bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c

OUTDIR ?= out
DISTDIR ?= dist
SRCDIR ?= src
TESTDIR ?= tests
APP ?= $(SRCDIR)/service.py
PORT ?= 8000
BIND_ADDR ?= 127.0.0.1
BUDGET_MS ?= 150

TEST_FILE ?= $(TESTDIR)/health_metric.bats
CONTRACT_DOC ?= docs/contrato-salida.md

VENV ?= .venv
PYTHON ?= python3
PIP ?= $(VENV)/bin/pip
PY ?= $(VENV)/bin/python

TOOLS = curl bats jq bash

.DEFAULT_GOAL := help
.PHONY: tools build run test pack clean help all _wait_port _kill_app

all: tools build test 
	@echo "[all] Pipeline básico OK"
tools:
	@echo "Verificando herramientas"
	@for t in $(TOOLS); do \
		if ! command -v $$t >/dev/null 2>&1; then \
			echo "Falta herramienta requerida: $$t"; exit 1; \
		else \
			echo "OK: $$t"; \
		fi \
	done
	command -v $(PYTHON) >/dev/null || { echo "python3 no encontrado"; exit 1; }


build: $(OUTDIR) $(DISTDIR)
	@echo "[build] Preparando dependencias"
	if [[ -f requirements.txt ]]; then
		$(PYTHON) -m venv $(VENV)
		source $(VENV)/bin/activate
		$(PIP) install --upgrade pip >/dev/null
		$(PIP) install -r requirements.txt
	fi
	@echo "[build] Listo"

$(OUTDIR):
	mkdir -p $(OUTDIR)

$(DISTDIR):
	mkdir -p $(DISTDIR)

run: build
	@echo "[run] Iniciando servicio en http://$(BIND_ADDR):$(PORT)"
	@echo "[run] Ctrl+C para detener"
	ENV=dev BIND_ADDR=$(BIND_ADDR) PORT=$(PORT) $(PY) $(APP)

_wait_port:
	@echo "[wait] Esperando a que $(BIND_ADDR):$(PORT) responda..."
	for i in {1..50}; do \
		if curl -fsS "http://$(BIND_ADDR):$(PORT)/health" >/dev/null 2>&1; then \
			echo "[wait] Servicio disponible"; exit 0; \
		fi; \
		sleep 0.2; \
	done; \
	echo "[wait] Timeout esperando servicio"; exit 1


_kill_app:
	@if [[ -f $(OUTDIR)/app.pid ]]; then \
		PID=$$(cat $(OUTDIR)/app.pid); \
		if ps -p $$PID >/dev/null 2>&1; then \
			echo "[kill] Deteniendo $$PID"; \
			kill $$PID; \
			wait $$PID 2>/dev/null || true; \
		fi; \
		rm -f $(OUTDIR)/app.pid; \
	fi


test: build
	@echo "[test] Lanzando servicio en background"
	ENV=test BIND_ADDR=$(BIND_ADDR) PORT=$(PORT) $(PY) $(APP) >$(OUTDIR)/app.log 2>&1 & echo $$! > $(OUTDIR)/app.pid
	@$(MAKE) _wait_port
	@echo "[test] Ejecutando Bats"
	@set +e
	BUDGET_MS=$(BUDGET_MS) PORT=$(PORT) BIND_ADDR=$(BIND_ADDR) bats -t $(TEST_FILE) | tee $(OUTDIR)/bats.tap
	STATUS=$$?
	set -e
	@echo "[test] Guardando evidencia de /health y /metrics"
	{ \
		echo "# curl /health"; \
		curl -sS -w "\n%{http_code} %{time_total}\n" "http://$(BIND_ADDR):$(PORT)/health" -o $(OUTDIR)/health.json; \
		echo "# curl /metrics"; \
		curl -sS -w "\n%{http_code} %{time_total}\n" "http://$(BIND_ADDR):$(PORT)/metrics" -o $(OUTDIR)/metrics.txt; \
	} > $(OUTDIR)/curl-evidence.txt || true
	@$(MAKE) _kill_app
	@if [[ $$STATUS -ne 0 ]]; then \
		echo "[test] Fallos en pruebas (ver $(OUTDIR)/bats.tap)"; exit $$STATUS; \
	else \
		echo "[test] Todas las pruebas OK"; \
	fi

pack: build
	@echo "[pack] Generando artefacto reproducible"
	REL ?= 0.1.0
	SOURCE_DATE_EPOCH=$$(date -u +%s); export SOURCE_DATE_EPOCH; \
	tar --sort=name --owner=0 --group=0 --numeric-owner \
	    --mtime="@$${SOURCE_DATE_EPOCH}" \
	    -czf "$(DISTDIR)/proyecto-$(REL).tar.gz" \
	    --exclude-vcs \
	    $(SRCDIR) $(TESTDIR) docs Makefile requirements.txt || { echo "[pack] fallo"; exit 1; }
	@echo "[pack] Artefacto: $(DISTDIR)/proyecto-$(REL).tar.gz"

clean:
	@echo "[clean] Limpiando out/ y dist/..."
	rm -rf $(OUTDIR) $(DISTDIR)
	mkdir -p $(OUTDIR) $(DISTDIR)
	@echo "[clean] OK"

help:
	@echo "Uso: make <target>"
	@echo "Targets disponibles:"
	@echo "  all     -> Ejecuta tools, build y test"
	@echo "  tools   -> Verifica herramientas necesarias"
	@echo "  build   -> Prepara directorios y artefactos iniciales"
	@echo "  test    -> Corre pruebas Bats"
	@echo "  run     -> Ejecuta flujo principal"
	@echo "  pack    -> Empaqueta código y pruebas"
	@echo "  clean   -> Limpia directorios out/ y dist/"
	@echo "  help    -> Muestra esta ayuda"