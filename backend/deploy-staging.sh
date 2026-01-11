#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-staging}"
REGION="${AWS_REGION:-us-east-1}"
PROFILE="${AWS_PROFILE:-Wizz_stg_UserApp}"

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

get_export() {
  local export_name="$1"
  aws cloudformation list-exports \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query "Exports[?Name=='${export_name}'].Value | [0]" \
    --output text
}

WALLET_SERVICE_URL="${WALLET_SERVICE_URL:-$(get_ssm "$SSM_WALLET_URL_PARAM")}"
ORDER_SERVICE_URL="${ORDER_SERVICE_URL:-$(get_export "OrderServiceApiUrl-${ENVIRONMENT}")}" 

SERVICE_CLIENT_ID="${SERVICE_CLIENT_ID:-$(get_ssm "$SSM_SERVICE_CLIENT_ID_PARAM")}"
SERVICE_CLIENT_SECRET="${SERVICE_CLIENT_SECRET:-$(get_ssm "$SSM_SERVICE_CLIENT_SECRET_PARAM")}"
SERVICE_USERNAME="${SERVICE_USERNAME:-$(get_ssm "$SSM_SERVICE_USERNAME_PARAM")}"
SERVICE_PASSWORD="${SERVICE_PASSWORD:-$(get_ssm "$SSM_SERVICE_PASSWORD_PARAM")}"

WEBSOCKET_CONNECTIONS_TABLE_NAME="${WEBSOCKET_CONNECTIONS_TABLE_NAME:-WizzUser_websocket_connections_staging}"
DISPATCH_JOBS_TABLE_NAME="${DISPATCH_JOBS_TABLE_NAME:-}"

# WaveSystem not deployed in staging yet; keep disabled by default.
WAVESYSTEM_ACCEPT_FUNCTION_NAME="${WAVESYSTEM_ACCEPT_FUNCTION_NAME:-}"
WAVESYSTEM_REJECT_FUNCTION_NAME="${WAVESYSTEM_REJECT_FUNCTION_NAME:-}"

if [[ -z "${WAVESYSTEM_ACCEPT_FUNCTION_NAME}" ]]; then
  candidate="$(get_export "WaveSystem-Functions-${ENVIRONMENT}-HandleDriverAcceptFunctionName" || true)"
  if [[ -n "${candidate}" && "${candidate}" != "None" && "${candidate}" != "null" ]]; then
    WAVESYSTEM_ACCEPT_FUNCTION_NAME="${candidate}"
  fi
fi

if [[ -z "${WAVESYSTEM_REJECT_FUNCTION_NAME}" ]]; then
  candidate="$(get_export "WaveSystem-Functions-${ENVIRONMENT}-HandleDriverRejectFunctionName" || true)"
  if [[ -n "${candidate}" && "${candidate}" != "None" && "${candidate}" != "null" ]]; then
    WAVESYSTEM_REJECT_FUNCTION_NAME="${candidate}"
  fi
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🚀 Deploying Drivers API (${ENVIRONMENT})"
echo "- Region: $REGION"
echo "- Profile: $PROFILE"
echo "- WalletServiceUrl: $WALLET_SERVICE_URL"
echo "- OrderServiceUrl:  $ORDER_SERVICE_URL"

sam build

PARAMS=(
  "Environment=$ENVIRONMENT"
  "WalletServiceUrl=$WALLET_SERVICE_URL"
  "OrderServiceUrl=$ORDER_SERVICE_URL"
  "ServiceClientId=$SERVICE_CLIENT_ID"
  "ServiceClientSecret=$SERVICE_CLIENT_SECRET"
  "ServiceUsername=$SERVICE_USERNAME"
  "ServicePassword=$SERVICE_PASSWORD"
  "WebsocketConnectionsTableName=$WEBSOCKET_CONNECTIONS_TABLE_NAME"
)

if [[ -n "${DISPATCH_JOBS_TABLE_NAME}" ]]; then
  PARAMS+=("DispatchJobsTableName=$DISPATCH_JOBS_TABLE_NAME")
fi

if [[ -n "${WAVESYSTEM_ACCEPT_FUNCTION_NAME}" ]]; then
  PARAMS+=("WaveSystemHandleDriverAcceptFunctionName=$WAVESYSTEM_ACCEPT_FUNCTION_NAME")
fi

if [[ -n "${WAVESYSTEM_REJECT_FUNCTION_NAME}" ]]; then
  PARAMS+=("WaveSystemHandleDriverRejectFunctionName=$WAVESYSTEM_REJECT_FUNCTION_NAME")
fi

sam deploy \
  --config-file samconfig.toml \
  --config-env staging \
  --region "$REGION" \
  --profile "$PROFILE" \
  --parameter-overrides "${PARAMS[@]}"

rc=$?
if [[ $rc -ne 0 ]]; then
  # SAM returns exit code 1 when the stack is already up to date.
  # Treat that as success to keep CI/manual runs smooth.
  if sam deploy \
    --config-file samconfig.toml \
    --config-env staging \
    --region "$REGION" \
    --profile "$PROFILE" \
    --parameter-overrides "${PARAMS[@]}" 2>&1 | grep -q "No changes to deploy"; then
    echo "ℹ️ No changes to deploy. Stack is up to date."
    rc=0
  fi
fi

exit $rc

echo "✅ Done. Useful commands:"
echo "- API URL export: DriversApiUrl-${ENVIRONMENT}"
