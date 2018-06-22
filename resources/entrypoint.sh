#!/bin/bash -e

REQUIRED_VARS="CONFIG DATABASE_HOST BASE_URL GOOGLE_CLIENT_ID HOSTED_DOMAIN"

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

if [[ -n "$GOOGLE_CLIENT_SECRET" ]]; then
    client_secret=$GOOGLE_CLIENT_SECRET
elif [[ -n "$GOOGLE_CLIENT_SECRET_KMS_BLOB" ]]; then
    client_secret=$(kms_decrypt $GOOGLE_CLIENT_SECRET_KMS_BLOB)
else
    echo "Either GOOGLE_CLIENT_SECRET or GOOGLE_CLIENT_SECRET_KMS_BLOB must be set."
    exit 1
fi

sed -e "s/{client_secret.kms}/${client_secret}/g" \
    -i /app/resources/client_secrets.json

export REDIRECT_URI=${BASE_URL}/oauth2/callback
# Using # as the separator to handle / in the uri.
sed -e "s#{redirect_uri}#${REDIRECT_URI}#g" \
    -i /app/resources/client_secrets.json
sed -e "s#{base_url}#${BASE_URL}#g" \
    -i /app/resources/nginx.conf

/usr/sbin/nginx -c /app/resources/nginx.conf -p /app/ &

export APP_SETTINGS="config.${CONFIG}"
export DATABASE_URI="postgresql://gogo:gogo@${DATABASE_HOST}/gogo"

if [[ -n "$SESSION_SECRET_KEY" ]]; then
    export SESSION_SECRET_KEY=$SESSION_SECRET_KEY
elif [[ -n "$SESSION_SECRET_KEY_KMS_BLOB" ]]; then
    export SESSION_SECRET_KEY=$(kms_decrypt $SESSION_SECRET_KEY_KMS_BLOB)
else
    echo "Either SESSION_SECRET_KEY or SESSION_SECRET_KEY_KMS_BLOB must be set."
    exit 1
fi

python /app/src/app.py
