FROM python:3.6.5-stretch

# Env var to force update of the image. Increment for each time this is needed
ENV CACHE_BUSTER_VAR=1

RUN apt-get update && \
    apt-get install -y nginx jq && \
    apt-get autoclean && \
    rm -rf /var/lib/apt/cache

# Generate SSL certs.
RUN mkdir -p /app/ssl && cd /app/ssl && \
    openssl req -x509 -nodes -newkey rsa:4096 -sha256 \
                -keyout privkey.pem -out fullchain.pem \
                -days 36500 -subj '/CN=gogo' && \
    openssl dhparam -dsaparam -out dhparam.pem 4096

# Set up gogo.
ADD resources/requirements.txt /app/resources/requirements.txt
RUN pip install -r /app/resources/requirements.txt && pip freeze

ADD resources /app/resources/
ADD static /app/static/
ADD templates /app/templates/
ADD src /app/src/

EXPOSE 80 443 5000
ENTRYPOINT ["/app/resources/entrypoint.sh"]
