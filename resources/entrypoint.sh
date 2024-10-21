#!/bin/bash

set -e

export CONFIG=${CONFIG:-ProductionConfig}
export TITLE=${TITLE:-GoGo}
export DISABLE_NGINX=${DISABLE_NGINX:-}
export SKIP_AUTH=${SKIP_AUTH:-false}

kms_decrypt() {
    python -c 'import sys
import base64
import boto3
blob = sys.argv[1];
binary_data = base64.b64decode(sys.argv[1])
session = boto3.session.Session()
client = session.client("kms")
print(client.decrypt(CiphertextBlob=binary_data)["Plaintext"].decode())
' "$1"
}

if [ -n "$DATABASE_URI_KMS" ]; then
  DATABASE_URI=$(kms_decrypt "$DATABASE_URI_KMS") || exit 1
  export DATABASE_URI
fi

if [ -z "${DATABASE_URI}" ]; then
  echo "DATABASE_URI_KMS/DATABASE_URI must be set."
  exit 1
fi

if [ -z "$AUTH_HEADER_NAME" ] && [ "$SKIP_AUTH" == "false" ]; then
    # Using Built-In Google OAuth.
    echo "AUTH_HEADER_NAME not set. Configuring Google OAuth."

    if [ -z "$GOOGLE_CLIENT_ID" ]; then
        echo "GOOGLE_CLIENT_ID must be set."
        exit 1
    fi

    if [ -z "$HOSTED_DOMAIN" ]; then
        echo "HOSTED_DOMAIN must be set."
        exit 1
    fi

    if [ -n "$GOOGLE_CLIENT_SECRET_KMS_BLOB" ]; then
      GOOGLE_CLIENT_SECRET=$(kms_decrypt "$GOOGLE_CLIENT_SECRET_KMS_BLOB")
    fi

    if [ -z "$GOOGLE_CLIENT_SECRET" ]; then
        echo "Either GOOGLE_CLIENT_SECRET or GOOGLE_CLIENT_SECRET_KMS_BLOB must be set."
        exit 1
    fi

    sed -e "s/{client_id}/${GOOGLE_CLIENT_ID}/g" -i /app/resources/client_secrets.json
    sed -e "s/{client_secret}/${GOOGLE_CLIENT_SECRET}/g" -i /app/resources/client_secrets.json
    sed -e "s/{hosted_domain}/${HOSTED_DOMAIN}/g" -i /app/resources/client_secrets.json

    export REDIRECT_URI=${BASE_URL}/oauth2/callback

    # Using # as the separator to handle / in the uri.
    sed -e "s#{redirect_uri}#${REDIRECT_URI}#g" \
        -i /app/resources/client_secrets.json

    if [ -n "$SESSION_SECRET_KEY_KMS_BLOB" ]; then
      SESSION_SECRET_KEY=$(kms_decrypt "$SESSION_SECRET_KEY_KMS_BLOB")
    fi
    export SESSION_SECRET_KEY

    if [ -z "$SESSION_SECRET_KEY" ]; then
      echo "Either SESSION_SECRET_KEY or SESSION_SECRET_KEY_KMS_BLOB must be set."
      exit 1
    fi
fi

test -z "${DISABLE_NGINX}" && /usr/sbin/nginx -c /app/resources/nginx.conf &

export APP_SETTINGS="config.${CONFIG}"

python /app/src/app.py
