# Makefile 

SHELL := /bin/bash
OUTDIR := out
DISTDIR := dist
SRCDIR := src
TESTDIR := tests

PORT ?= 8080
RELEASE ?= v0.1.0

TOOLS = curl bats


.PHONY: tools build test run clean pack help

all: tools build test run
	@echo "Flujo completo ejecutado"

tools:
	@echo "Verificando herramientas"
	@for t in $(TOOLS); do \
		if ! command -v $$t >/dev/null 2>&1; then \
			echo "Falta herramienta requerida: $$t"; exit 1; \
		else \
			echo "OK: $$t"; \
		fi \
	done

build:
	@echo "Preparando estructura"
	mkdir -p $(OUTDIR) $(DISTDIR)
	@echo "Sprint 1: no hay artefactos que compilar (solo base)."

test: tools build
	@echo "Ejecutando pruebas con bats"
	bats $(TESTDIR)

run: build
	@echo "Simulando servicio mínimo"
	@echo "Sprint 1: servicio aún no implementado"
	@echo "curl http://localhost:$(PORT)/health"
	@echo "curl http://localhost:$(PORT)/metrics"

pack: build
	@echo "Empaquetando versión $(RELEASE)"
	tar -czf $(DISTDIR)/proyecto7-$(RELEASE).tar.gz $(SRCDIR) $(TESTDIR) Makefile

clean:
	@echo "Limpiando directorios"
	rm -rf $(OUTDIR) $(DISTDIR)

help:
	@echo "Uso: make <target>"
	@echo "Targets disponibles:"
	@echo "  tools   -> Verifica herramientas necesarias"
	@echo "  build   -> Prepara directorios y artefactos iniciales"
	@echo "  test    -> Corre pruebas Bats"
	@echo "  run     -> Ejecuta flujo principal (simulado en Sprint 1)"
	@echo "  pack    -> Empaqueta código y pruebas"
	@echo "  clean   -> Limpia directorios out/ y dist/"
	@echo "  help    -> Muestra esta ayuda"
