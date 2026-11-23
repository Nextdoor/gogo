FROM python:3.14-alpine3.22

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

RUN apk add jq openssl libpq-dev build-base bash

# nginx from the upstream nginx.org stable channel; Alpine's package lags. Must be >= 1.30.7.
ARG NGINX_VERSION=1.30.7-r1
RUN wget -qO /etc/apk/keys/nginx_signing.rsa.pub https://nginx.org/keys/nginx_signing.rsa.pub && \
    echo "@nginx https://nginx.org/packages/alpine/v$(cut -d. -f1,2 /etc/alpine-release)/main" >> /etc/apk/repositories && \
    apk add --no-cache "nginx@nginx=${NGINX_VERSION}" && \
    nginx -v

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
