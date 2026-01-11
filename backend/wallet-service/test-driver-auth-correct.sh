#!/bin/bash

# Test Driver Authentication - استراتيجية مزدوجة
# التطبيق يحاول أولاً بالـ email، إذا فشل يحول إلى رقم هاتف مولّد

DRIVER_POOL_ID="us-east-1_Mnrmklxro"
DRIVER_CLIENT_ID="4dkt45gole08kurh0o43rvk8q7"
REGION="us-east-1"

# Driver credentials (provide via env vars; do not hardcode secrets)
EMAIL="${EMAIL:-}"
PHONE="${PHONE:-}"
PASSWORD="${PASSWORD:-}"

# Wallet API base URL (provide via env var; do not hardcode /dev)
API_URL="${API_URL:-}"

if [ -z "$EMAIL" ] || [ -z "$PASSWORD" ]; then
    echo "❌ Missing required env vars: EMAIL and PASSWORD"
    echo "Example: EMAIL=user@example.com PASSWORD=... API_URL=https://.../stg ./test-driver-auth-correct.sh"
    exit 1
fi

if [ -z "$API_URL" ]; then
    echo "❌ Missing required env var: API_URL"
    echo "Set API_URL to the Wallet API base URL for staging (no /dev)."
    exit 1
fi

echo "========================================="
echo "🔐 Driver Authentication Test - Dual Strategy"
echo "========================================="
echo ""

# Generate phone from email hash (same logic as app)
generate_phone_from_email() {
    local email=$1
    # Simple hash implementation in bash (not perfect match but for testing)
    local hash=$(echo -n "$email" | md5 | tr -d 'a-f' | tr -d '\n' | head -c 10)
    echo "+964${hash}"
}

GENERATED_PHONE=$(generate_phone_from_email "$EMAIL")

echo "📧 Email: $EMAIL"
echo "📱 Real Phone: $PHONE"
echo "🔢 Generated Phone (from email hash): $GENERATED_PHONE"
echo ""

# Strategy 1: Try with email directly
echo "========================================="
echo "Strategy 1: Direct Email Login"
echo "========================================="
echo "Testing: $EMAIL"

RESPONSE=$(aws cognito-idp initiate-auth \
    --region $REGION \
    --auth-flow USER_PASSWORD_AUTH \
    --client-id $DRIVER_CLIENT_ID \
    --auth-parameters USERNAME=$EMAIL,PASSWORD=$PASSWORD \
    2>&1)

if echo "$RESPONSE" | grep -q "AuthenticationResult"; then
    echo "✅ Strategy 1 SUCCESS: Email login worked!"
    TOKEN=$(echo $RESPONSE | jq -r '.AuthenticationResult.AccessToken')
    echo ""
    echo "🎫 Access Token (first 50 chars): ${TOKEN:0:50}..."
    echo ""
    
    # Test API call
    echo "Testing API call to Wallet Service..."
    
    WALLET_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
        -X GET "$API_URL/wallet/my-wallet" \
        -H "Authorization: Bearer $TOKEN")
    
    HTTP_STATUS=$(echo "$WALLET_RESPONSE" | grep "HTTP_STATUS" | cut -d: -f2)
    BODY=$(echo "$WALLET_RESPONSE" | sed '/HTTP_STATUS/d')
    
    echo "HTTP Status: $HTTP_STATUS"
    echo "Response: $BODY"
    
    if [ "$HTTP_STATUS" == "200" ]; then
        echo "✅ API call successful!"
    else
        echo "❌ API call failed with status $HTTP_STATUS"
    fi
    
    exit 0
else
    echo "❌ Strategy 1 FAILED: $RESPONSE"
fi

echo ""
echo "========================================="
echo "Strategy 2: Real Phone Number"
echo "========================================="
echo "Testing: $PHONE"

RESPONSE=$(aws cognito-idp initiate-auth \
    --region $REGION \
    --auth-flow USER_PASSWORD_AUTH \
    --client-id $DRIVER_CLIENT_ID \
    --auth-parameters USERNAME=$PHONE,PASSWORD=$PASSWORD \
    2>&1)

if echo "$RESPONSE" | grep -q "AuthenticationResult"; then
    echo "✅ Strategy 2 SUCCESS: Phone login worked!"
    TOKEN=$(echo $RESPONSE | jq -r '.AuthenticationResult.AccessToken')
    echo ""
    echo "🎫 Access Token (first 50 chars): ${TOKEN:0:50}..."
    echo ""
    
    # Test API call
    echo "Testing API call to Wallet Service..."
    
    WALLET_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
        -X GET "$API_URL/wallet/my-wallet" \
        -H "Authorization: Bearer $TOKEN")
    
    HTTP_STATUS=$(echo "$WALLET_RESPONSE" | grep "HTTP_STATUS" | cut -d: -f2)
    BODY=$(echo "$WALLET_RESPONSE" | sed '/HTTP_STATUS/d')
    
    echo "HTTP Status: $HTTP_STATUS"
    echo "Response: $BODY"
    
    if [ "$HTTP_STATUS" == "200" ]; then
        echo "✅ API call successful!"
    else
        echo "❌ API call failed with status $HTTP_STATUS"
    fi
    
    exit 0
else
    echo "❌ Strategy 2 FAILED: $RESPONSE"
fi

echo ""
echo "========================================="
echo "Strategy 3: Generated Phone (from email hash)"
echo "========================================="
echo "Testing: $GENERATED_PHONE"
echo "Note: This uses a simplified hash, may not match app exactly"

RESPONSE=$(aws cognito-idp initiate-auth \
    --region $REGION \
    --auth-flow USER_PASSWORD_AUTH \
    --client-id $DRIVER_CLIENT_ID \
    --auth-parameters USERNAME=$GENERATED_PHONE,PASSWORD=$PASSWORD \
    2>&1)

if echo "$RESPONSE" | grep -q "AuthenticationResult"; then
    echo "✅ Strategy 3 SUCCESS: Generated phone login worked!"
    TOKEN=$(echo $RESPONSE | jq -r '.AuthenticationResult.AccessToken')
    echo ""
    echo "🎫 Access Token (first 50 chars): ${TOKEN:0:50}..."
    echo ""
    
    # Test API call
    echo "Testing API call to Wallet Service..."
    
    WALLET_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
        -X GET "$API_URL/wallet/my-wallet" \
        -H "Authorization: Bearer $TOKEN")
    
    HTTP_STATUS=$(echo "$WALLET_RESPONSE" | grep "HTTP_STATUS" | cut -d: -f2)
    BODY=$(echo "$WALLET_RESPONSE" | sed '/HTTP_STATUS/d')
    
    echo "HTTP Status: $HTTP_STATUS"
    echo "Response: $BODY"
    
    if [ "$HTTP_STATUS" == "200" ]; then
        echo "✅ API call successful!"
    else
        echo "❌ API call failed with status $HTTP_STATUS"
    fi
    
    exit 0
else
    echo "❌ Strategy 3 FAILED: $RESPONSE"
fi

echo ""
echo "========================================="
echo "❌ ALL STRATEGIES FAILED"
echo "========================================="
echo "The driver may need to be registered or the username format is different."
echo ""
echo "Debug Info:"
echo "- Pool ID: $DRIVER_POOL_ID"
echo "- Client ID: $DRIVER_CLIENT_ID"
echo "- Email attribute: $EMAIL"
echo "- Phone attribute: $PHONE"
echo ""
echo "Next steps:"
echo "1. Verify the driver is registered and confirmed"
echo "2. Check if custom authentication flow is used"
echo "3. Examine actual Cognito user attributes"
