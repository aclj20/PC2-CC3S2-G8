SHELL := bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:

SRCDIR      ?= src
TESTDIR     ?= tests
DOCSDIR     ?= docs
OUTDIR      ?= out
DISTDIR     ?= dist
VENV        ?= .venv
PYTHON      ?= python3
PIP         ?= $(VENV)/bin/pip
PY          ?= $(VENV)/bin/python

APP         ?= $(SRCDIR)/service.py
BIND_ADDR   ?= 127.0.0.1
PORT        ?= 8080
BUDGET_MS   ?= 150

REL         ?= 0.3.0

REQFILE     := requirements.txt
SOURCES     := $(shell find $(SRCDIR) -type f -name '*.py' 2>/dev/null)
TESTS       := $(shell find $(TESTDIR) -type f -name '*.bats' 2>/dev/null)
DOCS        := $(shell find $(DOCSDIR) -type f \( -name '.md' -o -name '.txt' \) 2>/dev/null)
ROOTFILES   := Makefile $(REQFILE)
INPUTS      := $(ROOTFILES) $(SOURCES) $(TESTS) $(DOCS)

STAMP_BUILD := $(OUTDIR)/.built.stamp
STAMP_TEST  := $(OUTDIR)/.tested.stamp
MANIFEST    := $(OUTDIR)/manifest.txt
CHECKSUMS   := $(OUTDIR)/checksums.txt
PIDFILE     := $(OUTDIR)/app.pid
APPLOG      := $(OUTDIR)/app.log

DIST_TAR    := $(DISTDIR)/proyecto-$(REL).tar.gz

.DEFAULT_GOAL := help

.PHONY: all tools build run test pack clean help verify-idempotency _wait_port _kill_app _venv _checksums _manifest

all: tools build test
	@echo "[all] Pipeline básico completado (tools→build→test)."

tools:
	@echo "[tools] Verificando herramientas..."
	command -v bash >/dev/null
	command -v curl >/dev/null
	command -v jq >/dev/null
	command -v bats >/dev/null
	command -v $(PYTHON) >/dev/null
	@echo "[tools] OK"

build: $(STAMP_BUILD)
	@echo "[build] OK (caché incremental)."

_venv:
	@echo "[venv] Preparando entorno virtual (si aplica)..."
	if [[ -f $(REQFILE) ]]; then \
		$(PYTHON) -m venv $(VENV); \
		source $(VENV)/bin/activate; \
		$(PIP) install --upgrade pip >/dev/null; \
		$(PIP) install -r $(REQFILE); \
	else \
		echo "[venv] No hay requirements.txt; se usará python del sistema"; \
	fi

$(OUTDIR) $(DISTDIR):
	mkdir -p $@

# Checksums de entradas para decidir si hay trabajo
_checksums: | $(OUTDIR)
	@echo "[cache] Generando checksums..."
	{ \
		for f in $(INPUTS); do \
			if [[ -f $$f ]]; then sha256sum "$$f"; fi; \
		done; \
	} | sort > $(CHECKSUMS).new
	if [[ -f $(CHECKSUMS) ]]; then \
		if cmp -s $(CHECKSUMS).new $(CHECKSUMS); then \
			echo "[cache] Checksums sin cambios"; \
			rm -f $(CHECKSUMS).new; \
		else \
			echo "[cache] Cambios detectados en entradas"; \
			mv $(CHECKSUMS).new $(CHECKSUMS); \
		fi; \
	else \
		mv $(CHECKSUMS).new $(CHECKSUMS); \
	fi

_manifest: | $(OUTDIR)
	@echo "[manifest] Escribiendo manifest..."
	{ \
		echo "REL=$(REL)"; \
		date -u +"BUILD_UTC=%Y-%m-%dT%H:%M:%SZ"; \
		echo "BIND_ADDR=$(BIND_ADDR)"; \
		echo "PORT=$(PORT)"; \
		echo "BUDGET_MS=$(BUDGET_MS)"; \
		git rev-parse --short HEAD 2>/dev/null | sed 's/^/GIT_HEAD=/'; \
	} > $(MANIFEST)

$(STAMP_BUILD): | $(OUTDIR) $(DISTDIR)
	@echo "[build] Iniciando..."
	@$(MAKE) _checksums
	@$(MAKE) _manifest
	@$(MAKE) _venv
	@touch $(STAMP_BUILD)

run: build
	@echo "[run] Iniciando servicio en http://$(BIND_ADDR):$(PORT)"
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
	@if [[ -f $(PIDFILE) ]]; then \
		PID=$$(cat $(PIDFILE)); \
		if ps -p $$PID >/dev/null 2>&1; then \
			echo "[kill] Deteniendo $$PID"; \
			kill $$PID; \
			wait $$PID 2>/dev/null || true; \
		fi; \
		rm -f $(PIDFILE); \
	fi

test: $(STAMP_TEST)
	@echo "[test] OK (evidencias en $(OUTDIR))."

$(STAMP_TEST): build
	@echo "[test] Lanzando servicio en background..."
	ENV=test BIND_ADDR=$(BIND_ADDR) PORT=$(PORT) $(PY) $(APP) >$(APPLOG) 2>&1 & echo $$! > $(PIDFILE)
	@$(MAKE) _wait_port
	@echo "[test] Ejecutando Bats..."
	# Ejecuta todos los .bats
	set +e
	BUDGET_MS=$(BUDGET_MS) PORT=$(PORT) BIND_ADDR=$(BIND_ADDR) bats -t $(TESTDIR) | tee $(OUTDIR)/bats.tap
	STATUS=$$?
	set -e
	@echo "[test] Guardando evidencia curl..."
	{ \
		echo "# GET /health"; \
		curl -sS -w "\n%{http_code} %{time_total}\n" "http://$(BIND_ADDR):$(PORT)/health" -o $(OUTDIR)/health.json; \
		echo ""; \
		echo "# GET /metrics"; \
		curl -sS -w "\n%{http_code} %{time_total}\n" "http://$(BIND_ADDR):$(PORT)/metrics" -o $(OUTDIR)/metrics.txt; \
	} > $(OUTDIR)/curl-evidence.txt || true
	@$(MAKE) _kill_app
	if [[ $$STATUS -ne 0 ]]; then \
		echo "[test] Fallos en pruebas (ver $(OUTDIR)/bats.tap)"; exit $$STATUS; \
	fi
	@touch $(STAMP_TEST)

pack: build
	@echo "[pack] Generando artefacto reproducible..."
	# Para reproducibilidad, fija la fecha a la última modificación entre inputs
	SOURCE_DATE_EPOCH=$$( \
		{ for f in $(INPUTS); do if [[ -f $$f ]]; then date -r $$f +%s; fi; done; } | sort -n | tail -1 \
	); \
	if [[ -z "$$SOURCE_DATE_EPOCH" ]]; then SOURCE_DATE_EPOCH=$$(date -u +%s); fi; \
	export SOURCE_DATE_EPOCH; \
	tar --sort=name --owner=0 --group=0 --numeric-owner \
	    --mtime="@$${SOURCE_DATE_EPOCH}" \
	    --transform 's,^,$(notdir $(CURDIR))/,S' \
	    -czf "$(DIST_TAR)" \
	    --exclude-vcs --exclude="$(VENV)" --exclude="$(OUTDIR)" --exclude="$(DISTDIR)" \
	    --exclude='_pycache_' --exclude='*.pyc' --exclude='.DS_Store' \
	    $(SRCDIR) $(TESTDIR) $(DOCSDIR) Makefile $(REQFILE) 2>/dev/null || { echo "[pack] fallo"; exit 1; }
	@echo "[pack] Artefacto: $(DIST_TAR)"


verify-idempotency: build test
	@echo "[idempotency] Verificando que una segunda ejecución no haga trabajo extra"
	@set -e
	# Make -n no debe imprimir comandos si no hay trabajo pendiente
	if [[ -z "$$($(MAKE) -n all 2>/dev/null | sed '/^make\[/d')" ]]; then \
		echo "[idempotency] OK: no hay trabajo en segunda ejecución"; \
	else \
		echo "[idempotency] Fallo: aún hay acciones pendientes en segunda ejecución"; \
		exit 1; \
	fi


clean:
	@echo "[clean] Limpiando $(OUTDIR) y $(DISTDIR)"
	rm -rf $(OUTDIR) $(DISTDIR)
	mkdir -p $(OUTDIR) $(DISTDIR)
	@echo "[clean] OK"


help:
	@echo "Uso: make <target>"
	@echo ""
	@echo "Targets:"
	@echo "  all                - Ejecuta tools, build y test"
	@echo "  tools              - Verifica herramientas"
	@echo "  build              - Venv + deps + caché"
	@echo "  run                - Ejecuta el servicio en foreground"
	@echo "  test               - Arranca servicio, corre Bats y guarda evidencias en out/"
	@echo "  pack               - Crea dist/proyecto-<REL>.tar.gz"
	@echo "  verify-idempotency - Comprueba que la segunda corrida no hace trabajo"
	@echo "  clean              - Limpia out/ y dist/"
	@echo "  help               - Esta ayuda"
