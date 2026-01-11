#!/bin/bash

# Decode and analyze the driver JWT token

DRIVER_POOL_ID="us-east-1_Mnrmklxro"
DRIVER_CLIENT_ID="4dkt45gole08kurh0o43rvk8q7"
PHONE="+9640431874668"
PASSWORD="Moh@1985"

echo "========================================="
echo "🔍 Driver Token Analysis"
echo "========================================="

# Get token
RESPONSE=$(aws cognito-idp initiate-auth \
    --region us-east-1 \
    --auth-flow USER_PASSWORD_AUTH \
    --client-id $DRIVER_CLIENT_ID \
    --auth-parameters USERNAME=$PHONE,PASSWORD=$PASSWORD \
    2>&1)

if ! echo "$RESPONSE" | grep -q "AuthenticationResult"; then
    echo "❌ Authentication failed"
    exit 1
fi

ACCESS_TOKEN=$(echo $RESPONSE | jq -r '.AuthenticationResult.AccessToken')
ID_TOKEN=$(echo $RESPONSE | jq -r '.AuthenticationResult.IdToken')

echo ""
echo "✅ Authentication successful"
echo ""
echo "========================================="
echo "📋 Access Token Payload:"
echo "========================================="

# Decode access token (JWT is base64 encoded)
PAYLOAD=$(echo $ACCESS_TOKEN | cut -d. -f2)
# Add padding if needed
PADDING=$((4 - ${#PAYLOAD} % 4))
if [ $PADDING -ne 4 ]; then
    PAYLOAD="${PAYLOAD}$(printf '=%.0s' $(seq 1 $PADDING))"
fi

echo "$PAYLOAD" | base64 -d 2>/dev/null | jq '.'

echo ""
echo "========================================="
echo "📋 ID Token Payload:"
echo "========================================="

PAYLOAD=$(echo $ID_TOKEN | cut -d. -f2)
PADDING=$((4 - ${#PAYLOAD} % 4))
if [ $PADDING -ne 4 ]; then
    PAYLOAD="${PAYLOAD}$(printf '=%.0s' $(seq 1 $PADDING))"
fi

echo "$PAYLOAD" | base64 -d 2>/dev/null | jq '.'

echo ""
echo "========================================="
echo "🔑 Key Token Info:"
echo "========================================="

echo "$PAYLOAD" | base64 -d 2>/dev/null | jq -r '
"Username: \(.["cognito:username"] // .sub)
Email: \(.email // "N/A")
Phone: \(.phone_number // "N/A")
Token Use: \(.token_use // "N/A")
Client ID: \(.client_id // .aud)
ISS: \(.iss)
Custom Attributes: \(to_entries | map(select(.key | startswith("custom:"))) | from_entries)"
'

echo ""
echo "========================================="
echo "📝 Expected vs Actual:"
echo "========================================="
echo "Driver Pool ID: $DRIVER_POOL_ID"
echo "Expected ISS: https://cognito-idp.us-east-1.amazonaws.com/$DRIVER_POOL_ID"
echo ""
echo "Actual ISS from token:"
echo "$PAYLOAD" | base64 -d 2>/dev/null | jq -r '.iss'
