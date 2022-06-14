ROOT_DIR      := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
SHA1          := $(shell git rev-parse --short HEAD)
VENV_CMD      := python3 -m venv
VENV_DIR      := $(ROOT_DIR)/.venv
VENV_BIN      := $(VENV_DIR)/bin

###############################################################################
# GoGo
###############################################################################

DOCKER_IMAGE ?= gogo
DOCKER_TAG ?= latest

DOCKER_BUILD_ARGS := -t $(DOCKER_IMAGE)

ifdef CACHE_FROM
DOCKER_BUILD_ARGS := --cache-from $(CACHE_FROM) $(DOCKER_BUILD_ARGS)
endif

.PHONY: run stop test

run: stop
	@touch envfile
	@docker ps | grep gogo-postgres > /dev/null || $(MAKE) db
	@docker run --name $(DOCKER_IMAGE) \
		--publish 80:80 \
		--env AUTH_HEADER_NAME=X-BC-User \
		--env SKIP_AUTH=true \
		--env CONFIG=DevelopmentConfig \
		--env DATABASE_URI="postgresql://gogo:gogo@gogo-postgres/gogo" \
		--env BASE_URL=http://localhost \
		--env-file envfile \
		--hostname gogo-dev \
		--volume $(HOME)/.aws:/root/.aws \
		--link gogo-postgres \
		-it \
		$(DOCKER_IMAGE)

stop:
	@docker rm -f $(DOCKER_IMAGE) > /dev/null 2>&1 || true

test: stop
	@touch envfile
	@echo "Testing $(DOCKER_IMAGE)"
	@docker run $$ARGS $$INTERACTIVE_ARGS --entrypoint sh \
		"$(DOCKER_IMAGE)" \
		-c "cd /app/src/ && PYTHONPATH=. pytest $$TEST_ARGS --cov"

###############################################################################
# Database
###############################################################################

PG_DOCKER_IMAGE=postgres
PG_DOCKER_TAG=11.0
PG_DB=gogo
PG_HOST=localhost
PG_PORT=5432
PG_USER=gogo
PG_PASS=gogo # for dev only. Prod password is encrypted in KMS via DATABASE_URI_KMS
PG_DATA=/var/lib/postgresql/data/gogo


.PHONY: db db-truncate db-wipe psql db-run-command db-run-file db-apply-schema

db:
	@echo "Launching Postgres."
	@docker rm -f gogo-postgres > /dev/null 2>&1 || true
	@docker run --name gogo-postgres \
		--env POSTGRES_USER=$(PG_USER) \
		--env POSTGRES_PASSWORD=$(PG_PASS) \
		--env POSTGRES_DB=$(PG_DB) \
		--env PG_DATA=$(PG_DATA) \
		--detach \
		--volume $(HOME)/data/gogo:$(PG_DATA) \
		$(PG_DOCKER_IMAGE):$(PG_DOCKER_TAG) > /dev/null

	@echo "Waiting for Postgres to be ready."
	@while true; do \
		docker exec gogo-postgres pg_isready -U $(PG_USER) -d $(PG_DB) --quiet && break; \
		sleep 1; \
	done
	@echo "Waiting for $(PG_USER) role to exist."
	@while true; do \
		COMMAND="SELECT 1" $(MAKE) db-run-command > /dev/null 2>&1 && break; \
		sleep 1; \
	done
	@$(MAKE) db-apply-schema

db-truncate:
	@echo "Truncating database."
	@COMMAND='TRUNCATE shortcut;' $(MAKE) db-run-command

db-wipe:
	@echo "Wiping database."
	@docker exec gogo-postgres dropdb -U $(PG_USER) $(PG_DB)
	@docker exec gogo-postgres createdb -U $(PG_USER) $(PG_DB)

psql:
	@docker exec -it gogo-postgres psql \
		-U $(PG_USER) \
		-d $(PG_DB)

db-run-command:
	@docker exec gogo-postgres psql \
		-U $(PG_USER) \
		-d $(PG_DB) \
		-c "$$COMMAND"

db-run-file:
	@docker cp $$SQL_FILE gogo-postgres:/sql_file.sql
	@docker exec gogo-postgres psql \
		-f /sql_file.sql \
		-U $(PG_USER) \
		-d $(PG_DB)

db-apply-schema:
	@if COMMAND='\d' $(MAKE) db-run-command | grep 'row' > /dev/null; then \
		echo "Schema already applied. Use 'make db-wipe' to reset all data."; \
	else \
		echo "Applying schema."; \
		SQL_FILE=schema/schema.sql $(MAKE) db-run-file; \
	fi

###############################################################################
# Development Environment Setup
###############################################################################
.PHONY: venv
venv: $(VENV_DIR)

$(VENV_BIN)/activate:
	$(VENV_CMD) $(VENV_DIR)

$(VENV_DIR): $(VENV_BIN)/activate resources/requirements.txt resources/requirements.dev.txt
	$(VENV_BIN)/python -m pip install -U pip setuptools wheel
#	$(VENV_BIN)/pip install -Ur resources/requirements.dev.txt
	$(VENV_BIN)/pip install -Ur resources/requirements.txt && touch $(VENV_DIR)
