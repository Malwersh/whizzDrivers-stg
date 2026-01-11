#!/usr/bin/env bash
set -euo pipefail

STACK_NAME="Drivers-Tables-staging"
REGION="us-east-1"
PROFILE="Wizz_stg_UserApp"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/drivers-tables-stack.yaml"

aws cloudformation deploy \
  --stack-name "$STACK_NAME" \
  --template-file "$TEMPLATE_FILE" \
  --parameter-overrides Environment=staging \
  --region "$REGION" \
  --profile "$PROFILE" \
  --no-fail-on-empty-changeset

echo "\nOutputs:"
aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --profile "$PROFILE" \
  --query 'Stacks[0].Outputs[].{Key:OutputKey,Value:OutputValue}' \
  --output table
