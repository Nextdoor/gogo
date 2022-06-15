SHA1 := $(shell git rev-parse --short HEAD)

DOCKER_IMAGE ?= gogo
DOCKER_TAG ?= latest

DOCKER_BUILD_ARGS := -t $(DOCKER_IMAGE)

ifdef CACHE_FROM
DOCKER_BUILD_ARGS := --cache-from $(CACHE_FROM) $(DOCKER_BUILD_ARGS)
endif

define DOCKER_RUN_ARGS
--name $(DOCKER_IMAGE) \
--publish 80:80 \
--env CONFIG=DevelopmentConfig \
--env DATABASE_URI_KMS=$(DATABASE_URI_KMS) \
--env BASE_URL=http://localhost \
--env-file envfile \
--hostname gogo-dev \
--volume $(HOME)/.aws:/root/.aws \
--link gogo-postgres \
-it
endef

.PHONY: run stop test venv

run: stop
	@touch envfile
	@docker ps | grep gogo-postgres > /dev/null || $(MAKE) db
	@docker run $(DOCKER_RUN_ARGS) $(DOCKER_IMAGE)

stop:
	@docker rm -f $(DOCKER_IMAGE) > /dev/null 2>&1 || true

test: stop
	@touch envfile
	@echo "Testing $(DOCKER_IMAGE)"
	@docker run $$ARGS $$INTERACTIVE_ARGS --entrypoint sh \
		"$(DOCKER_IMAGE)" \
		-c "cd /app/src/ && PYTHONPATH=. pytest $$TEST_ARGS --cov"

venv:
	@echo "Creating and updating venv."
	@python3 -m venv .venv
	@if [ "$$(cat resources/requirements.txt | sort)" != "$$(.venv/bin/pip freeze)" ]; then \
		.venv/bin/pip install -Ur resources/requirements.txt; \
	fi

# Database.

PGDB=gogo
PGHOST=localhost
PGPORT=5432
PGUSER=gogo
PGPASS=changeme # for dev only. Prod password is encrypted in KMS via DATABASE_URI_KMS
PGDATA=/var/lib/postgresql/data/gogo

define PG_ARGS
--name gogo-postgres \
--env POSTGRES_USER=$(PGUSER) \
--env POSTGRES_PASSWORD=$(PGPASS) \
--env POSTGRES_DB=$(PGDB) \
--env PGDATA=$(PGDATA) \
--volume $(HOME)/data/gogo:$(PGDATA) \
--detach
endef

export PG_ARGS

.PHONY: db db-truncate db-wipe psql db-run-command db-run-file db-apply-schema

db:
	@echo "Launching Postgres."
	@docker rm -f gogo-postgres > /dev/null 2>&1 || true
	@docker run $$PG_ARGS postgres:10.0 > /dev/null
	@echo "Waiting for Postgres to be ready."
	@while true; do \
		docker exec gogo-postgres pg_isready -U $(PGUSER) -d $(PGDB) --quiet && break; \
		sleep 1; \
	done
	@echo "Waiting for $(PGUSER) role to exist."
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
	@docker exec gogo-postgres dropdb -U $(PGUSER) $(PGDB)
	@docker exec gogo-postgres createdb -U $(PGUSER) $(PGDB)

psql:
	@docker exec -it gogo-postgres psql \
		-U $(PGUSER) \
		-d $(PGDB)

db-run-command:
	@docker exec gogo-postgres psql \
		-U $(PGUSER) \
		-d $(PGDB) \
		-c "$$COMMAND"

db-run-file:
	@docker cp $$SQL_FILE gogo-postgres:/sql_file.sql
	@docker exec gogo-postgres psql \
		-f /sql_file.sql \
		-U $(PGUSER) \
		-d $(PGDB)

db-apply-schema:
	@if COMMAND='\d' $(MAKE) db-run-command | grep 'row' > /dev/null; then \
		echo "Schema already applied. Use 'make db-wipe' to reset all data."; \
	else \
		echo "Applying schema."; \
		SQL_FILE=schema/schema.sql $(MAKE) db-run-file; \
	fi
