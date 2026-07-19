# ============================================================
#  GLIA - Makefile
#  Version: 2.0 - 2026-07-19 (v3.0.0: the split - src/ + build)
#  Author: Michele (with Claude)
#  Project: GLIA (GNU Linux IA)
#
#  Dalla v3 lo sviluppo e' in src/ (un modulo per area) e bin/glia
#  e' l'artefatto GENERATO - committato, cosi' --update e rollback
#  non cambiano. Si edita src/, poi `make build`.
#    make build        ricostruisce bin/glia da src/*.sh
#    make check-docs   le superfici duplicate concordano con bin/glia?
#                      (include il check #6: build e artefatto combaciano)
#    make check        build + check-docs
#    make lint         shellcheck sui moduli (informativo, serve shellcheck)
#    make help         questa lista
# ============================================================

.PHONY: help build check-docs check lint

help:
	@echo "GLIA - target disponibili:"
	@echo "  make build        ricostruisce bin/glia da src/*.sh"
	@echo "  make check-docs   verifica superfici + build allineata (D7, #6)"
	@echo "  make check        build + check-docs"
	@echo "  make lint         shellcheck sui moduli (informativo)"
	@echo "  make help         questa lista"

build:
	@bash scripts/build.sh

check-docs:
	@bash scripts/check-docs.sh

check: build check-docs

lint:
	@command -v shellcheck >/dev/null 2>&1 || { echo "shellcheck non installato (pacman -S shellcheck / apt install shellcheck)"; exit 1; }
	@shellcheck -S warning -s bash src/[0-9]*.sh || true
	@echo "(informativo: i warning non bloccano - vedi CONTRIBUTING.md)"
