FROM python:3.13-alpine3.20

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

RUN apk add nginx jq openssl libpq-dev build-base bash

# Generate SSL certs.
RUN mkdir -p /app/ssl && cd /app/ssl && \
    openssl req -x509 -nodes -newkey rsa:4096 -sha256 \
                -keyout privkey.pem -out fullchain.pem \
                -days 36500 -subj '/CN=gogo' && \
    openssl dhparam -dsaparam -out dhparam.pem 4096

# Install dependencies using uv.
COPY pyproject.toml uv.lock /app/
WORKDIR /app
RUN uv sync --frozen --no-dev

ADD resources /app/resources/
ADD static /app/static/
ADD templates /app/templates/
ADD src /app/src/

ENV PATH="/app/.venv/bin:$PATH"

EXPOSE 80 443 5000
ENTRYPOINT ["/app/resources/entrypoint.sh"]
