#!/usr/bin/env bash
set -euo pipefail

REGION="${AWS_REGION:-${REGION:-us-east-1}}"
PROFILE="${AWS_PROFILE:-${PROFILE:-Wizz_stg_UserApp}}"

DRIVER_ID="${DRIVER_ID:-}"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <HOLD_ID...>"
  echo "Optional env vars: DRIVER_ID, REGION/AWS_REGION, PROFILE/AWS_PROFILE"
  exit 2
fi

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 3
  }
}

need aws
need python3
need curl

SSM_WALLET_URL_PARAM="${SSM_WALLET_URL_PARAM:-/whizz/stg/wallet-service/url}"
SSM_SERVICE_CLIENT_ID_PARAM="${SSM_SERVICE_CLIENT_ID_PARAM:-/whizz/stg/order-service/service-client-id}"
SSM_SERVICE_CLIENT_SECRET_PARAM="${SSM_SERVICE_CLIENT_SECRET_PARAM:-/whizz/stg/order-service/service-client-secret}"
SSM_SERVICE_USERNAME_PARAM="${SSM_SERVICE_USERNAME_PARAM:-/whizz/stg/order-service/service-username}"
SSM_SERVICE_PASSWORD_PARAM="${SSM_SERVICE_PASSWORD_PARAM:-/whizz/stg/order-service/service-password}"

get_ssm() {
  local name="$1"
  aws ssm get-parameter \
    --name "$name" \
    --with-decryption \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query 'Parameter.Value' \
    --output text
}

WALLET_URL="$(get_ssm "$SSM_WALLET_URL_PARAM")"
CLIENT_ID="$(get_ssm "$SSM_SERVICE_CLIENT_ID_PARAM")"
CLIENT_SECRET="$(get_ssm "$SSM_SERVICE_CLIENT_SECRET_PARAM")"
USERNAME="$(get_ssm "$SSM_SERVICE_USERNAME_PARAM")"
PASSWORD="$(get_ssm "$SSM_SERVICE_PASSWORD_PARAM")"

export CLIENT_ID CLIENT_SECRET USERNAME
SECRET_HASH="$(python3 - <<'PY'
import base64, hashlib, hmac, os
msg = os.environ['USERNAME'] + os.environ['CLIENT_ID']
dig = hmac.new(os.environ['CLIENT_SECRET'].encode('utf-8'), msg.encode('utf-8'), hashlib.sha256).digest()
print(base64.b64encode(dig).decode('utf-8'))
PY
)"

TOKEN="$(
  aws cognito-idp initiate-auth \
    --auth-flow USER_PASSWORD_AUTH \
    --client-id "$CLIENT_ID" \
    --auth-parameters "USERNAME=$USERNAME,PASSWORD=$PASSWORD,SECRET_HASH=$SECRET_HASH" \
    --region "$REGION" \
    --profile "$PROFILE" \
    --output json \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["AuthenticationResult"]["AccessToken"])'
)"

HAS_JQ=0
if command -v jq >/dev/null 2>&1; then
  HAS_JQ=1
fi

echo "Wallet URL: $WALLET_URL"
echo "Releasing hold(s): $*"

for HID in "$@"; do
  echo "- Releasing $HID"
  RESP="$(
    curl -sS -X POST "$WALLET_URL/wallet/hold/$HID/release" \
      -H "Authorization: Bearer $TOKEN" \
      -H 'Content-Type: application/json' \
      --data '{"reason":"cleanup orphan hold (drivers accept retry)"}'
  )"

  if [[ $HAS_JQ -eq 1 ]]; then
    echo "$RESP" | jq '{success,message,error,code,data}'
  else
    echo "$RESP"
  fi

done

if [[ -n "$DRIVER_ID" ]]; then
  echo "\nRe-checking ACTIVE holds in DynamoDB for DRIVER_ID=$DRIVER_ID …"
  OUT="$(
    aws dynamodb scan --table-name staging-Holds --region "$REGION" --profile "$PROFILE" \
      --filter-expression 'walletId = :wid AND #st = :active' \
      --expression-attribute-names '{"#st":"status"}' \
      --expression-attribute-values "{\":wid\":{\"S\":\"WALLET#DRIVER#${DRIVER_ID}\"},\":active\":{\"S\":\"ACTIVE\"}}" \
      --projection-expression 'holdId,orderId,amount,#st,createdAt,updatedAt' \
      --max-items 25 --output json
  )"
  if [[ $HAS_JQ -eq 1 ]]; then
    echo "$OUT" | jq '{Count,Items}'
  else
    echo "$OUT"
  fi
fi
