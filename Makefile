
ROOT_DIR   := $(shell git rev-parse --show-toplevel)
VENV_CMD   := python3 -m venv
VENV_DIR   := $(ROOT_DIR)/.venv
VENV_BIN   := $(VENV_DIR)/bin

# Docker Build Flags
DOCKER     ?= $(shell which docker)
DOCKERFILE ?= .

# gogo Application
GOGO_DOCKER_IMAGE          ?= gogo
GOGO_DOCKER_TAG            ?= latest
GOGO_DOCKER_CONTAINER_NAME ?= gogo-dev
GOGO_HOST                  ?= $(GOGO_DOCKER_CONTAINER_NAME)

# TODO: Extend for Google OAuth support
ifeq ($(AUTH_HEADER_NAME),)
	SKIP_AUTH            ?= true
else
	SKIP_AUTH            ?= false
	AUTH_HEADER_NAME_ENV := --env AUTH_HEADER_NAME=$(AUTH_HEADER_NAME)
endif

# Database
PG_DOCKER_IMAGE          ?= postgres
PG_DOCKER_TAG            ?= 10.0
PG_DOCKER_CONTAINER_NAME ?= gogo-postgres
PG_HOST                  := $(PG_DOCKER_CONTAINER_NAME)
PG_USER                  := gogo
PG_PASS                  := gogo
PG_DB                    := gogo
PG_DATA                  := /var/lib/postgresql/data/gogo
PG_DATA_LOCAL            ?= $(HOME)/data/gogo

# GoGo Application
.PHONY: docker_build
docker_build:
	$(DOCKER) build $(DOCKERFILE) -t $(GOGO_DOCKER_IMAGE):$(GOGO_DOCKER_TAG)

.PHONY: run
run: stop docker_build
	$(DOCKER) ps | grep $(PG_DOCKER_CONTAINER_NAME) > /dev/null || $(MAKE) db
	$(DOCKER) run \
		--name $(GOGO_DOCKER_CONTAINER_NAME) \
		--hostname $(GOGO_HOST) \
		--publish 80:80 \
		--publish 443:443 \
		--env CONFIG=DevelopmentConfig \
		--env SKIP_AUTH=$(SKIP_AUTH) \
		$(AUTH_HEADER_NAME_ENV) \
		--env DATABASE_URI=postgresql://$(PG_USER):$(PG_PASS)@$(PG_HOST)/$(PG_DB) \
		--volume $(HOME)/.aws:/root/.aws \
		--link $(PG_DOCKER_CONTAINER_NAME):$(PG_HOST) \
		-it $(GOGO_DOCKER_IMAGE):$(GOGO_DOCKER_TAG)

.PHONY: stop
stop:
	$(DOCKER) rm -f $(GOGO_DOCKER_CONTAINER_NAME) > /dev/null 2>&1 || true

# Postgres Database
.PHONY: db
db:
	@echo "Launching Postgres..."
	$(DOCKER) rm -f $(PG_DOCKER_CONTAINER_NAME) > /dev/null 2>&1 || true
	$(DOCKER) run \
		--name $(PG_DOCKER_CONTAINER_NAME) \
		--hostname $(PG_HOST) \
		--env POSTGRES_USER=$(PG_USER) \
		--env POSTGRES_PASSWORD=$(PG_PASS) \
		--env POSTGRES_DB=$(PG_DB) \
		--env PGDATA=$(PG_DATA) \
		--volume $(PG_DATA_LOCAL):$(PG_DATA) \
		--detach $(PG_DOCKER_IMAGE):$(PG_DOCKER_TAG) > /dev/null
	@echo "Waiting for Postgres to be ready..."
	while true; do \
		/bin/echo -n "." ; \
		docker exec $(PG_DOCKER_CONTAINER_NAME) pg_isready -U $(PG_USER) -d $(PG_DB) --quiet && break; \
		sleep 1; \
	done ; /bin/echo
	@echo "Waiting for $(PG_USER) role to exist..."
	while true; do \
		/bin/echo -n "." ; \
		COMMAND="SELECT 1" $(MAKE) db-run-command > /dev/null 2>&1 && break; \
		sleep 1; \
	done ; /bin/echo
	@$(MAKE) db-apply-schema

.PHONY: db-truncate
db-truncate:
	@echo "Truncating database..."
	@COMMAND='TRUNCATE shortcut;' $(MAKE) db-run-command

.PHONY: db-wipe
db-wipe:
	@echo "Wiping database..."
	$(DOCKER) exec $(PG_DOCKER_CONTAINER_NAME) dropdb -U $(PG_USER) $(PG_DB)
	$(DOCKER) exec $(PG_DOCKER_CONTAINER_NAME) createdb -U $(PG_USER) $(PG_DB)

.PHONY: psql
psql:
	$(DOCKER) exec -it $(PG_DOCKER_CONTAINER_NAME) psql \
		-U $(PG_USER) \
		-d $(PG_DB)

.PHONY: db-run-command
db-run-command:
	$(DOCKER) exec $(PG_DOCKER_CONTAINER_NAME) psql \
		-U $(PG_USER) \
		-d $(PG_DB) \
		-c "$$COMMAND"

.PHONY: db-run-file
db-run-file:
	$(DOCKER) cp $$SQL_FILE $(PG_DOCKER_CONTAINER_NAME):/sql_file.sql
	$(DOCKER) exec $(PG_DOCKER_CONTAINER_NAME) psql \
		-f /sql_file.sql \
		-U $(PG_USER) \
		-d $(PG_DB)

.PHONY: db-apply-schema
db-apply-schema:
	@if COMMAND='\d' $(MAKE) db-run-command | grep 'row' > /dev/null; then \
		echo "Schema already applied. Use 'make db-wipe' to reset all data."; \
	else \
		echo "Applying schema..."; \
		SQL_FILE=schema/schema.sql $(MAKE) db-run-file; \
	fi

# Dev Env
.PHONY: venv
venv: $(VENV_BIN)/activate
	if [ "$$(cat resources/requirements.txt | sort)" != "$$($(VENV_BIN)/pip freeze)" ]; then \
		$(VENV_BIN)/pip install -Ur resources/requirements.txt; \
	fi

$(VENV_BIN)/activate:
	@echo "Creating and updating venv..."
	$(VENV_CMD) $(VENV_DIR)
	$(VENV_BIN)/python -m pip install -U pip setuptools wheel
	$(VENV_BIN)/pip install black isort

.PHONY: clean
clean:
	$(DOCKER) rm -f $(GOGO_DOCKER_CONTAINER_NAME) $(PG_DOCKER_CONTAINER_NAME) || true
	rm -rf $(PG_DATA_LOCAL)/* || true
	rm -rf $(VENV_DIR) || true
