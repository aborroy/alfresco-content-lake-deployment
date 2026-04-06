# =============================================================
# Alfresco Content Lake — Unified Stack Makefile
# =============================================================

export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

STACK_MODE ?= full
VALID_STACK_MODES := full alfresco nuxeo demo

ifeq (,$(filter $(STACK_MODE),$(VALID_STACK_MODES)))
$(error STACK_MODE must be one of: $(VALID_STACK_MODES))
endif

# If .env.local exists:
#  1. Pass --env-file so its values are used for compose-file interpolation.
#  2. Prefix every compose command with "set -a && . .env.local && set +a &&"
#     so Docker secrets (which read os.Getenv, not the --env-file context)
#     can find MAVEN_USERNAME, MAVEN_PASSWORD, NEXUS_* and HXPR_GIT_AUTH_TOKEN.
ifneq (,$(wildcard .env.local))
  ENV_ARGS  := --env-file .env.local
else
  ENV_ARGS  :=
endif

LOAD_ENV := set -a && . ./.env && if [ -f ./.env.local ]; then . ./.env.local; fi && set +a &&
RAG_PERMISSION_SOURCE_IDS_EXPR := $${RAG_PERMISSION_SOURCE_IDS:-$$(if [ "$(STACK_MODE)" = "alfresco" ]; then printf '%s' "$${HXPR_REPOSITORY_ID:-default}"; elif [ "$(STACK_MODE)" = "nuxeo" ]; then printf '%s' "$${NUXEO_SOURCE_ID:-local}"; else printf '%s,%s' "$${HXPR_REPOSITORY_ID:-default}" "$${NUXEO_SOURCE_ID:-local}"; fi)}
DC := $(LOAD_ENV) STACK_MODE=$(STACK_MODE) COMPOSE_PROFILES=$(STACK_MODE) RAG_PERMISSION_SOURCE_IDS="$(RAG_PERMISSION_SOURCE_IDS_EXPR)" docker compose $(ENV_ARGS)

.PHONY: help up down logs ps config clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "  STACK_MODE=<full|alfresco|nuxeo|demo> selects the deployed source set (default: full)."

up: ## Build images (if needed) and start all services
	$(DC) up --build -d
	@echo ""
	@set -a; . ./.env; \
	  if [ -f ./.env.local ]; then . ./.env.local; fi; \
	  set +a; \
	  host="$${SERVER_NAME:-localhost}"; \
	  port="$${PUBLIC_PORT:-80}"; \
	  mode="$(STACK_MODE)"; \
	  base_url="http://$$host"; \
	  if [ "$$port" != "80" ]; then base_url="$$base_url:$$port"; fi; \
	  echo "Stack is starting in '$$mode' mode. Key endpoints (once healthy):"; \
	  echo "  RAG Service          → $$base_url/api/rag"; \
	  if [ "$$mode" = "full" ] || [ "$$mode" = "alfresco" ]; then \
	    echo "  ACA / Content Lake UI → $$base_url/"; \
	    echo "  Alfresco             → $$base_url/alfresco"; \
	    echo "  Share                → $$base_url/share"; \
	    echo "  Control Center       → $$base_url/admin"; \
	  fi; \
	  if [ "$$mode" = "demo" ]; then \
	    echo "  Demo App             → $$base_url/"; \
	    echo "  Alfresco             → $$base_url/alfresco"; \
	    echo "  Share                → $$base_url/share"; \
	    echo "  Control Center       → $$base_url/admin"; \
	  fi; \
	  if [ "$$mode" = "full" ] || [ "$$mode" = "nuxeo" ] || [ "$$mode" = "demo" ]; then \
	    echo "  Nuxeo Web UI         → $$base_url/nuxeo/"; \
	  fi
	@echo ""

down: ## Stop and remove containers (preserves volumes)
	$(DC) down

logs: ## Follow logs for all services
	$(DC) logs -f

ps: ## Show running services and their status
	$(DC) ps

config: ## Render the resolved docker compose configuration
	$(DC) config

clean: ## Stop containers and remove all volumes (DESTRUCTIVE)
	@echo "WARNING: This removes all persistent data (Alfresco, MongoDB, OpenSearch, etc.)"
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	$(DC) down -v
