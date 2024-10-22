FROM python:3.12-alpine3.19

RUN apk add nginx jq openssl libpq-dev build-base bash

# Generate SSL certs.
RUN mkdir -p /app/ssl && cd /app/ssl && \
    openssl req -x509 -nodes -newkey rsa:4096 -sha256 \
                -keyout privkey.pem -out fullchain.pem \
                -days 36500 -subj '/CN=gogo' && \
    openssl dhparam -dsaparam -out dhparam.pem 4096

# Set up gogo.
ADD resources/requirements.txt /app/resources/requirements.txt
RUN pip install setuptools
RUN pip install -r /app/resources/requirements.txt && pip freeze

ADD resources /app/resources/
ADD static /app/static/
ADD templates /app/templates/
ADD src /app/src/

EXPOSE 80 443 5000
ENTRYPOINT ["/app/resources/entrypoint.sh"]
