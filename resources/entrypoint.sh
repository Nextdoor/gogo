#!/bin/bash -e

REQUIRED_VARS="CONFIG DATABASE_URI BASE_URL TITLE"

EXIT=0
for VAR in $REQUIRED_VARS; do
    if [[ -z "$(eval echo "\$${VAR}")" ]]; then
        EXIT=1
        echo "Missing $VAR." >&2
    fi
done
if [[ "$EXIT" -eq 1 ]]; then
    exit 1
fi

kms_decrypt() {
    python -c 'import sys
import base64
import boto3
blob = sys.argv[1];
binary_data = base64.b64decode(sys.argv[1])
session = boto3.session.Session()
client = session.client("kms")
print(client.decrypt(CiphertextBlob=binary_data)["Plaintext"].decode())
' $1
}

if [[ -z "$AUTH_HEADER_NAME" ]]; then
    # Using Built-In Google OAuth.
    echo "AUTH_HEADER_NAME not set. Configuring Google OAuth."

    if [[ -z "$GOOGLE_CLIENT_ID" ]]; then
        echo "GOOGLE_CLIENT_ID must be set."
        exit 1
    fi

    if [[ -z "$HOSTED_DOMAIN" ]]; then
        echo "HOSTED_DOMAIN must be set."
        exit 1
    fi

    if [[ -n "$DATABASE_URI_KMS" ]]; then
        export DATABASE_URI=$(kms_decrypt $DATABASE_URI_KMS)
    else
        echo "DATABASE_URI_KMS must be set."
        exit 1
    fi

    if [[ -n "$GOOGLE_CLIENT_SECRET" ]]; then
        client_secret=$GOOGLE_CLIENT_SECRET
    elif [[ -n "$GOOGLE_CLIENT_SECRET_KMS_BLOB" ]]; then
        client_secret=$(kms_decrypt $GOOGLE_CLIENT_SECRET_KMS_BLOB)
    else
        echo "Either GOOGLE_CLIENT_SECRET or GOOGLE_CLIENT_SECRET_KMS_BLOB must be set."
        exit 1
    fi

    sed -e "s/{client_id}/${GOOGLE_CLIENT_ID}/g" \
        -i /app/resources/client_secrets.json
    sed -e "s/{client_secret}/${client_secret}/g" \
        -i /app/resources/client_secrets.json
    sed -e "s/{hosted_domain}/${HOSTED_DOMAIN}/g" \
        -i /app/resources/client_secrets.json

    export REDIRECT_URI=${BASE_URL}/oauth2/callback
    # Using # as the separator to handle / in the uri.
    sed -e "s#{redirect_uri}#${REDIRECT_URI}#g" \
        -i /app/resources/client_secrets.json

    if [[ -n "$SESSION_SECRET_KEY" ]]; then
        export SESSION_SECRET_KEY=$SESSION_SECRET_KEY
    elif [[ -n "$SESSION_SECRET_KEY_KMS_BLOB" ]]; then
        export SESSION_SECRET_KEY=$(kms_decrypt $SESSION_SECRET_KEY_KMS_BLOB)
    else
        echo "Either SESSION_SECRET_KEY or SESSION_SECRET_KEY_KMS_BLOB must be set."
        exit 1
    fi
fi

sed -e "s#{base_url}#${BASE_URL}#g" \
    -i /app/resources/nginx.conf

/usr/sbin/nginx -c /app/resources/nginx.conf -p /app/ &

export APP_SETTINGS="config.${CONFIG}"

python /app/src/app.py
