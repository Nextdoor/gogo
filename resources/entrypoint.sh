#!/bin/bash

set -e

# Basic Config
export CONFIG=${CONFIG:-ProductionConfig}
export TITLE=${TITLE:-GoGo}

# Short Circuits
export DISABLE_NGINX=${DISABLE_NGINX:-}
export SKIP_AUTH=${SKIP_AUTH:-false}

# KMS Helper
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

##############################
# Database URI Configuration #
##############################
if [ -n "${DATABASE_URI_KMS_BLOB}" ]; then
  if [ -n "${DATABASE_URI}" ]; then
    echo "Warning: DATABASE_URI_KMS_BLOB and DATABASE_URI are mutually exclusive. Overwriting DATABASE_URI."
  fi
  DATABASE_URI=$(kms_decrypt "${DATABASE_URI_KMS_BLOB}") \
    || echo "Error: Failed to decrypt DATABASE_URI_KMS_BLOB." && exit 1
  export DATABASE_URI
fi

if [ -z "${DATABASE_URI}" ]; then
  echo "Error: DATABASE_URI_KMS_BLOB or DATABASE_URI must be set."
  exit 1
fi

################################
# Authentication Configuration #
################################
if [ "${SKIP_AUTH}" == "true" ]; then
  echo "Warning: SKIP_AUTH is set. Skipping authentication configuration."
else
  if [ -n "${AUTH_HEADER_NAME}" ]; then
    # Header Auth
    echo "Info: AUTH_HEADER_NAME is set. Configuring header auth."
  else
    # Google OAuth
    echo "Info: AUTH_HEADER_NAME not set. Configuring Google OAuth."

    #########################
    # Google Client Secrets #
    #########################
    if [ -z "${GOOGLE_CLIENT_ID}" ]; then
      echo "Error: GOOGLE_CLIENT_ID must be set."
      exit 1
    fi

    if [ -n "${GOOGLE_CLIENT_SECRET_KMS_BLOB}" ]; then
      GOOGLE_CLIENT_SECRET=$(kms_decrypt "${GOOGLE_CLIENT_SECRET_KMS_BLOB}") \
        || echo "Error: Failed to decrypt GOOGLE_CLIENT_SECRET_KMS_BLOB." && exit 1
    fi

    if [ -z "${GOOGLE_CLIENT_SECRET}" ]; then
      echo "Error: GOOGLE_CLIENT_SECRET_KMS_BLOB or GOOGLE_CLIENT_SECRET must be set."
      exit 1
    fi

    if [ -z "${HOSTED_DOMAIN}" ]; then
      echo "Error: HOSTED_DOMAIN must be set."
      exit 1
    fi

    ######################
    # Session Secret Key #
    ######################
    if [ -n "${SESSION_SECRET_KEY_KMS_BLOB}" ]; then
      SESSION_SECRET_KEY=$(kms_decrypt "${SESSION_SECRET_KEY_KMS_BLOB}") \
        || echo "Error: Failed to decrypt SESSION_SECRET_KEY_KMS_BLOB." && exit 1
      export SESSION_SECRET_KEY
    fi

    if [ -z "${SESSION_SECRET_KEY}" ]; then
      echo "Error: SESSION_SECRET_KEY_KMS_BLOB or SESSION_SECRET_KEY must be set."
      exit 1
    fi

    ##########################
    # Configure Google OAuth #
    ##########################
    sed -e "s/{client_id}/${GOOGLE_CLIENT_ID}/g" -i /app/resources/client_secrets.json
    sed -e "s/{client_secret}/${GOOGLE_CLIENT_SECRET}/g" -i /app/resources/client_secrets.json
    sed -e "s/{hosted_domain}/${HOSTED_DOMAIN}/g" -i /app/resources/client_secrets.json
    export REDIRECT_URI=${BASE_URL}/oauth2/callback
    # Using # as the separator to handle / in the uri.
    sed -e "s#{redirect_uri}#${REDIRECT_URI}#g" -i /app/resources/client_secrets.json
  fi
fi

# Finally run some processes :)
test -z "${DISABLE_NGINX}" && /usr/sbin/nginx -c /app/resources/nginx.conf -p /app/ &

export APP_SETTINGS="config.${CONFIG}"

python /app/src/app.py
