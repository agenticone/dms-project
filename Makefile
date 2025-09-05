SHELL := /bin/bash

ENV_FILE ?= .env

# Helper to read a var from .env with a default fallback
_read_env = $(shell awk -F= '/^$(1)=/{print $$2}' $(ENV_FILE) 2>/dev/null | tr -d "\r" )

DOMAIN ?= $(call _read_env,DOMAIN)
DOMAIN := $(if $(DOMAIN),$(DOMAIN),dmsin.local)

.PHONY: dev-certs local-up local-down

dev-certs:
	@command -v mkcert >/dev/null 2>&1 || { echo "mkcert is not installed. See https://github.com/FiloSottile/mkcert"; exit 1; }
	@mkdir -p traefik/certs
	@echo "Generating local TLS cert for *.$(DOMAIN) ..."
	@mkcert -install
	@mkcert -cert-file traefik/certs/dev.crt -key-file traefik/certs/dev.key "*.$(DOMAIN)"
	@echo "Created traefik/certs/dev.crt and traefik/certs/dev.key"

local-up:
	@echo "Starting stack with local override (no ACME)..."
	docker compose -f docker-compose.yml -f compose.local.yml up -d

local-down:
	@docker compose -f docker-compose.yml -f compose.local.yml down

