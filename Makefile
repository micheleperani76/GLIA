# ============================================================
#  GLIA - Makefile
#  Version: 1.0 - 2026-07-17
#  Author: Michele (with Claude)
#  Project: GLIA (GNU Linux IA)
#
#  Comodita' per la manutenzione. Nessuna build: glia e' uno script.
#    make check-docs   le superfici duplicate concordano con bin/glia? (D7)
#    make check        alias di check-docs
#    make help         questa lista
# ============================================================

.PHONY: help check-docs check

help:
	@echo "GLIA - target disponibili:"
	@echo "  make check-docs   verifica che README, commands.html, le completions"
	@echo "                    e l'header concordino con il parser di bin/glia (D7)"
	@echo "  make check        alias di check-docs"
	@echo "  make help         questa lista"

check-docs:
	@bash scripts/check-docs.sh

check: check-docs
