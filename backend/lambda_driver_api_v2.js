/**
 * Enhanced Driver API Lambda Function
 * Supports both phone and email registration
 * Handles profile status tracking and completion
 * 
 * Version: 2.1 - ✅ Fixed working hours timezone (Asia/Baghdad)
 * Date: 2025-11-29
 * 
 * Changes in v2.1:
 * - Fixed checkBusinessWorkingHours() to use Asia/Baghdad timezone instead of UTC
 * - Now correctly handles midnight-crossing hours (e.g., 22:00 - 02:00)
 * - Matches timezone logic with get-businesses-status Lambda
 */

const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, GetCommand, PutCommand, UpdateCommand, ScanCommand, QueryCommand, DeleteCommand } = require('@aws-sdk/lib-dynamodb');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const h3 = require('h3-js');
const axios = require('axios');

const client = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const dynamodb = DynamoDBDocumentClient.from(client);
const s3 = new S3Client({ region: process.env.AWS_REGION || 'us-east-1' });

const DRIVERS_TABLE = process.env.DRIVER_TABLE;
const DRIVER_LIVE_STATE_TABLE = process.env.DRIVER_LIVE_STATE_TABLE;
const ORDERS_TABLE = process.env.ORDERS_TABLE;
const WEBSOCKET_CONNECTIONS_TABLE = process.env.WEBSOCKET_CONNECTIONS_TABLE;
const REGIONS_TABLE = process.env.REGIONS_TABLE;
const REGION_INDEX_TABLE = process.env.REGION_INDEX_TABLE;
const REGION_NEIGHBORS_TABLE = process.env.REGION_NEIGHBORS_TABLE;
const DRIVER_PERFORMANCE_METRICS_TABLE = process.env.DRIVER_PERFORMANCE_METRICS_TABLE || 'WizzDriverPerformanceMetrics';
const DISPATCH_JOBS_TABLE = process.env.DISPATCH_JOBS_TABLE;
const H3_RESOLUTION = 9;  // نفس الدقة المستخدمة في تطبيق المستخدم

const DRIVER_DOCUMENTS_BUCKET = process.env.DRIVER_DOCUMENTS_BUCKET;

// 🏢 Order Service - Centralized order cancellation with Hold release
const ORDER_SERVICE_URL = process.env.ORDER_SERVICE_URL;

if (!DRIVERS_TABLE || !DRIVER_LIVE_STATE_TABLE || !ORDERS_TABLE) {
  throw new Error('Missing required env vars: DRIVER_TABLE, DRIVER_LIVE_STATE_TABLE, ORDERS_TABLE');
}

if (!WEBSOCKET_CONNECTIONS_TABLE || !REGIONS_TABLE || !REGION_INDEX_TABLE) {
  throw new Error('Missing required env vars: WEBSOCKET_CONNECTIONS_TABLE, REGIONS_TABLE, REGION_INDEX_TABLE');
}

if (!REGION_NEIGHBORS_TABLE) {
  throw new Error('Missing required env var: REGION_NEIGHBORS_TABLE');
}

if (!ORDER_SERVICE_URL) {
  throw new Error('Missing required env var: ORDER_SERVICE_URL');
}

/**
 * Call Order Service to cancel order with automatic Hold release
 * @param {string} orderId - Order ID to cancel
 * @param {string} canceledBy - Who cancelled: 'driver' | 'customer' | 'restaurant' | 'system'
 * @param {string} reason - Cancellation reason
 * @param {string} requestedBy - User ID making the request (for authorization)
 * @returns {Promise<object>} - { success, orderId, newStatus, holdReleased, message }
 */
async function callOrderService(orderId, canceledBy, reason, requestedBy) {
  try {
    console.log(`📞 Calling Order Service: orderId=${orderId}, canceledBy=${canceledBy}, requestedBy=${requestedBy}`);
    
    const response = await axios.post(`${ORDER_SERVICE_URL}/order/cancel`, {
      orderId,
      canceledBy,
      reason,
      requestedBy
    }, {
      headers: { 'Content-Type': 'application/json' },
      timeout: 10000
    });
    
    console.log('✅ Order Service response:', response.data);
    return response.data;
    
  } catch (error) {
    console.error('❌ Order Service error:', error.response?.data || error.message);
    
    // Extract useful error info
    const errorData = error.response?.data || {};
    const errorMessage = errorData.error?.message || errorData.message || error.message;
    
    throw new Error(`Order Service failed: ${errorMessage}`);
  }
}

/**
 * Call Order Service to UNASSIGN driver (order stays active, gets reassigned)
 * @param {string} orderId - Order ID to unassign
 * @param {string} driverId - Driver ID to unassign
 * @param {string} reason - Unassignment reason
 * @param {string} requestedBy - Driver ID making the request (for authorization)
 * @returns {Promise<object>} - { success, orderId, oldDriverId, newStatus: 'reassigning', holdReleased, waveOfferId, message }
 */
async function callOrderServiceUnassign(orderId, driverId, reason, requestedBy) {
  try {
    console.log(`📞 Calling Order Service UNASSIGN: orderId=${orderId}, driverId=${driverId}, requestedBy=${requestedBy}`);
    
    const response = await axios.post(`${ORDER_SERVICE_URL}/order/unassign`, {
      orderId,
      driverId,
      reason,
      requestedBy
    }, {
      headers: { 'Content-Type': 'application/json' },
      timeout: 10000
    });
    
    console.log('✅ Order Service Unassign response:', response.data);
    return response.data;
    
  } catch (error) {
    console.error('❌ Order Service Unassign error:', error.response?.data || error.message);
    
    // Extract useful error info
    const errorData = error.response?.data || {};
    const errorMessage = errorData.error?.message || errorData.message || error.message;
    
    throw new Error(`Order Service Unassign failed: ${errorMessage}`);
  }
}

/**
 * Get driver information for order updates
 * 🚗 Helper function to fetch driver details for enriching order data
 */
async function getDriverInfo(driverId) {
  try {
    const result = await dynamodb.send(new GetCommand({
      TableName: DRIVERS_TABLE,
      Key: { driverId }
    }));
    
    if (!result.Item) {
      console.log(`⚠️ Driver ${driverId} not found in database`);
      return null;
    }
    
    const driver = result.Item;
    return {
      driverName: driver.name || null,
      driverPhone: driver.phoneNumber || driver.phone || null,
      vehicleType: driver.vehicleType || null,
      vehiclePlate: driver.licenseNumber || driver.vehiclePlate || null
    };
  } catch (error) {
    console.error(`❌ Error fetching driver info for ${driverId}:`, error);
    return null;
  }
}

/**
 * Extract username from JWT token
 */
function extractUsernameFromToken(authHeader) {
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    console.log('❌ No valid Authorization header found');
    return null;
  }
  
  try {
    const token = authHeader.substring(7); // Remove 'Bearer ' prefix
    const payload = token.split('.')[1]; // Get payload part of JWT
    const decoded = JSON.parse(Buffer.from(payload, 'base64').toString());
    
    console.log('🔍 JWT payload decoded:', JSON.stringify({
      sub: decoded.sub,
      username: decoded.username,
      'cognito:username': decoded['cognito:username']
    }, null, 2));
    
    const extractedUsername = decoded.sub || decoded.username || decoded['cognito:username'];
    console.log('🎯 Final extracted username:', extractedUsername);
    
    return extractedUsername;
  } catch (error) {
    console.error('❌ Failed to decode token:', error);
    return null;
  }
}

/**
 * Extract JWT claims object from Authorization header (no signature verification).
 * Used only as a fallback when API Gateway authorizer claims are not present.
 */
function extractClaimsFromToken(authHeader) {
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return null;
  }

  try {
    const token = authHeader.substring(7);
    const payload = token.split('.')[1];
    return JSON.parse(Buffer.from(payload, 'base64').toString());
  } catch (error) {
    console.error('❌ Failed to decode token claims:', error);
    return null;
  }
}

function extractBearerTokenFromEvent(event) {
  const authHeader = event.headers?.Authorization || event.headers?.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) return null;
  return authHeader.substring(7);
}

async function getCognitoUserFromAccessToken(accessToken) {
  if (!accessToken) return null;

  try {
    const cognitoClient = new CognitoIdentityProviderClient({ region: 'us-east-1' });
    const response = await cognitoClient.send(new GetUserCommand({ AccessToken: accessToken }));

    const attributes = {};
    for (const item of response.UserAttributes || []) {
      if (item?.Name) attributes[item.Name] = item.Value;
    }

    return { username: response.Username, attributes };
  } catch (error) {
    console.error('❌ Cognito GetUser failed:', error?.message || error);
    return null;
  }
}

function getEventJwtClaims(event) {
  const authorizerClaims = event.requestContext?.authorizer?.jwt?.claims ||
                           event.requestContext?.authorizer?.claims;
  const authHeader = event.headers?.Authorization || event.headers?.authorization;
  const headerClaims = extractClaimsFromToken(authHeader);

  // Prefer authorizer values when present, but enrich from header claims.
  if (authorizerClaims && typeof authorizerClaims === 'object') {
    return {
      ...(headerClaims && typeof headerClaims === 'object' ? headerClaims : {}),
      ...authorizerClaims,
    };
  }

  return headerClaims;
}

function buildDriverIdFallbacks(claims) {
  const candidates = [
    claims?.['cognito:username'],
    claims?.username,
    claims?.preferred_username,
    claims?.email,
    claims?.phone_number,
    claims?.phoneNumber,
  ].filter(Boolean);

  // de-dupe while preserving order
  return [...new Set(candidates)];
}

async function getDriverProfileItem(driverId) {
  const result = await dynamodb.send(new GetCommand({
    TableName: DRIVERS_TABLE,
    Key: { driverId },
  }));
  return result.Item || null;
}

async function ensureProfileUnderPrimaryId(primaryDriverId, fallbackDriverIds, accessToken) {
  const primaryProfile = await getDriverProfileItem(primaryDriverId);
  if (primaryProfile) {
    return { driverId: primaryDriverId, profile: primaryProfile, migrated: false };
  }

  let effectiveFallbacks = Array.isArray(fallbackDriverIds) ? [...fallbackDriverIds] : [];

  // With AccessToken, the JWT payload usually only contains `sub`/`username` (no email/phone).
  // Always try to enrich from Cognito GetUser so we can migrate profiles keyed by email/phone.
  if (accessToken) {
    const cognitoUser = await getCognitoUserFromAccessToken(accessToken);
    if (cognitoUser) {
      const attrs = cognitoUser.attributes || {};
      const enriched = [
        cognitoUser.username,
        attrs.email,
        attrs.phone_number,
      ].filter(Boolean);

      effectiveFallbacks = [...new Set([...(effectiveFallbacks || []), ...enriched])];
      console.log('🧩 Enriched fallbacks from Cognito GetUser:', enriched);
    }
  }

  for (const fallbackId of effectiveFallbacks || []) {
    if (!fallbackId || fallbackId === primaryDriverId) continue;
    const fallbackProfile = await getDriverProfileItem(fallbackId);
    if (!fallbackProfile) continue;

    // Copy the record to the primary key so the rest of the system uses a single stable id.
    const now = new Date().toISOString();
    const migratedProfile = {
      ...fallbackProfile,
      driverId: primaryDriverId,
      migratedFromDriverId: fallbackId,
      migratedAt: now,
      updatedAt: now,
    };

    await dynamodb.send(new PutCommand({
      TableName: DRIVERS_TABLE,
      Item: migratedProfile,
    }));

    console.log('✅ Migrated driver profile key:', { from: fallbackId, to: primaryDriverId });
    return { driverId: primaryDriverId, profile: migratedProfile, migrated: true };
  }

  return { driverId: primaryDriverId, profile: null, migrated: false };
}

async function ensureProfileExists(primaryDriverId, fallbackDriverIds, accessToken) {
  const existing = await ensureProfileUnderPrimaryId(primaryDriverId, fallbackDriverIds, accessToken);
  if (existing.profile) return existing;

  const now = new Date().toISOString();
  const cognitoUser = await getCognitoUserFromAccessToken(accessToken);
  const attrs = cognitoUser?.attributes || {};

  const profile = {
    driverId: primaryDriverId,
    registrationMethod: 'unknown',
    phoneNumber: attrs.phone_number || null,
    email: attrs.email || null,
    status: 'PENDING_PROFILE',
    createdAt: now,
    updatedAt: now,
    verifiedAt: now,
    profileCompletedAt: null,
    name: null,
    city: null,
    vehicleType: null,
    licenseNumber: null,
    nationalId: null,
    drivingLicenseUrl: null,
    registrationPaperUrl: null,
    isActive: true,
    isOnline: false,
  };

  await dynamodb.send(new PutCommand({
    TableName: DRIVERS_TABLE,
    Item: profile,
  }));

  console.log('✅ Created skeleton driver profile:', { driverId: primaryDriverId });
  return { driverId: primaryDriverId, profile, migrated: false };
}

// ===================================================================
// 💰 WALLET SERVICE INTEGRATION - Hold Management
// ===================================================================

const crypto = require('crypto');
const { CognitoIdentityProviderClient, InitiateAuthCommand, GetUserCommand } = require('@aws-sdk/client-cognito-identity-provider');

function decodeJwtPayload(token) {
  try {
    if (!token || typeof token !== 'string') return null;
    const parts = token.split('.');
    if (parts.length < 2) return null;
    const payloadPart = parts[1];
    const padded = payloadPart.replace(/-/g, '+').replace(/_/g, '/');
    const json = Buffer.from(padded + '='.repeat((4 - (padded.length % 4)) % 4), 'base64').toString('utf8');
    return JSON.parse(json);
  } catch (_) {
    return null;
  }
}

/**
 * Calculate SECRET_HASH for Cognito authentication
 * Required when CLIENT_SECRET is configured
 */
function calculateSecretHash(username, clientId, clientSecret) {
  return crypto
    .createHmac('SHA256', clientSecret)
    .update(username + clientId)
    .digest('base64');
}

/**
 * Get authentication token for Wallet Service using service pool credentials
 * This uses a dedicated service user in a separate Cognito pool
 */
async function getServiceToken() {
  try {
    const clientId = process.env.SERVICE_CLIENT_ID;
    const clientSecret = process.env.SERVICE_CLIENT_SECRET;
    const username = process.env.SERVICE_USERNAME;
    const password = process.env.SERVICE_PASSWORD;
    
    if (!clientId || !clientSecret || !username || !password) {
      throw new Error('Wallet service credentials not configured in environment variables');
    }
    
    const secretHash = calculateSecretHash(username, clientId, clientSecret);
    
    const cognitoClient = new CognitoIdentityProviderClient({ region: 'us-east-1' });
    
    const command = new InitiateAuthCommand({
      AuthFlow: 'USER_PASSWORD_AUTH',
      ClientId: clientId,
      AuthParameters: {
        USERNAME: username,
        PASSWORD: password,
        SECRET_HASH: secretHash
      }
    });
    
    const response = await cognitoClient.send(command);
    
    if (!response.AuthenticationResult?.AccessToken) {
      throw new Error('Failed to get AccessToken from Cognito');
    }
    
    const accessToken = response.AuthenticationResult.AccessToken;
    const decoded = decodeJwtPayload(accessToken);
    console.log('✅ Service authentication successful');
    console.log('   - SERVICE_USERNAME:', username);
    console.log('   - SERVICE_CLIENT_ID:', clientId ? `${String(clientId).slice(0, 8)}…` : 'N/A');
    if (decoded) {
      console.log('   - token_use:', decoded.token_use);
      console.log('   - iss:', decoded.iss);
      console.log('   - exp:', decoded.exp);
      console.log('   - client_id:', decoded.client_id);
    }
    return accessToken;
    
  } catch (error) {
    console.error('❌ Error getting service token:', error);
    throw new Error(`Service authentication failed: ${error.message}`);
  }
}

/**
 * Create Hold on driver wallet via Wallet Service
 * @param {string} driverId - The driver ID (wallet owner)
 * @param {number} amount - Amount to hold (in IQD)
 * @param {string} orderId - Order ID for idempotency
 * @param {number} assignmentAttempt - Wave number for reassignment scenarios
 * @returns {Promise<{holdId: string, status: string, amount: number}>}
 */
async function createWalletHold(driverId, amount, orderId, assignmentAttempt) {
  try {
    console.log('💰 Creating wallet Hold:');
    console.log('   - Driver ID:', driverId);
    console.log('   - Amount:', amount, 'IQD');
    console.log('   - Order ID:', orderId);
    console.log('   - Assignment Attempt:', assignmentAttempt || 'N/A');
    
    // Get service authentication token
    const token = await getServiceToken();
    
    // Call Wallet Service API
    const walletServiceUrl = process.env.WALLET_SERVICE_URL;
    if (!walletServiceUrl) {
      throw new Error('WALLET_SERVICE_URL not configured');
    }

    const holdCreateUrl = `${walletServiceUrl}/wallet/hold/create`;
    console.log('📞 Calling Wallet Service:', holdCreateUrl);
    
    const response = await fetch(holdCreateUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify({
        userId: driverId,
        amount: amount,
        orderId: orderId,
        assignmentAttempt: assignmentAttempt, // Wave number for unique idempotency
        reason: 'ORDER_ACCEPTANCE',
        metadata: {
          source: 'driver-api',
          timestamp: new Date().toISOString(),
          waveNumber: assignmentAttempt
        }
      })
    });
    
    const result = await response.json();
    
    if (!response.ok) {
      console.error('❌ Hold creation failed:', result);
      // API Gateway typically returns {"message":"Unauthorized"} when authorizer rejects token.
      if (response.status === 401 && (result?.message === 'Unauthorized' || result?.message === 'UNAUTHORIZED')) {
        throw new Error(
          'Unauthorized (Wallet Service authorizer rejected the service token). ' +
          'Check WALLET_SERVICE_URL + SERVICE_* credentials match the wallet-service environment.'
        );
      }
      throw new Error(result.message || 'Failed to create Hold on wallet');
    }
    
    // Wallet Service returns: { success: true, hold: { holdId, amount, status, ... }, message: "..." }
    console.log('✅ Hold created successfully - Full response:', JSON.stringify(result));
    
    // Extract hold data from response
    const holdData = result.hold || result;  // Fallback if structure changes
    console.log('   - holdId:', holdData.holdId);
    console.log('   - amount:', holdData.amount);
    console.log('   - status:', holdData.status);
    
    return {
      holdId: holdData.holdId,
      status: holdData.status,
      amount: holdData.amount
    };
    
  } catch (error) {
    console.error('❌ Error creating wallet Hold:', error);
    throw error;
  }
}

/**
 * Release Hold on driver wallet via Wallet Service
 * @param {string} holdId - The Hold ID to release
 * @param {string} reason - Reason for releasing (e.g., 'ORDER_CANCELLED_BY_USER')
 * @param {string} orderId - Order ID for idempotency
 * @returns {Promise<{success: boolean, message: string}>}
 */
async function releaseWalletHold(holdId, reason, orderId) {
  try {
    console.log('🔓 Releasing wallet Hold:');
    console.log('   - Hold ID:', holdId);
    console.log('   - Reason:', reason);
    console.log('   - Order ID:', orderId);
    
    // Get service authentication token
    const token = await getServiceToken();
    
    // Call Wallet Service API
    const walletServiceUrl = process.env.WALLET_SERVICE_URL;
    if (!walletServiceUrl) {
      throw new Error('WALLET_SERVICE_URL not configured');
    }
    
    const url = `${walletServiceUrl}/wallet/hold/${holdId}/release`;
    console.log('📞 Calling Wallet Service:', url);

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify({
        reason: reason,
        orderId: orderId,
        metadata: {
          source: 'driver-api',
          timestamp: new Date().toISOString()
        }
      })
    });
    
    const result = await response.json();
    
    if (!response.ok) {
      console.error('❌ Hold release failed:', result);
      throw new Error(result.message || 'Failed to release Hold');
    }
    
    console.log('✅ Hold released successfully:', JSON.stringify(result));
    
    return {
      success: true,
      message: result.message || 'Hold released successfully'
    };
    
  } catch (error) {
    console.error('❌ Error releasing wallet Hold:', error);
    throw error;
  }
}

/**
 * 💰 Capture wallet hold - when order is delivered
 * Similar to releaseWalletHold but CAPTURES money instead of releasing it
 */
async function captureWalletHold(holdId, actualAmount, reason, orderId) {
  try {
    console.log('💰 ========================================');
    console.log('💰 CAPTURING WALLET HOLD');
    console.log('💰 Hold ID:', holdId);
    console.log('💰 Actual Amount:', actualAmount);
    console.log('💰 Reason:', reason);
    console.log('💰 Order ID:', orderId);
    console.log('💰 ========================================');
    
    // Get service authentication token
    const token = await getServiceToken();
    
    // Call Wallet Service API
    const walletServiceUrl = process.env.WALLET_SERVICE_URL;
    if (!walletServiceUrl) {
      throw new Error('WALLET_SERVICE_URL not configured');
    }
    
    const url = `${walletServiceUrl}/wallet/hold/${holdId}/capture`;
    console.log('📞 Calling Wallet Service:', url);
    
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify({
        actualAmount: actualAmount, // Can be partial (for tips/adjustments)
        reason: reason,
        metadata: {
          source: 'driver-api',
          orderId: orderId,
          timestamp: new Date().toISOString()
        }
      })
    });
    
    const result = await response.json();
    
    if (!response.ok) {
      console.error('❌ Wallet Service capture hold failed:', result);
      throw new Error(result.message || 'Failed to capture Hold');
    }
    
    console.log('✅ ========================================');
    console.log('✅ HOLD CAPTURED SUCCESSFULLY!');
    console.log('✅ Hold ID:', result.holdId);
    console.log('✅ Captured Amount:', result.capturedAmount);
    console.log('✅ Released Amount:', result.releasedAmount || 0); // Partial capture
    console.log('✅ Message:', result.message);
    console.log('✅ ========================================');
    
    return {
      success: true,
      holdId: result.holdId,
      capturedAmount: result.capturedAmount,
      releasedAmount: result.releasedAmount || 0,
      message: result.message || 'Hold captured successfully'
    };
    
  } catch (error) {
    console.error('❌ ========================================');
    console.error('❌ FAILED TO CAPTURE HOLD!');
    console.error('❌ Hold ID:', holdId);
    console.error('❌ Error:', error);
    console.error('❌ Error name:', error.name);
    console.error('❌ Error message:', error.message);
    console.error('❌ Stack:', error.stack);
    console.error('❌ ========================================');
    
    return {
      success: false,
      error: error.message
    };
  }
}

function buildQueryString(queryParams) {
  if (!queryParams || typeof queryParams !== 'object') return '';
  const entries = Object.entries(queryParams)
    .filter(([, v]) => v !== undefined && v !== null && String(v).length > 0)
    .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(String(v))}`);
  return entries.length ? `?${entries.join('&')}` : '';
}

function getWalletPathFromRequestPath(path) {
  if (!path) return null;
  const idx = path.indexOf('/wallet');
  if (idx === -1) return null;
  return path.substring(idx);
}

async function proxyWalletRequest(event, httpMethod, walletPath, corsHeaders) {
  const walletServiceUrlRaw = process.env.WALLET_SERVICE_URL;
  const walletServiceUrl = walletServiceUrlRaw ? walletServiceUrlRaw.replace(/\/$/, '') : '';
  if (!walletServiceUrl) {
    return {
      statusCode: 503,
      headers: corsHeaders,
      body: JSON.stringify({
        error: 'Wallet service not configured',
        message: 'WALLET_SERVICE_URL is not configured for this environment',
      }),
    };
  }

  const queryString = buildQueryString(event.queryStringParameters);
  const targetUrl = `${walletServiceUrl}${walletPath}${queryString}`;

  const inboundHeaders = event.headers || {};
  const authHeader = inboundHeaders.Authorization || inboundHeaders.authorization;

  const outboundHeaders = {
    'Content-Type': inboundHeaders['Content-Type'] || inboundHeaders['content-type'] || 'application/json',
  };

  if (authHeader) {
    outboundHeaders.Authorization = authHeader;
  }

  const idempotencyKey = inboundHeaders['X-Idempotency-Key'] || inboundHeaders['x-idempotency-key'];
  if (idempotencyKey) {
    outboundHeaders['X-Idempotency-Key'] = idempotencyKey;
  }

  const accept = inboundHeaders.Accept || inboundHeaders.accept;
  if (accept) {
    outboundHeaders.Accept = accept;
  }

  let body = event.body;
  if (event.isBase64Encoded && body) {
    try {
      body = Buffer.from(body, 'base64').toString('utf-8');
    } catch (e) {
      console.warn('⚠️ Failed to decode base64 wallet request body:', e);
    }
  }

  const fetchOptions = {
    method: httpMethod,
    headers: outboundHeaders,
  };

  if (httpMethod !== 'GET' && httpMethod !== 'HEAD' && body != null) {
    fetchOptions.body = typeof body === 'string' ? body : JSON.stringify(body);
  }

  console.log('💳 Proxying wallet request:', { walletPath, targetUrl, method: httpMethod });

  const response = await fetch(targetUrl, fetchOptions);
  const responseText = await response.text();

  return {
    statusCode: response.status,
    headers: corsHeaders,
    body: responseText || JSON.stringify({}),
  };
}

/**
 * Main Lambda handler
 */
exports.handler = async (event) => {
  console.log('📨 Driver API v2 - Event:', JSON.stringify(event, null, 2));

  const httpMethod = event.httpMethod || event.requestContext?.http?.method;
  const path = event.path || event.rawPath || '';
  
  // Try to get JWT claims from authorizer context first (if Cognito authorizer is enabled)
  // API Gateway V2 uses .jwt.claims, V1 uses .claims
  const jwtClaims = getEventJwtClaims(event);
  const bearerToken = extractBearerTokenFromEvent(event);

  if (jwtClaims && typeof jwtClaims === 'object') {
    console.log('🔍 JWT claims keys:', Object.keys(jwtClaims).slice(0, 50));
  } else {
    console.log('⚠️ No JWT claims object available');
  }

  // Primary stable driver identity is Cognito `sub`
  let cognitoUsername = jwtClaims?.sub;
  const driverIdFallbacks = buildDriverIdFallbacks(jwtClaims);

  console.log('🧩 Driver identity:', {
    sub: jwtClaims?.sub,
    fallbackCount: driverIdFallbacks.length,
    fallbacks: driverIdFallbacks,
  });
  
  // If no authorizer, try to extract from Authorization header
  if (!cognitoUsername) {
    const authHeader = event.headers?.Authorization || event.headers?.authorization;
    console.log('🔍 Attempting to extract username from token');
    console.log('   Authorization header present:', !!authHeader);
    if (authHeader) {
      console.log('   Token starts with Bearer:', authHeader.startsWith('Bearer '));
    }
    cognitoUsername = extractUsernameFromToken(authHeader);
    console.log('🔓 Extracted username from JWT token:', cognitoUsername);
  } else {
    console.log('✅ Username from authorizer:', cognitoUsername);
  }

  // CORS headers - Define FIRST before any usage
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
    'Content-Type': 'application/json',
  };

  // Check if username is still missing (but allow public endpoints)
  const publicEndpoints = ['/driver/map-data'];
  const isPublicEndpoint = publicEndpoints.some(endpoint => path === endpoint || path.endsWith(endpoint));
  
  if (!cognitoUsername && !isPublicEndpoint) {
    console.error('❌ No username found in request - unauthorized');
    return {
      statusCode: 401,
      headers: corsHeaders,
      body: JSON.stringify({
        error: 'Unauthorized',
        message: 'No username found in Authorization token',
        details: 'Please ensure you are logged in and include a valid Authorization header'
      })
    };
  }

  console.log('✅ Processing request for user:', cognitoUsername || 'anonymous (public endpoint)');

  // Handle OPTIONS preflight
  if (httpMethod === 'OPTIONS') {
    return { statusCode: 200, headers: corsHeaders, body: JSON.stringify({}) };
  }

  try {
    // Wallet endpoints: proxy to Wallet Service
    const walletPath = getWalletPathFromRequestPath(path);
    if (walletPath) {
      return await proxyWalletRequest(event, httpMethod, walletPath, corsHeaders);
    }

    // Route handling
    if (path === '/driver/me' || path.endsWith('/driver/me')) {
      if (httpMethod === 'GET') {
        return await getDriverProfile(cognitoUsername, driverIdFallbacks, bearerToken, corsHeaders);
      } else if (httpMethod === 'PUT') {
        const body = JSON.parse(event.body || '{}');
        return await updateDriverProfile(cognitoUsername, driverIdFallbacks, bearerToken, body, corsHeaders);
      } else if (httpMethod === 'POST') {
        const body = JSON.parse(event.body || '{}');
        return await createDriverProfile(cognitoUsername, driverIdFallbacks, bearerToken, body, corsHeaders);
      }
    }

    // Profile status check endpoint
    if (path === '/driver/profile-status' || path.endsWith('/driver/profile-status')) {
      if (httpMethod === 'GET') {
        return await getProfileStatus(cognitoUsername, driverIdFallbacks, bearerToken, corsHeaders);
      }
    }

    // Document upload (base64)
    if (path === '/driver/documents/upload' || path.endsWith('/driver/documents/upload')) {
      if (httpMethod === 'POST') {
        const body = JSON.parse(event.body || '{}');
        return await uploadDriverDocument(cognitoUsername, driverIdFallbacks, bearerToken, body, corsHeaders);
      }
    }

    // ✨ NEW: Start searching endpoint
    if (path === '/driver/start-searching' || path.endsWith('/driver/start-searching')) {
      if (httpMethod === 'POST') {
        const body = JSON.parse(event.body || '{}');
        return await startSearching(cognitoUsername, body, corsHeaders);
      }
    }

    // ✨ NEW: Stop searching endpoint
    if (path === '/driver/stop-searching' || path.endsWith('/driver/stop-searching')) {
      if (httpMethod === 'POST') {
        const body = JSON.parse(event.body || '{}');
        return await stopSearching(cognitoUsername, body, corsHeaders);
      }
    }

    // ✨ NEW: Accept Wave Offer endpoint
    if (path === '/driver/accept-wave-offer' || path.endsWith('/driver/accept-wave-offer')) {
      if (httpMethod === 'POST') {
        const body = JSON.parse(event.body || '{}');
        return await acceptWaveOffer(cognitoUsername, body, corsHeaders);
      }
    }

    // ✨ NEW: Reject Wave Offer endpoint
    if (path === '/driver/reject-wave-offer' || path.endsWith('/driver/reject-wave-offer')) {
      if (httpMethod === 'POST') {
        const body = JSON.parse(event.body || '{}');
        return await rejectWaveOffer(cognitoUsername, body, corsHeaders);
      }
    }

    // ✨ NEW: Update location endpoint (periodic location updates)
    if (path === '/driver/update-location' || path.endsWith('/driver/update-location')) {
      if (httpMethod === 'POST') {
        const body = JSON.parse(event.body || '{}');
        return await updateLocation(cognitoUsername, body, corsHeaders);
      }
    }

    // ✨ NEW: Get map data (stores, regions, hot stores)
    if (path === '/driver/map-data' || path.endsWith('/driver/map-data')) {
      if (httpMethod === 'GET') {
        const queryParams = event.queryStringParameters || {};
        return await getMapData(cognitoUsername, queryParams, corsHeaders);
      }
    }

    // 📊 NEW: Get driver performance metrics
    if (path === '/driver/metrics' || path.endsWith('/driver/metrics')) {
      if (httpMethod === 'GET') {
        return await getDriverMetrics(cognitoUsername, corsHeaders);
      }
    }

    // 🚗 ACTIVE ORDER APIs
    
    // Get specific order by ID
    if (path.match(/^\/driver\/orders\/[^/]+$/) || path.match(/\/driver\/orders\/[^/]+$/)) {
      const orderId = path.split('/').pop();
      if (httpMethod === 'GET') {
        return await getOrderById(cognitoUsername, orderId, corsHeaders);
      }
    }

    // Get current active order
    if (path === '/driver/active-order' || path.endsWith('/driver/active-order')) {
      if (httpMethod === 'GET') {
        return await getActiveOrder(cognitoUsername, corsHeaders);
      }
    }

    // 🆕 Unassign from active order (order stays active, gets reassigned)
    if (path === '/driver/active-order/unassign' || path.endsWith('/driver/active-order/unassign')) {
      console.log(`🔥 UNASSIGN ROUTE HIT! Method: ${httpMethod}, Path: ${path}`);
      if (httpMethod === 'POST') {
        const body = JSON.parse(event.body || '{}');
        console.log(`📦 Parsed body:`, JSON.stringify(body));
        console.log(`👤 cognitoUsername: ${cognitoUsername}`);
        return await unassignActiveOrder(cognitoUsername, body, corsHeaders);
      }
    }

    // Start heading to store
    if (path.match(/^\/driver\/orders\/[^/]+\/start-heading$/) || path.match(/\/driver\/orders\/[^/]+\/start-heading$/)) {
      const orderId = path.split('/').slice(-2)[0];
      if (httpMethod === 'POST') {
        return await startHeadingToStore(cognitoUsername, orderId, corsHeaders);
      }
    }

    // Arrive at store
    if (path.match(/^\/driver\/orders\/[^/]+\/arrive-store$/) || path.match(/\/driver\/orders\/[^/]+\/arrive-store$/)) {
      const orderId = path.split('/').slice(-2)[0];
      if (httpMethod === 'POST') {
        return await arriveAtStore(cognitoUsername, orderId, corsHeaders);
      }
    }

    // Pickup order
    if (path.match(/^\/driver\/orders\/[^/]+\/pickup$/) || path.match(/\/driver\/orders\/[^/]+\/pickup$/)) {
      const orderId = path.split('/').slice(-2)[0];
      if (httpMethod === 'POST') {
        return await pickupOrder(cognitoUsername, orderId, corsHeaders);
      }
    }

    // Start heading to customer
    if (path.match(/^\/driver\/orders\/[^/]+\/start-heading-to-customer$/) || path.match(/\/driver\/orders\/[^/]+\/start-heading-to-customer$/)) {
      const orderId = path.split('/').slice(-2)[0];
      if (httpMethod === 'POST') {
        return await startHeadingToCustomer(cognitoUsername, orderId, corsHeaders);
      }
    }

    // Arrive at customer
    if (path.match(/^\/driver\/orders\/[^/]+\/arrive-customer$/) || path.match(/\/driver\/orders\/[^/]+\/arrive-customer$/)) {
      const orderId = path.split('/').slice(-2)[0];
      if (httpMethod === 'POST') {
        return await arriveAtCustomer(cognitoUsername, orderId, corsHeaders);
      }
    }

    // Deliver order
    if (path.match(/^\/driver\/orders\/[^/]+\/deliver$/) || path.match(/\/driver\/orders\/[^/]+\/deliver$/)) {
      const orderId = path.split('/').slice(-2)[0];
      if (httpMethod === 'POST') {
        const body = JSON.parse(event.body || '{}');
        return await deliverOrder(cognitoUsername, orderId, body, corsHeaders);
      }
    }

    // Report store issue
    if (path.match(/^\/driver\/orders\/[^/]+\/issue$/) || path.match(/\/driver\/orders\/[^/]+\/issue$/)) {
      const orderId = path.split('/').slice(-2)[0];
      if (httpMethod === 'POST') {
        const body = JSON.parse(event.body || '{}');
        return await reportStoreIssue(cognitoUsername, orderId, body, corsHeaders);
      }
    }

    // Report customer unreachable
    if (path.match(/^\/driver\/orders\/[^/]+\/customer-unreachable$/) || path.match(/\/driver\/orders\/[^/]+\/customer-unreachable$/)) {
      const orderId = path.split('/').slice(-2)[0];
      if (httpMethod === 'POST') {
        return await reportCustomerUnreachable(cognitoUsername, orderId, corsHeaders);
      }
    }

    // Cancel order by driver
    if (path.match(/^\/driver\/orders\/[^/]+\/cancel-by-driver$/) || path.match(/\/driver\/orders\/[^/]+\/cancel-by-driver$/)) {
      const orderId = path.split('/').slice(-2)[0];
      if (httpMethod === 'POST') {
        const body = JSON.parse(event.body || '{}');
        return await cancelOrderByDriver(cognitoUsername, orderId, body, corsHeaders);
      }
    }

    // 404 for unknown routes
    return {
      statusCode: 404,
      headers: corsHeaders,
      body: JSON.stringify({ error: 'Route not found', path, method: httpMethod }),
    };
  } catch (error) {
    console.error('❌ Lambda error:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({ error: 'Internal server error', message: error.message }),
    };
  }
};

/**
 * Get driver profile with fallback + migration to primary id (Cognito sub)
 */
async function getDriverProfile(username, fallbackDriverIds, accessToken, headers) {
  if (!username) {
    return {
      statusCode: 401,
      headers,
      body: JSON.stringify({ error: 'Unauthorized - No username found' }),
    };
  }

  try {
    const { profile } = await ensureProfileUnderPrimaryId(username, fallbackDriverIds, accessToken);

    if (!profile) {
      return {
        statusCode: 404,
        headers,
        body: JSON.stringify({ error: 'Driver profile not found' }),
      };
    }

    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({ data: profile }),
    };
  } catch (error) {
    console.error('Error getting profile:', error);
    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({ error: 'Failed to get profile', message: error.message }),
    };
  }
}

/**
 * Create new driver profile
 */
async function createDriverProfile(username, fallbackDriverIds, accessToken, body, headers) {
  if (!username) {
    return {
      statusCode: 401,
      headers,
      body: JSON.stringify({ error: 'Unauthorized' }),
    };
  }

  try {
    // If there is an existing profile under an old key, migrate it instead of creating a duplicate.
    const existing = await ensureProfileUnderPrimaryId(username, fallbackDriverIds, accessToken);
    if (existing.profile) {
      return {
        statusCode: 200,
        headers,
        body: JSON.stringify({
          message: 'Profile already exists',
          data: existing.profile,
        }),
      };
    }

    const now = new Date().toISOString();
    
    // Build profile with new schema
    const profile = {
      driverId: username,
      
      // Registration method tracking
      registrationMethod: body.registrationMethod || 'phone', // 'phone' | 'email'
      
      // Contact information (at least one required)
      phoneNumber: body.phoneNumber || null,
      email: body.email || null,
      
      // Profile status
      status: body.status || 'PENDING_PROFILE',
      
      // Timestamps
      createdAt: now,
      updatedAt: now,
      verifiedAt: body.verifiedAt || now,
      profileCompletedAt: null, // Set when profile is completed
      
      // Basic info (filled during profile setup)
      name: body.name || null,
      city: body.city || null,
      vehicleType: body.vehicleType || null,
      licenseNumber: body.licenseNumber || null,
      nationalId: body.nationalId || null,
      
      // Document URLs (filled during profile setup)
      drivingLicenseUrl: body.drivingLicenseUrl || null,
      registrationPaperUrl: body.registrationPaperUrl || null,
      
      // Additional fields
      isActive: body.isActive !== undefined ? body.isActive : true,
      isOnline: false,
    };

    await dynamodb.send(new PutCommand({
      TableName: DRIVERS_TABLE,
      Item: profile,
    }));

    console.log('✅ Profile created:', profile);

    return {
      statusCode: 201,
      headers,
      body: JSON.stringify({ 
        message: 'Profile created successfully',
        data: profile 
      }),
    };
  } catch (error) {
    console.error('Error creating profile:', error);
    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({ error: 'Failed to create profile', message: error.message }),
    };
  }
}

/**
 * Update driver profile
 */
async function updateDriverProfile(username, fallbackDriverIds, accessToken, body, headers) {
  if (!username) {
    return {
      statusCode: 401,
      headers,
      body: JSON.stringify({ error: 'Unauthorized' }),
    };
  }

  try {
    // Ensure profile exists (migrate from old key, or create skeleton) so profile setup can proceed.
    await ensureProfileExists(username, fallbackDriverIds, accessToken);

    console.log('📝 Update profile received body:', JSON.stringify(body, null, 2));
    
    const now = new Date().toISOString();
    
    // Build update expression dynamically
    const updates = [];
    const expressionAttributeNames = {};
    const expressionAttributeValues = {};
    
    // Fields that can be updated
    const updatableFields = [
      'name', 'city', 'vehicleType', 'licenseNumber', 'nationalId',
      'phoneNumber', 'email', 'registrationMethod',
      'drivingLicenseUrl', 'registrationPaperUrl',
      'status', 'isActive', 'isOnline',
      // ✨ New region and address fields
      'home_region_id', 'home_region_name', 'home_address_text',
      'governorate_id', 'governorate_name',
      'parent_district_id', 'parent_district_name'
    ];

    let fieldCount = 0;
    for (const field of updatableFields) {
      console.log(`🔍 Checking field '${field}': value=${body[field]}, type=${typeof body[field]}, included=${body[field] !== undefined && body[field] !== null}`);
      if (body[field] !== undefined && body[field] !== null) {
        const placeholder = `:val${fieldCount}`;
        updates.push(`#${field} = ${placeholder}`);
        expressionAttributeNames[`#${field}`] = field;
        expressionAttributeValues[placeholder] = body[field];
        fieldCount++;
      }
    }

    // Always update updatedAt
    updates.push('#updatedAt = :updatedAt');
    expressionAttributeNames['#updatedAt'] = 'updatedAt';
    expressionAttributeValues[':updatedAt'] = now;

    // Check if profile is being completed (has all required fields)
    if (body.status === 'ACTIVE' || isProfileComplete(body)) {
      updates.push('#profileCompletedAt = :profileCompletedAt');
      expressionAttributeNames['#profileCompletedAt'] = 'profileCompletedAt';
      expressionAttributeValues[':profileCompletedAt'] = now;
      
      // Auto-set status to ACTIVE if not explicitly set
      if (!body.status) {
        updates.push('#status = :statusActive');
        expressionAttributeNames['#status'] = 'status';
        expressionAttributeValues[':statusActive'] = 'ACTIVE';
      }
    }

    if (updates.length === 0) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({ error: 'No valid fields to update' }),
      };
    }

    const updateExpression = 'SET ' + updates.join(', ');

    console.log('🔄 Update expression:', updateExpression);
    console.log('🔄 Attribute names:', expressionAttributeNames);
    console.log('🔄 Attribute values:', expressionAttributeValues);

    const result = await dynamodb.send(new UpdateCommand({
      TableName: DRIVERS_TABLE,
      Key: { driverId: username },
      UpdateExpression: updateExpression,
      ExpressionAttributeNames: expressionAttributeNames,
      ExpressionAttributeValues: expressionAttributeValues,
      ReturnValues: 'ALL_NEW',
    }));

    console.log('✅ Profile updated:', result.Attributes);

    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({ 
        message: 'Profile updated successfully',
        data: result.Attributes 
      }),
    };
  } catch (error) {
    console.error('Error updating profile:', error);
    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({ error: 'Failed to update profile', message: error.message }),
    };
  }
}

/**
 * Get profile completion status
 */
async function getProfileStatus(username, fallbackDriverIds, accessToken, headers) {
  if (!username) {
    return {
      statusCode: 401,
      headers,
      body: JSON.stringify({ error: 'Unauthorized' }),
    };
  }

  try {
    const { profile } = await ensureProfileUnderPrimaryId(username, fallbackDriverIds, accessToken);

    if (!profile) {
      return {
        statusCode: 200,
        headers,
        body: JSON.stringify({ 
          profileExists: false,
          status: 'PENDING_PROFILE',
          isComplete: false,
          missingFields: ['all']
        }),
      };
    }

    const missingFields = [];
    
    // Check required fields
    if (!profile.name) missingFields.push('name');
    if (!profile.city) missingFields.push('city');
    if (!profile.vehicleType) missingFields.push('vehicleType');
    if (!profile.licenseNumber) missingFields.push('licenseNumber');
    if (!profile.nationalId) missingFields.push('nationalId');
    if (!profile.drivingLicenseUrl) missingFields.push('drivingLicenseUrl');
    
    // Registration paper required for car/motorcycle
    if ((profile.vehicleType === 'car' || profile.vehicleType === 'motorcycle') 
        && !profile.registrationPaperUrl) {
      missingFields.push('registrationPaperUrl');
    }

    const isComplete = missingFields.length === 0;

    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({
        profileExists: true,
        status: profile.status || 'PENDING_PROFILE',
        isComplete,
        missingFields,
        profileCompletedAt: profile.profileCompletedAt || null,
      }),
    };
  } catch (error) {
    console.error('Error getting profile status:', error);
    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({ error: 'Failed to get profile status', message: error.message }),
    };
  }
}

/**
 * Check if profile has all required fields
 */
function isProfileComplete(profile) {
  const requiredFields = ['name', 'city', 'vehicleType', 'licenseNumber', 'nationalId', 'drivingLicenseUrl'];
  
  for (const field of requiredFields) {
    if (!profile[field]) return false;
  }
  
  // Check registration paper for car/motorcycle
  if ((profile.vehicleType === 'car' || profile.vehicleType === 'motorcycle') 
      && !profile.registrationPaperUrl) {
    return false;
  }
  
  return true;
}

/**
 * Upload driver document (base64) and store in S3
 * POST /driver/documents/upload
 * Body: { documentType, fileName, contentType, fileData, phoneNumber? }
 */
async function uploadDriverDocument(username, fallbackDriverIds, accessToken, body, headers) {
  if (!username) {
    return {
      statusCode: 401,
      headers,
      body: JSON.stringify({ success: false, message: 'Unauthorized' }),
    };
  }

  if (!DRIVER_DOCUMENTS_BUCKET) {
    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({ success: false, message: 'Document storage not configured' }),
    };
  }

  try {
    const documentType = body.documentType;
    const fileName = body.fileName;
    const contentType = body.contentType;
    const fileData = body.fileData;

    if (!documentType || !fileName || !contentType || !fileData) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({ success: false, message: 'Missing required fields' }),
      };
    }

    // Ensure profile exists so subsequent PUT /driver/me doesn't 404.
    await ensureProfileExists(username, fallbackDriverIds, accessToken);

    const now = new Date().toISOString();
    const safeFileName = String(fileName).replace(/[^a-zA-Z0-9._-]/g, '_');
    const key = `drivers/${username}/${documentType}/${now}_${safeFileName}`;
    const buffer = Buffer.from(String(fileData), 'base64');

    await s3.send(new PutObjectCommand({
      Bucket: DRIVER_DOCUMENTS_BUCKET,
      Key: key,
      Body: buffer,
      ContentType: contentType,
    }));

    const documentUrl = `s3://${DRIVER_DOCUMENTS_BUCKET}/${key}`;

    // Persist onto profile for completeness checks.
    const urlField = documentType === 'driving_license'
      ? 'drivingLicenseUrl'
      : documentType === 'registration_paper'
        ? 'registrationPaperUrl'
        : null;

    if (urlField) {
      await dynamodb.send(new UpdateCommand({
        TableName: DRIVERS_TABLE,
        Key: { driverId: username },
        UpdateExpression: 'SET #urlField = :url, #updatedAt = :updatedAt',
        ExpressionAttributeNames: {
          '#urlField': urlField,
          '#updatedAt': 'updatedAt',
        },
        ExpressionAttributeValues: {
          ':url': documentUrl,
          ':updatedAt': now,
        },
      }));
    }

    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({
        success: true,
        documentUrl,
        message: 'تم رفع المستند بنجاح',
      }),
    };
  } catch (error) {
    console.error('❌ Document upload failed:', error);
    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({ success: false, message: 'فشل رفع المستند', error: error.message }),
    };
  }
}

/**
 * ✨ Start searching for orders
 * POST /driver/start-searching
 * Body: { lat: number, lng: number, deviceInfo?: object }
 */
async function startSearching(driverId, body, headers) {
  try {
    const { lat, lng, deviceInfo } = body;

    if (!lat || !lng) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({ 
          success: false, 
          message: 'الإحداثيات مطلوبة (lat, lng)' 
        })
      };
    }

    console.log(`📍 Driver ${driverId} requesting to start searching at (${lat}, ${lng})`);

    // ============================================
    // الخطوة 1: التحقق من حالة السائق
    // ============================================
    const driverResult = await dynamodb.send(new GetCommand({
      TableName: DRIVERS_TABLE,
      Key: { driverId }
    }));

    if (!driverResult.Item) {
      return {
        statusCode: 404,
        headers,
        body: JSON.stringify({ 
          success: false, 
          message: 'السائق غير موجود' 
        })
      };
    }

    const driver = driverResult.Item;

    // فحص الحالة
    if (driver.status !== 'ACTIVE') {
      return {
        statusCode: 403,
        headers,
        body: JSON.stringify({ 
          success: false, 
          message: 'حسابك غير مؤهل حاليًا لاستلام الطلبات' 
        })
      };
    }

    if (driver.status === 'BANNED' || driver.status === 'SUSPENDED') {
      return {
        statusCode: 403,
        headers,
        body: JSON.stringify({ 
          success: false, 
          message: 'تم إيقاف حسابك. تواصل مع الدعم' 
        })
      };
    }

    // ============================================
    // الخطوة 2: تحديد المنطقة الحالية
    // ============================================
    const regionInfo = await determineRegionFromCoordinates(lat, lng, driver);

    if (!regionInfo) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({ 
          success: false, 
          message: 'لا يمكن تحديد المنطقة من موقعك الحالي' 
        })
      };
    }

    const { 
      region_id, 
      region_name, 
      district_id, 
      district_name, 
      governorate_id, 
      governorate_name,
      is_active 
    } = regionInfo;

    // فحص: هل المنطقة نشطة؟
    if (!is_active) {
      return {
        statusCode: 403,
        headers,
        body: JSON.stringify({ 
          success: false, 
          message: `خدمة التوصيل غير متوفرة في منطقة ${region_name}` 
        })
      };
    }

    // فحص: هل السائق مسموح له بالعمل في هذه المنطقة؟
    console.log(`🔍 فحص صلاحيات السائق:`);
    console.log(`   - home_region_id: ${driver.home_region_id}`);
    console.log(`   - home_region_level: ${driver.home_region_level || 3}`);
    console.log(`   - target region_id: ${region_id}`);
    console.log(`   - target region_name: ${region_name}`);
    console.log(`   - target region_level: ${regionInfo.region_level || 3}`);
    console.log(`   - home_governorate_id: ${driver.governorate_id}`);
    console.log(`   - target governorate_id: ${governorate_id}`);
    console.log(`   - driver level: ${driver.level || 'Bronze (default)'}`);
    
    const permission = await checkDriverRegionPermission(
      driverId, 
      driver.home_region_id,
      driver.home_region_level || 3,
      region_id,
      regionInfo.region_level || 3,
      governorate_id,
      driver.governorate_id,
      driver.level
    );

    console.log(`✅ نتيجة فحص الصلاحيات: allowed=${permission.allowed}`);

    if (!permission.allowed) {
      return {
        statusCode: 403,
        headers,
        body: JSON.stringify({ 
          success: false, 
          message: `لا يمكنك العمل في ${region_name}. ${permission.suggestion}` 
        })
      };
    }

    // ============================================
    // الخطوة 3: البحث عن WebSocket Connection (اختياري)
    // ============================================
    console.log(`🔍 Searching for WebSocket connection for driver: ${driverId}`);
    
    let connectionId = null;
    
    try {
      // ✅ Support both connection table schemas:
      // - staging: connectionId hash key + GSI (userId-connectedAt-index)
      // - dev/legacy: PK/SK + GSI1 (GSI1PK = DRIVER#<id>)
      let connectionResult = null;

      // 1) Try staging index first (fast + ordered by connectedAt)
      try {
        connectionResult = await dynamodb.send(new QueryCommand({
          TableName: WEBSOCKET_CONNECTIONS_TABLE,
          IndexName: 'userId-connectedAt-index',
          KeyConditionExpression: 'userId = :userId',
          ScanIndexForward: false,
          Limit: 10,
          FilterExpression: 'isActive = :active AND (#status = :activeStatus OR #status = :connectedStatus) AND entityType = :driver',
          ExpressionAttributeNames: { '#status': 'status' },
          ExpressionAttributeValues: {
            ':userId': driverId,
            ':active': true,
            ':activeStatus': 'active',
            ':connectedStatus': 'connected',
            ':driver': 'driver'
          }
        }));
      } catch (stagingIndexError) {
        // Index may not exist in dev/legacy
        console.log(`ℹ️ userId-connectedAt-index not available; trying GSI1...`);
      }

      // 2) Fallback to legacy GSI1 (dev)
      if (!connectionResult) {
        connectionResult = await dynamodb.send(new QueryCommand({
          TableName: WEBSOCKET_CONNECTIONS_TABLE,
          IndexName: 'GSI1',
          KeyConditionExpression: 'GSI1PK = :gsi1pk',
          FilterExpression: 'isActive = :active AND (#status = :activeStatus OR #status = :connectedStatus)',
          ExpressionAttributeNames: { '#status': 'status' },
          ExpressionAttributeValues: {
            ':gsi1pk': `DRIVER#${driverId}`,
            ':active': true,
            ':activeStatus': 'active',
            ':connectedStatus': 'connected'
          }
        }));
      }
      
      if (connectionResult.Items && connectionResult.Items.length > 0) {
        // ✅ FIX: إذا كان هناك عدة اتصالات، أخذ الأحدث حسب lastHeartbeat
        const sortedConnections = connectionResult.Items.sort((a, b) => {
          const aTime = new Date(a.lastHeartbeat || a.connectedAt || 0).getTime();
          const bTime = new Date(b.lastHeartbeat || b.connectedAt || 0).getTime();
          return bTime - aTime; // الأحدث أولاً
        });
        
        connectionId = sortedConnections[0].connectionId;
        console.log(`✅ Found ${connectionResult.Items.length} WebSocket connection(s), using latest: ${connectionId}`);
        if (connectionResult.Items.length > 1) {
          console.log(`⚠️ Driver has ${connectionResult.Items.length} active connections - using most recent`);
        }
      } else {
        console.log(`ℹ️ No WebSocket connection yet - will be updated when driver connects`);
      }
    } catch (queryError) {
      console.warn(`⚠️ Error querying connection (non-critical):`, queryError);
      console.log(`ℹ️ Continuing without connectionId - will be synced on WebSocket connect`);
    }

    // ============================================
    // الخطوة 4: حساب المناطق المسموحة والمقاييس (Wave System)
    // ============================================
    console.log('🌊 Wave System: Calculating allowed regions and metrics snapshot...');
    
    // 4.1: حساب المناطق المسموحة من RegionNeighbors
    const allowedRegions = await calculateAllowedRegions(region_id);
    
    // 4.2: جلب snapshot للمقاييس من WizzDriverPerformanceMetrics
    const metricsSnapshot = await getDriverMetricsSnapshot(driverId);

    // ============================================
    // الخطوة 5: تحديث WizzDriverLiveState
    // ============================================
    const now = new Date().toISOString();
    
    // 🔄 الحصول على الحالة الحالية للسائق (للحفاظ على currentOrderId إذا كان موجوداً)
    let finalConnectionId = connectionId;
    let existingCurrentOrderId = null;
    let existingActiveOrdersCount = 0;
    
    const existingState = await dynamodb.send(new GetCommand({
      TableName: DRIVER_LIVE_STATE_TABLE,
      Key: { driverId }
    }));
    
    if (existingState.Item) {
      if (!finalConnectionId && existingState.Item.connectionId) {
        finalConnectionId = existingState.Item.connectionId;
        console.log(`ℹ️ Using existing connectionId from LiveState: ${finalConnectionId}`);
      }
      
      // 🚨 الحفاظ على currentOrderId و activeOrdersCount إذا كان السائق لديه طلب نشط
      if (existingState.Item.currentOrderId) {
        existingCurrentOrderId = existingState.Item.currentOrderId;
        existingActiveOrdersCount = existingState.Item.activeOrdersCount || 1;
        console.log(`🚨 CRITICAL: Driver has active order ${existingCurrentOrderId} - preserving it!`);
      }
    }

    // ⚠️ إذا كان لدى السائق طلب نشط، نستخدم UpdateCommand بدلاً من PutCommand
    // لتجنب حذف currentOrderId
    if (existingCurrentOrderId) {
      console.log(`🔄 Using UpdateCommand to preserve active order ${existingCurrentOrderId}`);
      
      await dynamodb.send(new UpdateCommand({
        TableName: DRIVER_LIVE_STATE_TABLE,
        Key: { driverId },
        UpdateExpression: `
          SET #status = :status,
              isActive = :isActive,
              isSearching = :isSearching,
              connectionStatus = :connectionStatus,
              connectionId = :connectionId,
              lat = :lat,
              lng = :lng,
              locationUpdatedAt = :now,
              current_work_region_id = :region_id,
              parent_district_id = :district_id,
              governorate_id = :governorate_id,
              region_mode = :region_mode,
              home_region_id = :home_region_id,
              allowed_region_ids = :allowed_region_ids,
              allowed_region_ids_priority0 = :allowed_region_ids_priority0,
              allowed_region_ids_priority1 = :allowed_region_ids_priority1,
              metricsSnapshot_acceptanceRate = :metricsSnapshot_acceptanceRate,
              metricsSnapshot_completionRate = :metricsSnapshot_completionRate,
              metricsSnapshot_responseRate = :metricsSnapshot_responseRate,
              metricsSnapshot_consecutiveRejections = :metricsSnapshot_consecutiveRejections,
              metricsSnapshot_totalOffersWindow = :metricsSnapshot_totalOffersWindow,
              metricsSnapshot_totalTrips = :metricsSnapshot_totalTrips,
              currentWaveOfferId = :null,
              searchStartedAt = :now,
              lastOnlineAt = :now,
              lastUpdated = :now
        `,
        ExpressionAttributeNames: {
          '#status': 'status'
        },
        ExpressionAttributeValues: {
          ':status': 'busy', // السائق مشغول بطلب نشط
          ':isActive': true,
          ':isSearching': true, // يمكن للسائق البحث عن طلبات جديدة أثناء تنفيذ طلب
          ':connectionStatus': 'connected',
          ':connectionId': finalConnectionId,
          ':lat': lat,
          ':lng': lng,
          ':region_id': region_id,
          ':district_id': district_id,
          ':governorate_id': governorate_id,
          ':region_mode': region_id === driver.home_region_id ? 'home' : 'custom',
          ':home_region_id': driver.home_region_id || region_id,
          ':allowed_region_ids': allowedRegions.all,
          ':allowed_region_ids_priority0': allowedRegions.priority0,
          ':allowed_region_ids_priority1': allowedRegions.priority1,
          ':metricsSnapshot_acceptanceRate': metricsSnapshot.acceptanceRate,
          ':metricsSnapshot_completionRate': metricsSnapshot.completionRate,
          ':metricsSnapshot_responseRate': metricsSnapshot.responseRate,
          ':metricsSnapshot_consecutiveRejections': metricsSnapshot.consecutiveRejections,
          ':metricsSnapshot_totalOffersWindow': metricsSnapshot.totalOffersWindow,
          ':metricsSnapshot_totalTrips': metricsSnapshot.totalTrips || 0,
          ':null': null,
          ':now': now
        }
      }));
      
      console.log(`✅ Driver ${driverId} state updated while preserving active order ${existingCurrentOrderId}`);
      
    } else {
      // السائق ليس لديه طلب نشط - يمكن استخدام PutCommand بأمان
      console.log(`✅ No active order - using PutCommand for fresh state`);
      
      await dynamodb.send(new PutCommand({
        TableName: DRIVER_LIVE_STATE_TABLE,
        Item: {
          driverId: driverId,

          // حالة السائق
          status: 'available',
          isActive: true,
          isSearching: true,              // ⭐ المفتاح!

          // الاتصال
          connectionStatus: 'connected',
          connectionId: finalConnectionId,

          // الموقع الحالي
          lat: lat,
          lng: lng,
          locationUpdatedAt: now,

          // المنطقة الحالية
          current_work_region_id: region_id,
          parent_district_id: district_id,
          governorate_id: governorate_id,
          region_mode: region_id === driver.home_region_id ? 'home' : 'custom',

          // ✨ Wave System: المنطقة المنزلية والمناطق المسموحة
          home_region_id: driver.home_region_id || region_id,
          allowed_region_ids: allowedRegions.all,
          allowed_region_ids_priority0: allowedRegions.priority0,
          allowed_region_ids_priority1: allowedRegions.priority1,

          // ✨ Wave System: Snapshot للمقاييس
          metricsSnapshot_acceptanceRate: metricsSnapshot.acceptanceRate,
          metricsSnapshot_completionRate: metricsSnapshot.completionRate,
          metricsSnapshot_responseRate: metricsSnapshot.responseRate, // ✨ NEW
          metricsSnapshot_consecutiveRejections: metricsSnapshot.consecutiveRejections,
          metricsSnapshot_totalOffersWindow: metricsSnapshot.totalOffersWindow,
          metricsSnapshot_totalTrips: metricsSnapshot.totalTrips || 0,

          // ✨ Wave System: معلومات الطلب/العرض الحالي
          currentOrderId: null,
          currentWaveOfferId: null,

          // معلومات الوردية
          searchStartedAt: now,
          shiftStartTime: now,
          lastOnlineAt: now,
          lastUpdated: now,

          // الأداء
          activeOrdersCount: 0
        }
      }));
    }

    console.log(`✅ Driver ${driverId} is now searching in ${region_name}`);
    console.log(`🌊 Wave System fields added: allowed_region_ids=${allowedRegions.all.length}, metrics snapshot ready`);

    // ============================================
    // الخطوة 6: الرد للتطبيق
    // ============================================
    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({
        success: true,
        status: 'searching',
        message: `تم تفعيل البحث عن الطلبات في منطقة: ${region_name}`,
        data: {
          current_work_region: {
            id: region_id,
            name: region_name,
            district_name: district_name,
            governorate_name: governorate_name
          },
          driver_level: driver.level || 'Bronze',
          started_at: now
        }
      })
    };

  } catch (error) {
    console.error('❌ Error in start-searching:', error);
    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({ 
        success: false, 
        message: 'حدث خطأ غير متوقع',
        error: error.message 
      })
    };
  }
}

/**
 * ✨ Stop searching for orders
 * POST /driver/stop-searching
 * 
 * Enhanced for Wave System:
 * - Checks for pending wave offers
 * - Checks for active orders
 * - Cleans up currentWaveOfferId and currentOrderId
 */
async function stopSearching(driverId, body, headers) {
  try {
    console.log(`🛑 Driver ${driverId} stopping search`);

    // ============================================
    // الخطوة 1: جلب الحالة الحالية
    // ============================================
    const liveStateResult = await dynamodb.send(new GetCommand({
      TableName: DRIVER_LIVE_STATE_TABLE,
      Key: { driverId }
    }));

    if (!liveStateResult.Item) {
      console.warn(`⚠️ Driver ${driverId} has no live state`);
      return {
        statusCode: 404,
        headers,
        body: JSON.stringify({
          success: false,
          message: 'حالة السائق غير موجودة'
        })
      };
    }

    const currentState = liveStateResult.Item;

    // ============================================
    // الخطوة 2: التحقق من وجود طلب نشط
    // ============================================
    if (currentState.currentOrderId) {
      console.warn(`⚠️ Driver ${driverId} has active order ${currentState.currentOrderId}`);
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({
          success: false,
          message: 'لا يمكن إيقاف البحث أثناء وجود طلب نشط',
          activeOrderId: currentState.currentOrderId
        })
      };
    }

    // ============================================
    // الخطوة 3: معالجة العرض المعلق (إن وجد)
    // ============================================
    let pendingOfferInfo = null;
    if (currentState.currentWaveOfferId) {
      console.log(`🌊 Wave System: Driver has pending offer ${currentState.currentWaveOfferId}`);
      pendingOfferInfo = {
        offerId: currentState.currentWaveOfferId,
        status: 'cancelled_by_driver_stop'
      };
      
      // ملاحظة: سيتم تحديث WaveOffers في الجزء 5 (Wave Management)
      // حالياً نقوم فقط بتنظيف currentWaveOfferId
    }

    // ============================================
    // الخطوة 4: تحديث WizzDriverLiveState
    // ============================================
    const now = new Date().toISOString();
    
    await dynamodb.send(new UpdateCommand({
      TableName: DRIVER_LIVE_STATE_TABLE,
      Key: { driverId },
      UpdateExpression: `
        SET isSearching = :false,
            #status = :offline,
            isActive = :inactive,
            searchStoppedAt = :now,
            lastUpdated = :now,
            currentWaveOfferId = :null,
            stopReason = :reason
      `,
      ExpressionAttributeNames: {
        '#status': 'status'
      },
      ExpressionAttributeValues: {
        ':false': false,
        ':offline': 'offline',
        ':inactive': false,
        ':now': now,
        ':null': null,
        ':reason': 'manual_stop'
      }
    }));

    console.log(`✅ Driver ${driverId} stopped searching successfully`);
    if (pendingOfferInfo) {
      console.log(`   🌊 Cleared pending offer: ${pendingOfferInfo.offerId}`);
    }

    // ============================================
    // الخطوة 5: الرد للتطبيق
    // ============================================
    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({
        success: true,
        message: 'تم إيقاف البحث عن الطلبات',
        data: {
          searchDuration: currentState.searchStartedAt 
            ? Math.floor((new Date(now) - new Date(currentState.searchStartedAt)) / 1000) 
            : 0,
          hadPendingOffer: !!pendingOfferInfo,
          stoppedAt: now
        }
      })
    };

  } catch (error) {
    console.error('❌ Error in stop-searching:', error);
    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({ 
        success: false, 
        message: 'حدث خطأ في إيقاف البحث',
        error: error.message 
      })
    };
  }
}

/**
 * ✨ Update driver location during active searching
 * POST /driver/update-location
 * Body: { lat: number, lng: number }
 * 
 * تحديث موقع السائق أثناء البحث عن الطلبات
 * يعيد حساب current_work_region_id إذا انتقل السائق لمنطقة جديدة
 */
async function updateLocation(driverId, body, headers) {
  try {
    const { lat, lng } = body;

    if (!lat || !lng) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({ 
          success: false, 
          message: 'الإحداثيات مطلوبة (lat, lng)' 
        })
      };
    }

    console.log(`📍 Driver ${driverId} updating location to (${lat}, ${lng})`);

    // ============================================
    // الخطوة 1: جلب حالة السائق الحالية
    // ============================================
    const liveStateResult = await dynamodb.send(new GetCommand({
      TableName: DRIVER_LIVE_STATE_TABLE,
      Key: { driverId }
    }));

    if (!liveStateResult.Item) {
      return {
        statusCode: 404,
        headers,
        body: JSON.stringify({ 
          success: false, 
          message: 'حالة السائق غير موجودة. قم بتفعيل البحث أولاً' 
        })
      };
    }

    const currentState = liveStateResult.Item;

    // التحقق من أن السائق في حالة بحث
    if (!currentState.isSearching) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({ 
          success: false, 
          message: 'السائق ليس في حالة بحث عن الطلبات' 
        })
      };
    }

    // ============================================
    // الخطوة 2: جلب بيانات السائق الأساسية
    // ============================================
    const driverResult = await dynamodb.send(new GetCommand({
      TableName: DRIVERS_TABLE,
      Key: { driverId }
    }));

    if (!driverResult.Item) {
      return {
        statusCode: 404,
        headers,
        body: JSON.stringify({ 
          success: false, 
          message: 'السائق غير موجود' 
        })
      };
    }

    const driver = driverResult.Item;

    // ============================================
    // الخطوة 3: تحديد المنطقة الجديدة من الموقع
    // ============================================
    const regionInfo = await determineRegionFromCoordinates(lat, lng, driver);

    if (!regionInfo) {
      console.warn(`⚠️ Could not determine region for location (${lat}, ${lng})`);
      // نستمر بتحديث الإحداثيات حتى لو لم نستطع تحديد المنطقة
      await dynamodb.send(new UpdateCommand({
        TableName: DRIVER_LIVE_STATE_TABLE,
        Key: { driverId },
        UpdateExpression: `
          SET lat = :lat,
              lng = :lng,
              locationUpdatedAt = :now,
              lastUpdated = :now
        `,
        ExpressionAttributeValues: {
          ':lat': lat,
          ':lng': lng,
          ':now': new Date().toISOString()
        }
      }));

      return {
        statusCode: 200,
        headers,
        body: JSON.stringify({
          success: true,
          location_updated: true,
          region_changed: false,
          message: 'تم تحديث الموقع (منطقة غير محددة)'
        })
      };
    }

    const { region_id, region_name, district_id, district_name, governorate_id, governorate_name, is_active } = regionInfo;

    // فحص: هل المنطقة الجديدة نشطة؟
    if (!is_active) {
      return {
        statusCode: 403,
        headers,
        body: JSON.stringify({ 
          success: false, 
          message: `خدمة التوصيل غير متوفرة في منطقة ${region_name}` 
        })
      };
    }

    // ============================================
    // الخطوة 4: مقارنة المنطقة الحالية مع السابقة
    // ============================================
    const previousRegionId = currentState.current_work_region_id;
    const regionChanged = previousRegionId !== region_id;

    console.log(`📊 Region comparison: ${previousRegionId} → ${region_id} (changed: ${regionChanged})`);

    // إذا تغيرت المنطقة، نفحص الصلاحيات
    if (regionChanged) {
      const permission = await checkDriverRegionPermission(
        driverId, 
        driver.home_region_id, 
        region_id, 
        governorate_id,
        driver.governorate_id,
        driver.level
      );

      if (!permission.allowed) {
        // السائق دخل منطقة غير مسموح له بالعمل فيها
        console.warn(`⚠️ Driver ${driverId} entered unauthorized region ${region_name}`);
        
        // إيقاف البحث تلقائياً
        await dynamodb.send(new UpdateCommand({
          TableName: DRIVER_LIVE_STATE_TABLE,
          Key: { driverId },
          UpdateExpression: `
            SET isSearching = :false,
                #status = :offline,
                lat = :lat,
                lng = :lng,
                locationUpdatedAt = :now,
                searchStoppedAt = :now,
                lastUpdated = :now,
                stopReason = :reason
          `,
          ExpressionAttributeNames: {
            '#status': 'status'
          },
          ExpressionAttributeValues: {
            ':false': false,
            ':offline': 'offline',
            ':lat': lat,
            ':lng': lng,
            ':now': new Date().toISOString(),
            ':reason': `دخول منطقة غير مصرح بها: ${region_name}`
          }
        }));

        return {
          statusCode: 403,
          headers,
          body: JSON.stringify({ 
            success: false, 
            searching_stopped: true,
            message: `لا يمكنك العمل في ${region_name}. ${permission.suggestion}`,
            data: {
              unauthorized_region: region_name,
              current_level: driver.level || 'Bronze'
            }
          })
        };
      }
    }

    // ============================================
    // الخطوة 5: تحديث WizzDriverLiveState
    // ============================================
    const now = new Date().toISOString();

    // 🌊 Wave System: إذا تغيرت المنطقة، نعيد حساب allowed_region_ids
    if (regionChanged) {
      console.log('🌊 Wave System: Region changed, recalculating allowed_region_ids...');
      
      const allowedRegions = await calculateAllowedRegions(region_id);

      await dynamodb.send(new UpdateCommand({
        TableName: DRIVER_LIVE_STATE_TABLE,
        Key: { driverId },
        UpdateExpression: `
          SET lat = :lat,
              lng = :lng,
              current_work_region_id = :regionId,
              parent_district_id = :districtId,
              governorate_id = :governorateId,
              region_mode = :regionMode,
              allowed_region_ids = :allowedAll,
              allowed_region_ids_priority0 = :allowedP0,
              allowed_region_ids_priority1 = :allowedP1,
              locationUpdatedAt = :now,
              lastUpdated = :now
        `,
        ExpressionAttributeValues: {
          ':lat': lat,
          ':lng': lng,
          ':regionId': region_id,
          ':districtId': district_id,
          ':governorateId': governorate_id,
          ':regionMode': region_id === driver.home_region_id ? 'home' : 'custom',
          ':allowedAll': allowedRegions.all,
          ':allowedP0': allowedRegions.priority0,
          ':allowedP1': allowedRegions.priority1,
          ':now': now
        }
      }));

      console.log(`✅ Driver ${driverId} location & allowed_region_ids updated for ${region_name}`);
    } else {
      // 🌊 Wave System: المنطقة لم تتغير، فقط نحدث lat/lng (98% من الحالات)
      await dynamodb.send(new UpdateCommand({
        TableName: DRIVER_LIVE_STATE_TABLE,
        Key: { driverId },
        UpdateExpression: `
          SET lat = :lat,
              lng = :lng,
              current_work_region_id = :regionId,
              parent_district_id = :districtId,
              governorate_id = :governorateId,
              region_mode = :regionMode,
              locationUpdatedAt = :now,
              lastUpdated = :now
        `,
        ExpressionAttributeValues: {
          ':lat': lat,
          ':lng': lng,
          ':regionId': region_id,
          ':districtId': district_id,
          ':governorateId': governorate_id,
          ':regionMode': region_id === driver.home_region_id ? 'home' : 'custom',
          ':now': now
        }
      }));

      console.log(`✅ Driver ${driverId} location updated (same region: ${region_name})`);
    }

    // ============================================
    // الخطوة 6: الرد للتطبيق
    // ============================================
    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({
        success: true,
        location_updated: true,
        region_changed: regionChanged,
        message: regionChanged 
          ? `انتقلت إلى منطقة: ${region_name}` 
          : 'تم تحديث الموقع',
        data: {
          current_work_region: {
            id: region_id,
            name: region_name,
            district_name: district_name,
            governorate_name: governorate_name
          },
          previous_region_id: previousRegionId,
          region_mode: region_id === driver.home_region_id ? 'home' : 'custom'
        }
      })
    };

  } catch (error) {
    console.error('❌ Error in update-location:', error);
    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({ 
        success: false, 
        message: 'حدث خطأ في تحديث الموقع',
        error: error.message 
      })
    };
  }
}

/**
 * 🗺️ تحديد المنطقة من الإحداثيات باستخدام H3 Geospatial Index
 */
async function determineRegionFromCoordinates(lat, lng, driver) {
  if (!lat || !lng) {
    console.error('❌ Missing coordinates');
    return null;
  }
  
  try {
    const latitude = parseFloat(lat);
    const longitude = parseFloat(lng);
    
    console.log(`📍 Finding region for coordinates: (${latitude}, ${longitude})`);
    console.log(`📊 Using tables: RegionIndex=${REGION_INDEX_TABLE}, Regions=${REGIONS_TABLE}`);
    
    // توليد H3 cell عند الدقة 9 (نفس دقة تطبيق المستخدم)
    const h3Cell = h3.latLngToCell(latitude, longitude, H3_RESOLUTION);
    console.log(`🔷 Generated H3 cell: ${h3Cell} (resolution ${H3_RESOLUTION})`);
    console.log(`🔷 H3 cell details: lat=${latitude}, lng=${longitude}, resolution=${H3_RESOLUTION}`);
    
    // ✅ محاولة مطابقة دقيقة - البحث عن جميع المطابقات واختيار Level 3 أولاً
    console.log(`🔍 Searching in ${REGION_INDEX_TABLE} for cell: ${h3Cell}`);
    
    // Query بدلاً من Get للحصول على جميع المطابقات
    const allMatches = await dynamodb.send(new QueryCommand({
      TableName: REGION_INDEX_TABLE,
      KeyConditionExpression: 'index_cell_id = :cellId',
      ExpressionAttributeValues: {
        ':cellId': h3Cell
      }
    }));
    
    if (allMatches.Items && allMatches.Items.length > 0) {
      console.log(`✅ Found ${allMatches.Items.length} matches for H3 cell ${h3Cell}`);
      
      // ⭐ ترتيب حسب Level: نفضل Level 3 (child) على Level 2 (parent)
      const sortedMatches = allMatches.Items.sort((a, b) => {
        const levelA = parseInt(a.level) || 0;
        const levelB = parseInt(b.level) || 0;
        return levelB - levelA; // Level 3 أولاً، ثم 2، ثم 1
      });
      
      const bestMatch = sortedMatches[0];
      console.log(`🎯 BEST MATCH SELECTED!`);
      console.log(`   Region ID: ${bestMatch.regionId}`);
      console.log(`   Region Name: ${bestMatch.region_name}`);
      console.log(`   Level: ${bestMatch.level} ⭐ (highest level from ${allMatches.Items.length} matches)`);
      console.log(`   Center: (${bestMatch.center_lat}, ${bestMatch.center_lng})`);
      
      if (allMatches.Items.length > 1) {
        console.log(`   ℹ️ Other matches found:`);
        sortedMatches.slice(1).forEach((item, index) => {
          console.log(`      [${index + 1}] ${item.region_name} (Level ${item.level}) - IGNORED`);
        });
      }
      
      // جلب معلومات التسلسل الهرمي الكاملة
      const hierarchy = await getRegionFullHierarchy(bestMatch.regionId);
      
      if (hierarchy) {
        console.log(`✅ Hierarchy retrieved successfully`);
        console.log(`   Region: ${hierarchy.region_name} (${hierarchy.region_id})`);
        console.log(`   District: ${hierarchy.district_name} (${hierarchy.district_id})`);
        console.log(`   Governorate: ${hierarchy.governorate_name} (${hierarchy.governorate_id})`);
        return hierarchy;
      } else {
        console.log(`⚠️ Failed to get hierarchy for region ${bestMatch.regionId}`);
      }
    } else {
      console.log(`❌ NO EXACT MATCH - cell ${h3Cell} not found in RegionIndex`);
    }
    
    // Fallback: البحث في parent cells (دقة أقل)
    console.log('⚠️ No exact match, trying parent cells (lower resolution)...');
    for (let resolution = H3_RESOLUTION - 1; resolution >= 6; resolution--) {
      const parentCell = h3.cellToParent(h3Cell, resolution);
      console.log(`   🔍 Trying resolution ${resolution}: cell=${parentCell}`);
      
      const parentMatch = await dynamodb.send(new GetCommand({
        TableName: REGION_INDEX_TABLE,
        Key: { index_cell_id: parentCell }
      }));
      
      if (parentMatch.Item) {
        console.log(`✅ PARENT MATCH FOUND at resolution ${resolution}!`);
        console.log(`   Region ID: ${parentMatch.Item.regionId}`);
        console.log(`   Region Name: ${parentMatch.Item.region_name}`);
        console.log(`   Level: ${parentMatch.Item.level}`);
        
        // جلب معلومات التسلسل الهرمي الكاملة
        const hierarchy = await getRegionFullHierarchy(parentMatch.Item.regionId);
        
        if (hierarchy) {
          console.log(`✅ Hierarchy from parent cell:`);
          console.log(`   Region: ${hierarchy.region_name} (${hierarchy.region_id})`);
          console.log(`   District: ${hierarchy.district_name} (${hierarchy.district_id})`);
          console.log(`   Governorate: ${hierarchy.governorate_name} (${hierarchy.governorate_id})`);
          return hierarchy;
        }
      } else {
        console.log(`   ❌ No match at resolution ${resolution}`);
      }
    }
    
    console.warn(`⚠️⚠️⚠️ NO H3 MATCH FOUND - trying FALLBACK: nearest region by distance...`);
    
    // Fallback: البحث عن أقرب منطقة بالمسافة
    const nearestRegion = await findNearestRegionByDistance(latitude, longitude);
    if (nearestRegion) {
      console.log(`✅ FALLBACK SUCCESS: Using nearest region`);
      return nearestRegion;
    }
    
    console.warn(`⚠️ No region found for coordinates (${latitude}, ${longitude})`);
    return null;
    
  } catch (error) {
    console.error('❌ Error in determineRegionFromCoordinates:', error);
    return null;
  }
}

/**
 * 📍 Find nearest region by distance (fallback when H3 fails)
 */
async function findNearestRegionByDistance(lat, lng) {
  try {
    console.log(`🔍 Scanning RegionIndex for nearest region to (${lat}, ${lng})...`);
    
    // Get all level-3 regions (neighborhoods)
    const result = await dynamodb.send(new ScanCommand({
      TableName: REGION_INDEX_TABLE,
      FilterExpression: '#level = :level',
      ExpressionAttributeNames: {
        '#level': 'level'
      },
      ExpressionAttributeValues: {
        ':level': 3
      },
      ProjectionExpression: 'regionId,region_name,center_lat,center_lng'
    }));
    
    if (!result.Items || result.Items.length === 0) {
      return null;
    }
    
    // Calculate distances
    const regionsWithDistance = result.Items.map(item => {
      const distance = calculateDistance(
        lat, lng,
        parseFloat(item.center_lat),
        parseFloat(item.center_lng)
      );
      return { ...item, distance };
    });
    
    // Sort by distance and get closest
    regionsWithDistance.sort((a, b) => a.distance - b.distance);
    const nearest = regionsWithDistance[0];
    
    console.log(`✅ Nearest region: ${nearest.region_name} (${nearest.regionId}) - ${nearest.distance.toFixed(2)}km away`);
    
    // Get full hierarchy
    return await getRegionFullHierarchy(nearest.regionId);
    
  } catch (error) {
    console.error('❌ Error in findNearestRegionByDistance:', error);
    return null;
  }
}

/**
 * 🏛️ الحصول على التسلسل الهرمي الكامل للمنطقة
 * (ناحية ← قضاء ← محافظة)
 */
async function getRegionFullHierarchy(regionId) {
  try {
    if (!regionId) return null;

    // جلب المنطقة الأساسية (level 3 = ناحية)
    const regionResult = await dynamodb.send(new GetCommand({
      TableName: REGIONS_TABLE,
      Key: { regionId: regionId }
    }));

    if (!regionResult.Item) {
      console.warn(`⚠️ Region ${regionId} not found in RegionsDerived table`);
      return null;
    }

    const region = regionResult.Item;
    const districtId = region.parent_id;

    // التحقق من أن المنطقة نشطة
    const effectiveIsActiveRaw =
      region.effective_is_active ??
      region.effective?.isActive ??
      region.effective?.is_active ??
      region.is_active ??
      region.isActive;

    const isActive = (() => {
      if (effectiveIsActiveRaw === undefined || effectiveIsActiveRaw === null) {
        console.warn(
          `⚠️ Region ${regionId} missing isActive field (effective_is_active/effective.isActive). Defaulting to active.`
        );
        return true;
      }

      if (effectiveIsActiveRaw === 1 || effectiveIsActiveRaw === '1' || effectiveIsActiveRaw === true || effectiveIsActiveRaw === 'true') {
        return true;
      }

      if (effectiveIsActiveRaw === 0 || effectiveIsActiveRaw === '0' || effectiveIsActiveRaw === false || effectiveIsActiveRaw === 'false') {
        return false;
      }

      return Boolean(effectiveIsActiveRaw);
    })();
    
    // ⚠️ لا نرجع null عند is_active = false
    // بل نرجع البيانات مع is_active: false لكي يعطي startSearching رسالة واضحة
    if (!isActive) {
      console.warn(`⚠️ Region ${region.name || region.name_ar} is not active - will return data with is_active=false`);
    }

    // جلب معلومات القضاء (level 2)
    let districtName = 'غير محدد';
    let governorateId = null;
    let governorateName = 'غير محدد';

    if (districtId) {
      const districtResult = await dynamodb.send(new GetCommand({
        TableName: REGIONS_TABLE,
        Key: { regionId: districtId }
      }));

      if (districtResult.Item) {
        const district = districtResult.Item;
        districtName = district.name || district.name_ar || 'غير محدد';
        governorateId = district.parent_id;

        // جلب معلومات المحافظة (level 1)
        if (governorateId) {
          const governorateResult = await dynamodb.send(new GetCommand({
            TableName: REGIONS_TABLE,
            Key: { regionId: governorateId }
          }));

          if (governorateResult.Item) {
            governorateName = governorateResult.Item.name || governorateResult.Item.name_ar || 'غير محدد';
          }
        }
      }
    }

    return {
      region_id: regionId,
      region_name: region.name || region.name_ar || 'غير محدد',
      region_level: region.level || 3, // ← إضافة Level
      district_id: districtId,
      district_name: districtName,
      governorate_id: governorateId,
      governorate_name: governorateName,
      is_active: isActive
    };

  } catch (error) {
    console.error('❌ Error getting full region hierarchy:', error);
    return null;
  }
}

/**
 * 🏛️ الحصول على التسلسل الهرمي للمنطقة (القضاء والمحافظة)
 * @deprecated Use getRegionFullHierarchy instead
 */
async function getRegionHierarchy(districtId) {
  try {
    if (!districtId) return null;

    // البحث عن القضاء (level 2)
    const districtResult = await dynamodb.send(new GetCommand({
      TableName: REGIONS_TABLE,
      Key: { regionId: districtId }
    }));

    if (!districtResult.Item) {
      console.warn(`⚠️ District ${districtId} not found`);
      return null;
    }

    const district = districtResult.Item;
    const governorateId = district.parent_id;

    if (!governorateId) {
      return {
        district_name: district.name || district.name_ar,
        governorate_id: null,
        governorate_name: null
      };
    }

    // البحث عن المحافظة (level 1)
    const governorateResult = await dynamodb.send(new GetCommand({
      TableName: REGIONS_TABLE,
      Key: { regionId: governorateId }
    }));

    return {
      district_name: district.name || district.name_ar,
      governorate_id: governorateId,
      governorate_name: governorateResult.Item 
        ? (governorateResult.Item.name || governorateResult.Item.name_ar)
        : 'غير محدد'
    };

  } catch (error) {
    console.error('❌ Error getting region hierarchy:', error);
    return null;
  }
}

/**
 * 🔐 فحص صلاحية السائق للعمل في المنطقة
 */
async function checkDriverRegionPermission(driverId, homeRegionId, homeRegionLevel, targetRegionId, targetRegionLevel, targetGovernorateId, homeGovernorateId, driverLevel) {
  console.log(`🔐 فحص صلاحيات السائق ${driverId}:`);
  console.log(`   homeRegionId: ${homeRegionId} (Level ${homeRegionLevel})`);
  console.log(`   targetRegionId: ${targetRegionId} (Level ${targetRegionLevel})`);
  console.log(`   homeGovernorateId: ${homeGovernorateId}`);
  console.log(`   targetGovernorateId: ${targetGovernorateId}`);
  console.log(`   driverLevel: ${driverLevel || 'Bronze (default)'}`);
  
  // 1. نفس المنطقة الأساسية → مسموح دائماً
  if (homeRegionId === targetRegionId) {
    console.log(`✅ نفس المنطقة الأصلية - مسموح`);
    return { allowed: true };
  }

  // ============================================
  // 🎯 المنطق الجديد: حسب Level
  // ============================================

  // 2. إذا كانت home_region هي Level 2 (بدون أطفال Level 3)
  if (homeRegionLevel === 2) {
    console.log(`⚠️ home_region هي Level 2 - نسمح فقط بنفس المنطقة`);
    console.log(`❌ غير مسموح - السائق في Level 2 يعمل فقط في منطقته`);
    return { 
      allowed: false, 
      suggestion: 'يمكنك العمل فقط في منطقتك الحالية' 
    };
  }

  // 3. إذا كانت home_region هي Level 3 → نتحقق من الجيران Priority 0/1 فقط
  if (homeRegionLevel === 3) {
    console.log(`✅ home_region هي Level 3 - نفحص الجيران Priority 0/1 فقط`);
    
    try {
      console.log(`🔍 فحص جدول RegionNeighbors لـ ${homeRegionId}...`);
      
      // Query RegionNeighbors للحصول على الجيران
      const result = await dynamodb.send(new QueryCommand({
        TableName: REGION_NEIGHBORS_TABLE,
        IndexName: 'source-region-index',
        KeyConditionExpression: 'source_region_id = :regionId',
        ExpressionAttributeValues: {
          ':regionId': homeRegionId
        }
      }));

      const neighbors = result.Items || [];
      console.log(`   ✅ Found ${neighbors.length} neighbor entries for home_region`);

      // ❌ لا نفحص parent - نفحص فقط Priority 0 & 1
      const priority0and1 = neighbors.filter(n => n.expansion_priority === 0 || n.expansion_priority === 1);
      const allowedNeighborIds = priority0and1.map(n => n.target_region_id);
      
      console.log(`   📊 المناطق المجاورة المسموحة (Priority 0 & 1 فقط):`);
      console.log(`      - Priority 0: ${neighbors.filter(n => n.expansion_priority === 0).length} مناطق`);
      console.log(`      - Priority 1: ${neighbors.filter(n => n.expansion_priority === 1).length} مناطق`);
      console.log(`      - Priority 2 (مستبعدة): ${neighbors.filter(n => n.expansion_priority === 2).length} مناطق`);
      console.log(`      - Total allowed neighbors: ${allowedNeighborIds.length} مناطق`);
      
      if (allowedNeighborIds.includes(targetRegionId)) {
        console.log(`✅ المنطقة المستهدفة ضمن المناطق المجاورة (Priority 0 أو 1) - مسموح`);
        return { allowed: true };
      }
      
      console.log(`⚠️ المنطقة المستهدفة ليست ضمن:`);
      console.log(`   - home_region (${homeRegionId})`);
      console.log(`   - neighbors Priority 0/1 (${allowedNeighborIds.length} مناطق)`);
      
    } catch (error) {
      console.error('❌ خطأ في فحص RegionNeighbors:', error);
      // في حالة الخطأ، نكمل بفحص المحافظات
    }
  }

  // 4. فحص مستوى السائق
  const level = driverLevel || 'Bronze';

  // Gold: أي محافظة
  if (level === 'Gold') {
    console.log(`✅ مستوى Gold - مسموح في كل المحافظات`);
    return { allowed: true };
  }

  // Silver: نفس المحافظة
  if (level === 'Silver' && homeGovernorateId === targetGovernorateId) {
    console.log(`✅ مستوى Silver ونفس المحافظة - مسموح`);
    return { allowed: true };
  }

  // Bronze: نفس المحافظة فقط (لأن Bronze يعمل في نفس المحافظة)
  if (level === 'Bronze' && homeGovernorateId === targetGovernorateId) {
    console.log(`✅ مستوى Bronze ونفس المحافظة - مسموح`);
    return { allowed: true };
  }

  // غير مسموح
  console.log(`❌ غير مسموح - مستوى ${level} ومحافظة مختلفة`);
  
  // رسائل مخصصة حسب السبب
  let suggestion = 'المنطقة المطلوبة خارج نطاق عملك الحالي';
  
  if (homeRegionLevel === 3) {
    // Level 3: يمكنه العمل في الجيران Priority 0/1
    suggestion = 'يمكنك العمل فقط في منطقتك والمناطق المجاورة القريبة';
  } else if (homeRegionLevel === 2) {
    // Level 2: فقط في نفس المنطقة
    suggestion = 'يمكنك العمل فقط في منطقتك الحالية';
  }
  
  return { 
    allowed: false, 
    suggestion: suggestion
  };
}

/**
 * 📏 حساب المسافة بين نقطتين (Haversine formula)
 */
function calculateDistance(lat1, lng1, lat2, lng2) {
  const R = 6371; // نصف قطر الأرض بالكيلومتر
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
            Math.sin(dLng / 2) * Math.sin(dLng / 2);
  
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function toRad(degrees) {
  return degrees * (Math.PI / 180);
}

// ============================================================================
// 🗺️ MAP DATA ENDPOINT - Stores, Regions, Hot Stores
// ============================================================================

// In-memory cache for map data
const mapDataCache = new Map();
const CACHE_TTL = {
  neighbors: 60 * 60 * 1000,      // 1 hour for region neighbors
  stores: 20 * 1000,              // 20 seconds for stores list - shorter than frontend polling (30s)
  hotScores: 30 * 1000            // 30 seconds for hot scores
};

/**
 * 🗺️ Get map data for driver home screen
 * GET /driver/map-data?lat=32.0018&lng=44.3449
 * 
 * Returns:
 * - current_work_region (from GPS)
 * - neighbor_regions (Priority 0 & 1)
 * - nearby_stores (from current + neighbors)
 * - hot_stores (calculated from orders)
 */
async function getMapData(driverId, queryParams, headers) {
  const startTime = Date.now();
  console.log('🗺️ === Get Map Data ===');
  console.log('   Driver ID:', driverId);
  console.log('   Query params:', JSON.stringify(queryParams));

  try {
    // 1️⃣ Validate input
    const lat = parseFloat(queryParams.lat);
    const lng = parseFloat(queryParams.lng);

    if (!lat || !lng || isNaN(lat) || isNaN(lng)) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({
          success: false,
          message: 'Invalid coordinates',
          error: 'lat and lng parameters are required'
        })
      };
    }

    console.log(`   📍 Location: ${lat}, ${lng}`);

    // 2️⃣ Determine current work region from GPS
    const regionInfo = await determineRegionFromCoordinates(lat, lng, null);
    
    if (!regionInfo || !regionInfo.region_id) {
      return {
        statusCode: 404,
        headers,
        body: JSON.stringify({
          success: false,
          message: 'لا يمكن تحديد المنطقة من موقعك الحالي',
          error: 'Region not found for coordinates'
        })
      };
    }

    const currentRegionId = regionInfo.region_id;
    console.log(`   🎯 Current region: ${regionInfo.region_name} (${currentRegionId})`);

    // 3️⃣ Get neighbor regions (Priority 0 & 1) with caching
    const neighborRegions = await getNeighborRegionsWithCache(currentRegionId);
    console.log(`   🔗 Found ${neighborRegions.length} neighbor regions`);

    // 4️⃣ Build list of region IDs to query stores from
    // Include current region + its children + neighbors
    const childRegions = await getChildRegions(currentRegionId);
    console.log(`   👶 Found ${childRegions.length} child regions for ${currentRegionId}`);
    
    const regionIdsToQuery = [
      currentRegionId,
      ...childRegions.map(c => c.regionId),
      ...neighborRegions.map(n => n.neighbor_region_id)
    ];
    
    // TEMPORARY FIX: Also include known child region until parent-index permissions are fixed
    if (currentRegionId === 'Rmhvc7snfyul1f' && !regionIdsToQuery.includes('Rmhvcpnn3iy5f1')) {
      regionIdsToQuery.push('Rmhvcpnn3iy5f1'); // Al-Manathirah Center
      console.log(`   🔧 Temporarily added known child region Rmhvcpnn3iy5f1`);
    }
    
    console.log(`   📋 Querying stores from ${regionIdsToQuery.length} regions`);

    // 5️⃣ Get stores from these regions with caching
    const stores = await getStoresFromRegionsWithCache(regionIdsToQuery, lat, lng);
    console.log(`   🏪 Found ${stores.length} stores`);

    // 6️⃣ Calculate hot scores (simple version - count waiting orders)
    await enrichStoresWithHotScores(stores);

    // 7️⃣ Build response
    const response = {
      success: true,
      timestamp: new Date().toISOString(),
      processing_time_ms: Date.now() - startTime,
      current_work_region: {
        id: currentRegionId,
        name: regionInfo.region_name,
        level: regionInfo.level,
        parent_id: regionInfo.parent_id,
        district_name: regionInfo.district_name,
        governorate_id: regionInfo.governorate_id,
        governorate_name: regionInfo.governorate_name
      },
      neighbor_regions: neighborRegions.map(n => ({
        id: n.neighbor_region_id,
        name: n.neighbor_region_name,
        priority: n.expansion_priority,
        distance_km: parseFloat(n.shared_boundary_km || 0).toFixed(1)
      })),
      nearby_stores: stores,
      summary: {
        total_stores: stores.length,
        hot_stores: stores.filter(s => s.is_hot).length,
        open_stores: stores.filter(s => s.is_open).length,
        region_coverage_km: calculateRegionCoverageKm(stores, lat, lng)
      }
    };

    console.log(`✅ Map data ready in ${Date.now() - startTime}ms`);
    console.log(`   📊 Summary: ${response.summary.total_stores} stores, ${response.summary.hot_stores} hot`);

    return {
      statusCode: 200,
      headers,
      body: JSON.stringify(response)
    };

  } catch (error) {
    console.error('❌ Error in getMapData:', error);
    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({
        success: false,
        message: 'حدث خطأ في جلب بيانات الخريطة',
        error: error.message
      })
    };
  }
}

/**
 * 👶 Get child regions (sub-neighborhoods within a district)
 */
async function getChildRegions(parentRegionId) {
  try {
    console.log(`   🔍 Fetching child regions for ${parentRegionId}...`);
    
    const result = await dynamodb.send(new QueryCommand({
      TableName: REGIONS_TABLE,
      IndexName: 'parent-index',
      KeyConditionExpression: 'parent_id = :parentId',
      FilterExpression: 'effective_is_active = :active',
      ExpressionAttributeValues: {
        ':parentId': parentRegionId,
        ':active': 1
      },
      ProjectionExpression: 'regionId,#n,#level',
      ExpressionAttributeNames: {
        '#n': 'name',
        '#level': 'level'
      }
    }));
    
    const children = result.Items || [];
    console.log(`   ✅ Found ${children.length} active child regions`);
    
    return children;
    
  } catch (error) {
    console.error('❌ Error fetching child regions:', error);
    return [];
  }
}

/**
 * 🌍 Calculate allowed regions for Wave System
 * Returns Priority 0 (same region) and Priority 1 (neighbors)
 * Used at start-searching and when region changes
 */
async function calculateAllowedRegions(currentRegionId) {
  try {
    console.log(`   🔍 Calculating allowed regions for ${currentRegionId}...`);
    
    // Query RegionNeighbors for Priority 0 & 1
    const result = await dynamodb.send(new QueryCommand({
      TableName: REGION_NEIGHBORS_TABLE,
      IndexName: 'source-region-index',
      KeyConditionExpression: 'source_region_id = :regionId',
      FilterExpression: 'expansion_priority IN (:p0, :p1)',
      ExpressionAttributeValues: {
        ':regionId': currentRegionId,
        ':p0': 0,  // Priority 0 (same region)
        ':p1': 1   // Priority 1 (nearby regions)
      }
    }));

    const neighbors = result.Items || [];
    console.log(`   ✅ Found ${neighbors.length} neighbors (Priority 0 & 1)`);

    // Separate by priority
    const priority0 = neighbors
      .filter(n => n.expansion_priority === 0)
      .map(n => n.target_region_id);
    
    const priority1 = neighbors
      .filter(n => n.expansion_priority === 1)
      .map(n => n.target_region_id);

    // Add current region to priority0
    priority0.push(currentRegionId);

    // Combine all (with deduplication)
    const all = [...new Set([...priority0, ...priority1])];

    console.log(`   📊 Allowed regions breakdown:`);
    console.log(`      - Priority 0: ${priority0.length} regions`);
    console.log(`      - Priority 1: ${priority1.length} regions`);
    console.log(`      - Total: ${all.length} regions`);

    return {
      all,
      priority0,
      priority1
    };

  } catch (error) {
    console.error('❌ Error calculating allowed regions:', error);
    // Fallback: only current region
    return {
      all: [currentRegionId],
      priority0: [currentRegionId],
      priority1: []
    };
  }
}

/**
 * 📊 Get driver metrics snapshot for Wave System
 * Reads from WizzDriverPerformanceMetrics and returns snapshot
 */
async function getDriverMetricsSnapshot(driverId) {
  try {
    console.log(`   📊 ========================================`);
    console.log(`   📊 Fetching metrics snapshot for driver ${driverId}...`);
    console.log(`   📊 Table: ${DRIVER_PERFORMANCE_METRICS_TABLE}`);
    console.log(`   📊 PK: DRIVER#${driverId}`);
    console.log(`   📊 SK: METRICS`);
    
    const result = await dynamodb.send(new GetCommand({
      TableName: DRIVER_PERFORMANCE_METRICS_TABLE,
      Key: { 
        PK: `DRIVER#${driverId}`,
        SK: 'METRICS'
      }
    }));

    console.log(`   📊 DynamoDB Response received`);
    console.log(`   📊 result.Item exists: ${!!result.Item}`);
    console.log(`   📊 Full result.Item:`, JSON.stringify(result.Item, null, 2));

    const metrics = result.Item;

    if (!metrics) {
      console.log('   ⚠️ ========================================');
      console.log('   ⚠️ NO METRICS FOUND - USING DEFAULTS');
      console.log(`   ⚠️ Searched for: PK=DRIVER#${driverId}, SK=METRICS`);
      console.log('   ⚠️ ========================================');
      return {
        acceptanceRate: 0,
        completionRate: 0,
        responseRate: 0,
        consecutiveRejections: 0,
        totalOffersWindow: 0,
        totalTrips: 0
      };
    }
    
    console.log('   ✅ ========================================');
    console.log('   ✅ METRICS FOUND SUCCESSFULLY!');
    console.log('   ✅ Raw metrics data:', {
      acceptanceRate: metrics.acceptanceRate,
      completionRate: metrics.completionRate,
      responseRate: metrics.responseRate,
      consecutiveRejections: metrics.consecutiveRejections,
      totalOffersLast100: metrics.totalOffersLast100,
      totalTrips: metrics.totalTrips
    });

    const snapshot = {
      acceptanceRate: metrics.acceptanceRate || 0,
      completionRate: metrics.completionRate || 0,
      responseRate: metrics.responseRate || 0,
      consecutiveRejections: metrics.consecutiveRejections || 0,
      totalOffersWindow: metrics.totalOffersLast100 || 0,
      totalTrips: metrics.totalTrips || 0
    };

    console.log(`   ✅ Final snapshot object:`, snapshot);
    console.log('   ✅ ========================================');
    return snapshot;

  } catch (error) {
    console.error('   ❌ ========================================');
    console.error('   ❌ EXCEPTION IN getDriverMetricsSnapshot!');
    console.error('   ❌ Error:', error);
    console.error('   ❌ Error name:', error.name);
    console.error('   ❌ Error message:', error.message);
    console.error('   ❌ Error stack:', error.stack);
    console.error('   ❌ ========================================');
    // Return defaults on error
    return {
      acceptanceRate: 0,
      completionRate: 0,
      responseRate: 0,
      consecutiveRejections: 0,
      totalOffersWindow: 0,
      totalTrips: 0
    };
  }
}

/**
 * 🔗 Get neighbor regions with caching
 */
async function getNeighborRegionsWithCache(regionId) {
  const cacheKey = `neighbors_${regionId}`;
  const cached = mapDataCache.get(cacheKey);

  if (cached && (Date.now() - cached.timestamp < CACHE_TTL.neighbors)) {
    console.log('   💾 Using cached neighbor regions');
    return cached.data;
  }

  console.log('   🔍 Fetching neighbor regions from DynamoDB...');

  try {
    // Use source-region-index GSI to query neighbors
    const result = await dynamodb.send(new QueryCommand({
      TableName: REGION_NEIGHBORS_TABLE,
      IndexName: 'source-region-index',
      KeyConditionExpression: 'source_region_id = :sourceId',
      FilterExpression: 'expansion_priority IN (:p0, :p1)',
      ExpressionAttributeValues: {
        ':sourceId': regionId,
        ':p0': 0,
        ':p1': 1
      }
    }));

    const neighbors = result.Items || [];
    console.log(`   ✅ Found ${neighbors.length} neighbors (Priority 0 & 1)`);

    // Cache the result
    mapDataCache.set(cacheKey, {
      data: neighbors,
      timestamp: Date.now()
    });

    return neighbors;

  } catch (error) {
    console.error('❌ Error fetching neighbors:', error);
    console.error('   Error details:', error.message);
    return [];
  }
}

/**
 * 🏪 Get stores from regions with caching
 * Note: Cache stores RAW data from DynamoDB, not processed/filtered results
 */
async function getStoresFromRegionsWithCache(regionIds, driverLat, driverLng) {
  // Cache key based on regions (not including lat/lng since we filter by distance later)
  const cacheKey = `stores_raw_${regionIds.sort().join('_')}`;
  const cached = mapDataCache.get(cacheKey);

  let rawStores;
  
  if (cached && (Date.now() - cached.timestamp < CACHE_TTL.stores)) {
    console.log('   💾 Using cached stores data');
    rawStores = cached.data;
  } else {
    console.log('   🔍 Fetching stores from DynamoDB...');

    try {
      const BUSINESSES_TABLE = 'WhizzMerchants_Businesses';
      
      // ✅ Use Scan with filter - فقط المطاعم النشطة (بدون فلترة acceptingOrders)
      // نريد أن نرى جميع المطاعم (مفتوح/مغلق/مشغول) لإعطاء السائق صورة كاملة
      const result = await dynamodb.send(new ScanCommand({
        TableName: BUSINESSES_TABLE,
        FilterExpression: 'isActive = :active AND #status = :approvedStatus',
        ExpressionAttributeNames: {
          '#status': 'status'
        },
        ExpressionAttributeValues: {
          ':active': true,
          ':approvedStatus': 'approved'  // فقط المطاعم المعتمدة
        }
      }));

      const allStores = result.Items || [];
      console.log(`   📦 Fetched ${allStores.length} total active stores`);
      
      // 🔍 Debug: عرض acceptingOrders لكل مطعم
      allStores.forEach(store => {
        console.log(`   📊 ${store.businessName}: acceptingOrders=${store.acceptingOrders}, type=${typeof store.acceptingOrders}`);
      });

      // Filter by regionId (if regionIds are valid)
      if (regionIds.length > 0 && regionIds.every(id => id && id.trim().length > 0)) {
        rawStores = allStores.filter(store => 
          regionIds.includes(store.regionId)
        );
        console.log(`   ✅ ${rawStores.length} stores match regions ${regionIds.join(', ')}`);
      } else {
        // Fallback: use all stores if region filtering fails
        console.log(`   ⚠️ Invalid regionIds, using all ${allStores.length} stores`);
        rawStores = allStores;
      }

      // Cache the RAW filtered data (not processed)
      mapDataCache.set(cacheKey, {
        data: rawStores,
        timestamp: Date.now()
      });

    } catch (error) {
      console.error('❌ Error fetching stores:', error);
      console.error('   Error details:', error.message);
      return [];
    }
  }

  // Always filter by distance and process (never cache this step)
  return await filterStoresByDistance(rawStores, driverLat, driverLng, 20);
}

/**
 * 📏 Filter stores by distance from driver
 * Uses Haversine formula for accurate distance calculation
 */
async function filterStoresByDistance(stores, driverLat, driverLng, maxDistanceKm) {
  // First, calculate distances and filter
  const storesWithDistance = stores
    .filter(store => store.latitude && store.longitude)
    .map(store => {
      // حساب المسافة الدقيقة باستخدام Haversine formula
      const distance = calculateDistance(
        driverLat,
        driverLng,
        parseFloat(store.latitude),
        parseFloat(store.longitude)
      );

      return {
        ...store,
        distance_km: parseFloat(distance.toFixed(2))
      };
    })
    .filter(store => store.distance_km <= maxDistanceKm);
  
  // ✅ Then, check status for each store in parallel
  const storePromises = storesWithDistance.map(async store => {
    // ✅ فحص حالة المطعم بشكل صحيح (async)
    const isOpen = await checkIfStoreOpen(store);
    
    return {
      store_id: store.businessId,
      name: store.businessName,
      category: store.businessType || 'restaurant',
      lat: parseFloat(store.latitude),
      lng: parseFloat(store.longitude),
      address: extractRealAddress(store), // ✅ العنوان الحقيقي من DynamoDB
      region_id: store.regionId,
      distance_km: store.distance_km, // ✅ المسافة المحسوبة بدقة
      is_open: isOpen, // ✅ حالة حقيقية من ساعات العمل + acceptingOrders
      is_hot: false, // Will be enriched with real data
      hot_score: 0,
      waiting_orders_count: 0, // Will be enriched with real data
      photo_url: store.businessPhotoUrl || null,
      // ✅ حقول جديدة للحالة الفعلية
      accepting_orders: store.acceptingOrders !== false, // حالة قبول الطلبات
      online_status: determineOnlineStatus(store),
      is_core_region: store.expansion_priority === 0, // منطقة أساسية
      working_hours: store.workingHours || null,
    };
  });
  
  // ✅ Wait for all status checks to complete
  return await Promise.all(storePromises);
}

/**
 * 🔥 Enrich stores with hot scores based on real waiting orders
 */
async function enrichStoresWithHotScores(stores) {
  console.log(`   🔥 Calculating hot scores for ${stores.length} stores...`);
  
  let hotCount = 0;
  
  for (const store of stores) {
    try {
      // Get waiting orders count from WizzOrders table
      const waitingOrders = await getWaitingOrdersCount(store.store_id);
      
      // Calculate hot score based on waiting orders
      store.waiting_orders_count = waitingOrders;
      store.hot_score = calculateHotScore(waitingOrders);
      store.is_hot = store.hot_score > 0;
      
      if (store.is_hot) {
        hotCount++;
        console.log(`      🔥 ${store.name}: ${waitingOrders} orders → score ${store.hot_score}`);
      }
    } catch (error) {
      console.error(`   ⚠️ Failed to get orders for ${store.name}:`, error.message);
      // Keep default values (is_hot: false, hot_score: 0)
    }
  }
  
  console.log(`   ✅ Found ${hotCount} hot stores out of ${stores.length}`);
}

/**
 * 📊 Calculate hot score based on waiting orders count
 * 
 * Score ranges:
 * - 0 orders: score 0 (no glow)
 * - 1-2 orders: score 1-4 (orange glow)
 * - 3-5 orders: score 5-9 (light red glow)
 * - 6+ orders: score 10+ (strong red glow)
 */
function calculateHotScore(waitingOrders) {
  if (waitingOrders === 0) return 0;
  if (waitingOrders <= 2) return waitingOrders * 2; // 2, 4
  if (waitingOrders <= 5) return 5 + waitingOrders; // 8, 9, 10
  return 10 + waitingOrders; // 16, 17, 18...
}

/**
 * 📦 Get count of waiting orders for a specific business
 * 
 * Queries WizzOrders table using GSI_StoreStatus index
 * Counts orders with status: pending, confirmed, preparing, ready
 */
async function getWaitingOrdersCount(businessId) {
  const waitingStatuses = ['pending', 'confirmed', 'preparing', 'ready'];
  let totalCount = 0;
  
  try {
    // Query each status + bucket separately.
    // Expected storeStatus format: businessId#status#b0..b9
    const buckets = ['b0', 'b1', 'b2', 'b3', 'b4', 'b5', 'b6', 'b7', 'b8', 'b9'];

    for (const status of waitingStatuses) {
      for (const bucket of buckets) {
        const storeStatusValue = `${businessId}#${status}#${bucket}`;

        const result = await dynamodb.send(new QueryCommand({
          TableName: ORDERS_TABLE,
          IndexName: 'GSI_StoreStatus',
          KeyConditionExpression: 'storeStatus = :storeStatusValue',
          ExpressionAttributeValues: {
            ':storeStatusValue': { S: storeStatusValue }
          },
          Select: 'COUNT'
        }));

        totalCount += result.Count || 0;
      }
    }
    
    return totalCount;
  } catch (error) {
    console.error(`Error querying orders for ${businessId}:`, error.message);
    return 0;
  }
}

/**
 * 🏢 Extract real address from store data
 * Handles both old format (district/street/city) and new format (address object)
 */
function extractRealAddress(store) {
  // Try new format first (address object from DynamoDB)
  if (store.address && typeof store.address === 'object') {
    const addr = store.address;
    
    // If fullAddress exists, use it
    if (addr.fullAddress) {
      return addr.fullAddress;
    }
    
    // Otherwise, build from components
    const parts = [];
    if (addr.street) parts.push(addr.street);
    if (addr.district) parts.push(addr.district);
    if (addr.city) parts.push(addr.city);
    if (addr.governorate) parts.push(addr.governorate);
    
    if (parts.length > 0) {
      return parts.join('، ');
    }
  }
  
  // Fallback to old format (flat fields)
  const parts = [];
  if (store.street) parts.push(store.street);
  if (store.district) parts.push(store.district);
  if (store.city) parts.push(store.city);
  
  return parts.length > 0 ? parts.join('، ') : 'عنوان غير محدد';
}

/**
 * 🟢 Determine online status of store
 * Returns: 'online', 'offline', or 'busy'
 */
function determineOnlineStatus(store) {
  // Check if store has isOnline field
  if (store.isOnline) {
    return store.isOnline; // 'online', 'offline', 'busy'
  }
  
  // Fallback: check acceptingOrders
  if (store.acceptingOrders === false) {
    return 'busy'; // Not accepting orders = busy
  }
  
  return 'online'; // Default to online if accepting orders
}

/**
 * ⏰ Check if store is open now
 * نظام محسّن مثل wizzuser - يتحقق من:
 * 1. acceptingOrders (من جدول Businesses) -> إذا false = مشغول
 * 2. ساعات العمل (من جدول WorkingHours مع isClosed) -> إذا خارج الأوقات أو isClosed = مغلق
 */
async function checkIfStoreOpen(store) {
  try {
    console.log(`   🔍 Checking status for ${store.businessName}:`);
    console.log(`   📊 Store data: acceptingOrders=${store.acceptingOrders}, isClosed=${store.isClosed}, isActive=${store.isActive}`);
    
    // 0. ✅ فحص isClosed من جدول Businesses أولاً (أولوية قصوى!)
    // هذا الحقل يتم تعديله من تطبيق التاجر
    if (store.isClosed === true) {
      console.log(`   🔒 ${store.businessName}: مغلق يدوياً من جدول Businesses (isClosed=true)`);
      return false; // مغلق تماماً
    }
    
    // 1. ✅ فحص acceptingOrders (من جدول WhizzMerchants_Businesses)
    // إذا acceptingOrders = false -> المطعم مشغول (لا يستقبل طلبات)
    if (store.acceptingOrders === false) {
      console.log(`   ⚠️ ${store.businessName}: مشغول (acceptingOrders=false)`);
      return false; // مشغول
    }
    
    console.log(`   🕐 Calling checkBusinessWorkingHours for ${store.businessId}...`);
    // 2. ✅ فحص ساعات العمل من جدول WhizzMerchants_BusinessWorkingHours
    const workingHoursStatus = await checkBusinessWorkingHours(store.businessId);
    console.log(`   ✅ Working hours status received:`, workingHoursStatus);
    
    // إذا كان هناك isClosed=true في جدول ساعات العمل -> مغلق
    if (workingHoursStatus.isClosed) {
      console.log(`   ⚠️ ${store.businessName}: مغلق يدوياً في WorkingHours (isClosed=true)`);
      return false; // مغلق يدوياً
    }
    
    // إذا كان خارج ساعات العمل -> مغلق
    if (!workingHoursStatus.isOpen) {
      console.log(`   ⚠️ ${store.businessName}: خارج ساعات العمل`);
      return false; // خارج ساعات العمل
    }
    
    // ✅ All checks passed - المطعم مفتوح ويستقبل طلبات
    console.log(`   ✅ ${store.businessName}: مفتوح ويستقبل طلبات`);
    return true;
    
  } catch (error) {
    console.error(`Error checking store status for ${store.businessName}:`, error);
    // في حالة الخطأ، نفترض المطعم مفتوح إذا كان acceptingOrders = true AND isClosed != true
    return store.acceptingOrders !== false && store.isClosed !== true;
  }
}

/**
 * 🕐 Query working hours from WhizzMerchants_BusinessWorkingHours table
 * Returns: { isOpen: boolean, isClosed: boolean, statusText: string }
 * 
 * Format من الجدول:
 * - opening: "09:00" (string)
 * - closing: "23:00" (string)  
 * - isClosed: true/false (boolean)
 * 
 * ✅ يستخدم Asia/Baghdad timezone للحصول على الوقت الصحيح
 */
async function checkBusinessWorkingHours(businessId) {
  try {
    // ✅ استخدام وقت بغداد (Asia/Baghdad = UTC+3)
    const now = new Date();
    const timezone = 'Asia/Baghdad';
    
    // ✅ الحصول على اليوم الحالي في توقيت بغداد
    const formatter = new Intl.DateTimeFormat('en-US', { 
      weekday: 'long',
      timeZone: timezone 
    });
    const currentWeekday = formatter.format(now);
    
    console.log(`   📅 Checking working hours for ${businessId} on ${currentWeekday} (Baghdad time)`);
    
    // ✅ Query جدول ساعات العمل - استخدام DocumentClient format
    const result = await dynamodb.send(new QueryCommand({
      TableName: 'WhizzMerchants_BusinessWorkingHours',
      KeyConditionExpression: 'businessId = :businessId AND weekday = :weekday',
      ExpressionAttributeValues: {
        ':businessId': businessId,  // ✅ DocumentClient format (not {S: ...})
        ':weekday': currentWeekday
      }
    }));
    
    if (!result.Items || result.Items.length === 0) {
      console.log(`   ⚠️ No working hours found for ${businessId} on ${currentWeekday}`);
      return { isOpen: true, isClosed: false, statusText: 'لا توجد ساعات عمل محددة' };
    }
    
    const workingHours = result.Items[0];
    console.log(`   📊 Working hours data:`, JSON.stringify(workingHours));
    console.log(`   🔍 isClosed value: ${workingHours.isClosed}, type: ${typeof workingHours.isClosed}`);
    
    // ✅ 1. تحقق من isClosed أولاً (الأولوية العليا)
    const isClosed = workingHours.isClosed === true;
    console.log(`   🎯 Final isClosed decision: ${isClosed}`);
    if (isClosed) {
      console.log(`   🔒 ${businessId}: مغلق يدوياً (isClosed=true)`);
      return { 
        isOpen: false, 
        isClosed: true, 
        statusText: 'مغلق يدوياً' 
      };
    }
    
    // ✅ 2. تحقق من أوقات الفتح والإغلاق
    const opening = workingHours.opening || '';
    const closing = workingHours.closing || '';
    
    console.log(`   🕐 Opening: ${opening}, Closing: ${closing}`);
    
    // إذا كانت الأوقات فارغة أو "closed" -> مغلق
    if (!opening || !closing || 
        opening === 'none' || closing === 'none' || 
        opening === 'closed' || closing === 'closed') {
      console.log(`   ⏰ ${businessId}: مغلق (لا توجد أوقات صالحة)`);
      return { 
        isOpen: false, 
        isClosed: false, 
        statusText: 'مغلق اليوم' 
      };
    }
    
    // ✅ 3. تحقق من الوقت الحالي ضمن ساعات العمل (باستخدام توقيت بغداد)
    // الحصول على الساعة والدقيقة الحالية في توقيت بغداد
    const timeFormatter = new Intl.DateTimeFormat('en-US', {
      hour: '2-digit',
      minute: '2-digit',
      hour12: false,
      timeZone: timezone
    });
    
    const baghdadTime = timeFormatter.format(now);
    const [currentHour, currentMinute] = baghdadTime.split(':').map(Number);
    const currentTime = currentHour * 60 + currentMinute;
    
    console.log(`   🕐 Current time in Baghdad: ${baghdadTime} (${currentTime} minutes)`);
    
    // Parse opening time
    const openingParts = opening.split(':');
    if (openingParts.length !== 2) {
      console.log(`   ⚠️ Invalid opening time format: ${opening}`);
      return { isOpen: false, isClosed: false, statusText: 'خطأ في صيغة الوقت' };
    }
    const [openHour, openMinute] = openingParts.map(Number);
    
    // Parse closing time
    const closingParts = closing.split(':');
    if (closingParts.length !== 2) {
      console.log(`   ⚠️ Invalid closing time format: ${closing}`);
      return { isOpen: false, isClosed: false, statusText: 'خطأ في صيغة الوقت' };
    }
    const [closeHour, closeMinute] = closingParts.map(Number);
    
    const openTime = openHour * 60 + openMinute;
    const closeTime = closeHour * 60 + closeMinute;
    
    console.log(`   📊 Working hours: ${opening} (${openTime} min) - ${closing} (${closeTime} min)`);
    
    // ✅ Handle case where closing time is after midnight (e.g., 22:00 - 02:00)
    let isOpen;
    if (closeTime < openTime) {
      // ✅ يعبر منتصف الليل: مفتوح إذا الوقت >= وقت الفتح أو الوقت <= وقت الإغلاق
      isOpen = currentTime >= openTime || currentTime < closeTime;
      console.log(`   🌙 Midnight crossing detected: ${opening}-${closing}`);
      console.log(`      Current time ${currentTime} >= ${openTime} OR < ${closeTime} = ${isOpen}`);
    } else {
      // ✅ حالة عادية: مفتوح إذا الوقت بين وقت الفتح والإغلاق
      isOpen = currentTime >= openTime && currentTime < closeTime;
      console.log(`   ☀️ Normal hours: ${opening}-${closing}`);
      console.log(`      ${currentTime} >= ${openTime} AND < ${closeTime} = ${isOpen}`);
    }
    
    console.log(`   ⏰ ${businessId}: ${opening}-${closing}, Baghdad time: ${baghdadTime}, isOpen: ${isOpen}`);
    console.log(`   ✅ FINAL RETURN: isOpen=${isOpen}, isClosed=false`);
    
    return {
      isOpen,
      isClosed: false,
      statusText: isOpen ? `مفتوح حتى ${closing}` : `يفتح في ${opening}`
    };
    
  } catch (error) {
    console.error(`❌ Error checking working hours for ${businessId}:`, error);
    console.error('   Stack:', error.stack);
    return { isOpen: true, isClosed: false, statusText: 'خطأ في فحص ساعات العمل' };
  }
}

/**
 * 🌍 Calculate distance between two coordinates using Haversine formula
 * Returns distance in kilometers with high accuracy
 * 
 * @param {number} lat1 - Latitude of first point
 * @param {number} lon1 - Longitude of first point
 * @param {number} lat2 - Latitude of second point
 * @param {number} lon2 - Longitude of second point
 * @returns {number} Distance in kilometers
 */
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Earth's radius in kilometers
  
  // Convert degrees to radians
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  
  const lat1Rad = lat1 * Math.PI / 180;
  const lat2Rad = lat2 * Math.PI / 180;
  
  // Haversine formula
  const a = 
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1Rad) * Math.cos(lat2Rad) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  
  const distance = R * c;
  
  return distance;
}

/**
 * 📐 Calculate region coverage in km
 */
function calculateRegionCoverageKm(stores, centerLat, centerLng) {
  if (stores.length === 0) return 0;

  const distances = stores.map(store => store.distance_km);
  return parseFloat(Math.max(...distances).toFixed(1));
}

/**
 * 🌊 Accept Wave Offer
 * Proxy request to WaveSystem_HandleDriverAccept Lambda
 */
async function acceptWaveOffer(driverId, body, corsHeaders) {
  console.log('🌊 Accept Wave Offer called');
  console.log('Driver ID from token:', driverId);
  console.log('Request body:', JSON.stringify(body, null, 2));
  
  try {
    const { offerId, orderId, driverId: driverIdFromBody } = body;
    
    // Use driverId from body if token extraction failed
    const finalDriverId = driverId || driverIdFromBody;
    
    console.log('Final Driver ID:', finalDriverId);
    
    if (!offerId) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({
          success: false,
          message: 'Missing required field: offerId'
        })
      };
    }
    
    // Extract waveNumber from offerId: OFFER_orderId_driverId_W1 -> waveNumber = 1
    let extractedWaveNumber = 1; // Default
    try {
      const offerParts = offerId.split('_');
      const wavePart = offerParts.find(part => part.startsWith('W'));
      if (wavePart) {
        extractedWaveNumber = parseInt(wavePart.substring(1)) || 1;
        console.log(`📊 Extracted wave number from offerId: ${extractedWaveNumber}`);
      }
    } catch (parseError) {
      console.warn('⚠️ Could not extract wave number from offerId, using default: 1');
    }
    
    if (!finalDriverId) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({
          success: false,
          message: 'Missing required field: driverId'
        })
      };
    }
    
    if (!orderId) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({
          success: false,
          message: 'Missing required field: orderId'
        })
      };
    }
    
    // ===== 💰 STEP 1: Get order details to calculate Hold amount =====
    console.log('📦 Fetching order details for Hold calculation...');
    const orderResult = await dynamodb.send(new GetCommand({
      TableName: ORDERS_TABLE,
      Key: {
        PK: `ORDER#${orderId}`,
        SK: 'META'
      }
    }));
    
    if (!orderResult.Item) {
      return {
        statusCode: 404,
        headers: corsHeaders,
        body: JSON.stringify({
          success: false,
          message: 'Order not found'
        })
      };
    }
    
    const order = orderResult.Item;
    
    // ✅ استخراج holdAmount من goodsSubtotal (قيمة الطلب فقط - بدون رسوم التوصيل والتِب)
    // holdAmount = قيمة المنتجات فقط (للمنصة)
    // deliveryFee + tip = للسائق (كاش مباشرة)
    const holdAmount = order.pricing?.goodsSubtotal || order.subtotal || 0;
    
    console.log('💵 Order Goods Subtotal for Hold:', holdAmount, 'IQD');
    console.log('💵 Delivery Fee (for driver):', order.pricing?.deliveryFee || 0, 'IQD');
    console.log('💵 Tip (for driver):', order.pricing?.tip || 0, 'IQD');
    console.log('💵 Total shown to driver:', order.pricing?.total || 0, 'IQD');
    console.log('📊 Order pricing structure:', order.pricing);
    
    // ✅ نثبت: هل الطلب ثابت؟ Hold التحقق الثنائي
    if (order.holdId && order.holdStatus === 'ACTIVE') {
      console.error('❌ Order already has active holdId:', order.holdId);
      console.error('   holdStatus:', order.holdStatus);
      console.error('   holdAmount:', order.holdAmount);
      return {
        statusCode: 409,
        headers: corsHeaders,
        body: JSON.stringify({
          success: false,
          message: 'تم قبول الطلب من سائق آخر',
          error: 'HOLD_ALREADY_EXISTS',
          details: 'لديك حجز نشط. يرجى البحث عن طلبات أخرى'
        })
      };
    }
    
    // ===== 💰 STEP 2: Create Hold on driver wallet =====
    let holdInfo = null;
    try {
      console.log('🔒 Creating Hold on driver wallet...');
      // ✅ FIXED: Use assignmentAttemptCounter instead of waveNumber
      // assignmentAttemptCounter increments on EACH assignment (even if reassigned in Wave 1 again)
      // This ensures unique idempotency keys even when unassign/reassign happens
      const assignmentAttempt = order.assignmentAttemptCounter || 1;
      console.log('📊 Assignment attempt (from assignmentAttemptCounter):', assignmentAttempt);
      holdInfo = await createWalletHold(finalDriverId, holdAmount, orderId, assignmentAttempt);
      console.log('✅ Hold created successfully:', holdInfo);
    } catch (holdError) {
      console.error('❌ Hold creation failed:', holdError);
      console.error('❌ Hold error details:', JSON.stringify(holdError, null, 2));
      
      // ✅ Re-check order to see if another driver accepted while we were processing
      // Adding small delay to ensure first driver's update is visible in DynamoDB
      console.log('🔄 Re-checking order status after Hold failure (with retry)...');
      
      // Helper function to check order status
      const checkOrderStatus = async () => {
        const recheckResult = await dynamodb.send(new GetCommand({
          TableName: ORDERS_TABLE,
          Key: {
            PK: `ORDER#${orderId}`,
            SK: 'META'
          }
        }));
        return recheckResult.Item;
      };
      
      try {
        // First check immediately
        let orderItem = await checkOrderStatus();
        
        // If no hold found, wait 100ms and check again (to handle race condition)
        if (!orderItem?.holdId || orderItem?.holdStatus !== 'ACTIVE') {
          console.log('⏳ First re-check: no hold found, waiting 100ms and checking again...');
          await new Promise(resolve => setTimeout(resolve, 100));
          orderItem = await checkOrderStatus();
        }
        
        // If still no hold found, wait another 100ms and check one more time
        if (!orderItem?.holdId || orderItem?.holdStatus !== 'ACTIVE') {
          console.log('⏳ Second re-check: no hold found, waiting 100ms and checking again...');
          await new Promise(resolve => setTimeout(resolve, 100));
          orderItem = await checkOrderStatus();
        }
        
        if (orderItem?.holdId && orderItem?.holdStatus === 'ACTIVE') {
          console.log('✅ Confirmed: Another driver has accepted this order');
          console.log('   - holdId:', orderItem.holdId);
          console.log('   - driverId:', orderItem.driverId);
          return {
            statusCode: 409,
            headers: corsHeaders,
            body: JSON.stringify({
              success: false,
              message: 'تم قبول الطلب من سائق آخر',
              error: 'ORDER_ALREADY_ACCEPTED',
              details: 'لقد قام سائق آخر بقبول هذا الطلب بالفعل'
            })
          };
        } else {
          console.log('⚠️ Re-check completed: No hold found after 3 attempts');
        }
      } catch (recheckError) {
        console.error('⚠️ Failed to recheck order:', recheckError);
      }
      
      // ✅ Check if error is due to duplicate idempotency (order already assigned to another driver)
      const errorMessage = (holdError.message || '').toLowerCase();
      const errorString = JSON.stringify(holdError).toLowerCase();
      
      const isIdempotencyError = 
        errorMessage.includes('idempotency') || 
        errorMessage.includes('already exists') ||
        errorMessage.includes('already created') ||
        errorMessage.includes('duplicate') ||
        errorMessage.includes('conflict') ||
        errorString.includes('idempotency') ||
        errorString.includes('409') ||
        errorString.includes('conflict');
      
      console.log('🔍 Is idempotency error?', isIdempotencyError);
      
      if (isIdempotencyError) {
        console.log('✅ Detected idempotency conflict - returning user-friendly message');
        return {
          statusCode: 409,
          headers: corsHeaders,
          body: JSON.stringify({
            success: false,
            message: 'تم قبول الطلب من سائق آخر',
            error: 'ORDER_ALREADY_ACCEPTED',
            details: 'لقد قام سائق آخر بقبول هذا الطلب بالفعل'
          })
        };
      }
      
      // Other wallet errors (insufficient balance, etc.)
      console.log('💰 Wallet error (not idempotency related)');

      const holdErrMsg = String(holdError?.message || '');
      const isWalletUnauthorized = holdErrMsg.toLowerCase().includes('unauthorized') && holdErrMsg.toLowerCase().includes('wallet service');

      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({
          success: false,
          message: 'فشل حجز المبلغ على المحفظة',
          error: holdError.message,
          details: isWalletUnauthorized
            ? 'فشل التفويض بين Drivers API وWallet Service. تحقق من WALLET_SERVICE_URL وSERVICE_* في بيئة staging.'
            : 'الرصيد غير كافٍ أو حدث خطأ في المحفظة'
        })
      };
    }
    
    // ===== 🌊 STEP 3: Call WaveSystem_HandleDriverAccept Lambda =====
    const waveSystemAcceptFn = (process.env.WAVESYSTEM_HANDLE_DRIVER_ACCEPT_FUNCTION_NAME || '').trim();
    if (!waveSystemAcceptFn) {
      console.warn('⚠️ WaveSystem accept handler is not configured. Skipping WaveSystem invocation.');
      return {
        statusCode: 503,
        headers: corsHeaders,
        body: JSON.stringify({
          success: false,
          message: 'WaveSystem غير مُفعّل حالياً في هذا البيئة',
          error: 'WAVESYSTEM_NOT_CONFIGURED'
        })
      };
    }

    console.log(`📞 Calling ${waveSystemAcceptFn}...`);
    const { LambdaClient, InvokeCommand } = require('@aws-sdk/client-lambda');
    const lambda = new LambdaClient({ region: 'us-east-1' });
    
    const payload = {
      body: JSON.stringify({
        offerId,
        driverId: finalDriverId,
        orderId,
        holdId: holdInfo.holdId,
        holdStatus: holdInfo.status,
        holdAmount: holdInfo.amount
      })
    };
    
    const command = new InvokeCommand({
      FunctionName: waveSystemAcceptFn,
      InvocationType: 'RequestResponse',
      Payload: JSON.stringify(payload)
    });
    
    const response = await lambda.send(command);
    const rawPayload = Buffer.from(response.Payload || '').toString();
    let result;
    try {
      result = rawPayload ? JSON.parse(rawPayload) : {};
    } catch (parseError) {
      console.error('❌ Failed to parse WaveSystem Lambda payload as JSON');
      console.error('   - Raw payload:', rawPayload);
      result = {};
    }
    
    console.log('✅ WaveSystem Lambda response:', result);

    // Handle Lambda invocation-level failures (unhandled exception, timeouts, etc.)
    const invocationFailed = Boolean(response.FunctionError) || Boolean(result?.errorMessage) || (!result?.statusCode && !result?.body);
    if (invocationFailed) {
      console.error('❌ WaveSystem invocation failed');
      console.error('   - FunctionError:', response.FunctionError);
      console.error('   - errorMessage:', result?.errorMessage);

      // IMPORTANT: release hold to avoid orphan ACTIVE hold when accept fails
      let holdReleased = false;
      try {
        await releaseWalletHold(holdInfo.holdId, 'WAVE_ACCEPT_FAILED', orderId);
        holdReleased = true;
      } catch (releaseErr) {
        console.error('⚠️ Failed to release hold after WaveSystem invocation failure:', releaseErr?.message || releaseErr);
      }

      return {
        statusCode: 502,
        headers: corsHeaders,
        body: JSON.stringify({
          success: false,
          message: 'فشل في قبول العرض',
          error: 'WAVESYSTEM_INVOCATION_FAILED',
          details: response.FunctionError || result?.errorMessage || 'WaveSystem did not return a valid proxy response',
          data: {
            holdId: holdInfo?.holdId,
            holdStatus: holdInfo?.status,
            holdAmount: holdInfo?.amount,
            holdReleased
          }
        })
      };
    }
    
    // ===== 💾 STEP 4: Update Order with Hold information =====
    try {
      console.log('💾 Updating order with Hold info...');
      console.log('   - Order ID:', orderId);
      console.log('   - Hold ID:', holdInfo.holdId);
      console.log('   - Hold Amount:', holdInfo.amount);
      console.log('   - Hold Status:', holdInfo.status);
      console.log('   - Table:', ORDERS_TABLE);
      
      const updateResult = await dynamodb.send(new UpdateCommand({
        TableName: ORDERS_TABLE,
        Key: {
          PK: `ORDER#${orderId}`,
          SK: 'META'
        },
        UpdateExpression: 'SET holdId = :holdId, holdStatus = :holdStatus, holdAmount = :holdAmount, pricingFrozen = :frozen, updatedAt = :now',
        ExpressionAttributeValues: {
          ':holdId': holdInfo.holdId,
          ':holdStatus': holdInfo.status,
          ':holdAmount': Number(holdInfo.amount),  // ✅ تأكد من تحويله لرقم
          ':frozen': true,
          ':now': new Date().toISOString()
        },
        ReturnValues: 'ALL_NEW'
      }));
      
      console.log('✅ Order updated with Hold info successfully');
      console.log('   - Updated attributes:', JSON.stringify({
        holdId: updateResult.Attributes?.holdId,
        holdAmount: updateResult.Attributes?.holdAmount,
        holdStatus: updateResult.Attributes?.holdStatus
      }));
    } catch (updateError) {
      console.error('❌ CRITICAL: Failed to update order with Hold info');
      console.error('   - Error name:', updateError.name);
      console.error('   - Error message:', updateError.message);
      console.error('   - Error code:', updateError.code);
      console.error('   - Full error:', JSON.stringify(updateError, null, 2));
      // Don't fail the whole operation - Hold is already created
    }
    
    // ===== 📤 STEP 5: Return response (normalized) =====
    let waveResponse = {};
    try {
      waveResponse = typeof result.body === 'string' && result.body ? JSON.parse(result.body) : (result.body || {});
    } catch (parseBodyError) {
      console.error('⚠️ Failed to parse WaveSystem body JSON:', parseBodyError?.message || parseBodyError);
      waveResponse = {};
    }

    const waveStatusCode = Number.isInteger(result.statusCode) ? result.statusCode : (waveResponse?.statusCode || 500);
    const waveSuccess = (typeof waveResponse.success === 'boolean')
      ? waveResponse.success
      : (waveStatusCode >= 200 && waveStatusCode < 300);

    // If WaveSystem says accept failed (or returned non-2xx), release the hold.
    if (!waveSuccess || waveStatusCode >= 400) {
      let holdReleased = false;
      try {
        await releaseWalletHold(holdInfo.holdId, 'WAVE_ACCEPT_FAILED', orderId);
        holdReleased = true;
      } catch (releaseErr) {
        console.error('⚠️ Failed to release hold after WaveSystem non-success response:', releaseErr?.message || releaseErr);
      }

      return {
        statusCode: waveStatusCode >= 400 ? waveStatusCode : 500,
        headers: corsHeaders,
        body: JSON.stringify({
          ...waveResponse,
          success: false,
          message: waveResponse.message || 'فشل في قبول العرض',
          data: {
            ...(waveResponse.data || {}),
            holdId: holdInfo.holdId,
            holdStatus: holdInfo.status,
            holdAmount: holdInfo.amount,
            holdReleased
          }
        })
      };
    }

    return {
      statusCode: waveStatusCode,
      headers: corsHeaders,
      body: JSON.stringify({
        ...waveResponse,
        success: true,
        message: waveResponse.message || 'تم قبول العرض بنجاح',
        data: {
          ...(waveResponse.data || {}),
          holdId: holdInfo.holdId,
          holdStatus: holdInfo.status,
          holdAmount: holdInfo.amount
        }
      })
    };
    
  } catch (error) {
    console.error('❌ Error accepting wave offer:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({
        success: false,
        message: 'خطأ في قبول الطلب',
        error: error.message
      })
    };
  }
}

/**
 * 🚫 Reject Wave Offer
 * Proxy request to WaveSystem_HandleDriverReject Lambda
 */
async function rejectWaveOffer(driverId, body, corsHeaders) {
  console.log('🚫 Reject Wave Offer called');
  console.log('Driver ID from token:', driverId);
  console.log('Request body:', JSON.stringify(body, null, 2));
  
  try {
    const { offerId, orderId, driverId: driverIdFromBody } = body;
    
    // Use driverId from body if token extraction failed
    const finalDriverId = driverId || driverIdFromBody;
    
    console.log('Final Driver ID:', finalDriverId);
    
    if (!offerId) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({
          success: false,
          message: 'Missing required field: offerId'
        })
      };
    }
    
    if (!finalDriverId) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({
          success: false,
          message: 'Missing required field: driverId'
        })
      };
    }
    
    // Call WaveSystem_HandleDriverReject Lambda
    const waveSystemRejectFn = (process.env.WAVESYSTEM_HANDLE_DRIVER_REJECT_FUNCTION_NAME || '').trim();
    if (!waveSystemRejectFn) {
      console.warn('⚠️ WaveSystem reject handler is not configured. Skipping WaveSystem invocation.');
      return {
        statusCode: 503,
        headers: corsHeaders,
        body: JSON.stringify({
          success: false,
          message: 'WaveSystem غير مُفعّل حالياً في هذا البيئة',
          error: 'WAVESYSTEM_NOT_CONFIGURED'
        })
      };
    }

    const { LambdaClient, InvokeCommand } = require('@aws-sdk/client-lambda');
    const lambda = new LambdaClient({ region: 'us-east-1' });
    
    const payload = {
      body: JSON.stringify({
        offerId,
        driverId: finalDriverId,
        orderId
      })
    };
    
    const command = new InvokeCommand({
      FunctionName: waveSystemRejectFn,
      InvocationType: 'RequestResponse',
      Payload: JSON.stringify(payload)
    });
    
    const response = await lambda.send(command);
    const result = JSON.parse(Buffer.from(response.Payload).toString());
    
    console.log('✅ Lambda response:', result);
    
    // Return the Lambda's response
    return {
      statusCode: result.statusCode || 200,
      headers: corsHeaders,
      body: result.body
    };
    
  } catch (error) {
    console.error('❌ Error rejecting wave offer:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({
        success: false,
        message: 'خطأ في رفض الطلب',
        error: error.message
      })
    };
  }
}

/**
 * 📊 Get driver performance metrics
 * GET /driver/metrics
 * Returns acceptance rate, response rate, and other statistics
 */
async function getDriverMetrics(driverId, corsHeaders) {
  try {
    console.log(`📊 Fetching metrics for driver: ${driverId}`);
    
    // جلب metrics من WizzDriverPerformanceMetrics
    const result = await dynamodb.send(new GetCommand({
      TableName: DRIVER_PERFORMANCE_METRICS_TABLE,
      Key: {
        PK: `DRIVER#${driverId}`,
        SK: 'METRICS'
      }
    }));
    
    if (!result.Item) {
      console.log('⚠️ No metrics found for driver, returning defaults');
      return {
        statusCode: 200,
        headers: corsHeaders,
        body: JSON.stringify({
          acceptanceRate: 0,
          responseRate: 0,
          completionRate: 0,
          totalAccepted: 0,
          totalRejected: 0,
          totalExpired: 0,
          totalOffersReceived: 0,
          consecutiveRejections: 0,
          rating: 0,
          totalTrips: 0
        })
      };
    }
    
    const metrics = result.Item;
    
    // إرجاع البيانات
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({
        acceptanceRate: metrics.acceptanceRate || 0,
        responseRate: metrics.responseRate || 0,
        completionRate: metrics.completionRate || 0,
        totalAccepted: metrics.totalAccepted || 0,
        totalRejected: metrics.totalRejected || 0,
        totalExpired: metrics.totalExpired || 0,
        totalOffersReceived: metrics.totalOffersReceived || 0,
        consecutiveRejections: metrics.consecutiveRejections || 0,
        rating: metrics.rating || 0,
        totalTrips: metrics.totalTrips || 0,
        updatedAt: metrics.updatedAt || null
      })
    };
    
  } catch (error) {
    console.error('❌ Error fetching driver metrics:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({
        error: 'خطأ في جلب إحصائيات السائق',
        message: error.message
      })
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 🚗 ACTIVE ORDER MANAGEMENT APIs
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Get order details by ID
 * GET /driver/orders/:orderId
 */
async function getOrderById(driverId, orderId, corsHeaders) {
  try {
    console.log(`📦 Fetching order ${orderId} for driver ${driverId}`);
    
    // Get order from Orders table using PK/SK structure
    const result = await dynamodb.send(new GetCommand({
      TableName: ORDERS_TABLE,
      Key: {
        PK: `ORDER#${orderId}`,
        SK: 'META'
      }
    }));
    
    if (!result.Item) {
      return {
        statusCode: 404,
        headers: corsHeaders,
        body: JSON.stringify({
          error: 'Order not found',
          message: 'الطلب غير موجود'
        })
      };
    }
    
    const order = result.Item;
    
    // Verify driver is assigned to this order
    if (order.driverId !== driverId) {
      return {
        statusCode: 403,
        headers: corsHeaders,
        body: JSON.stringify({
          error: 'Forbidden',
          message: 'هذا الطلب غير مخصص لك'
        })
      };
    }
    
    // Format response to match ActiveOrder model
    const response = {
      orderId: order.orderId,
      status: order.status || 'accepted',
      
      // Restaurant info
      restaurantId: order.restaurantId || order.businessId,
      restaurantName: order.restaurantName || order.businessName,
      restaurantAddress: order.restaurantAddress || order.pickupAddress,
      restaurantLat: order.restaurantLat || order.pickupLatitude,
      restaurantLng: order.restaurantLng || order.pickupLongitude,
      restaurantPhone: order.restaurantPhone || order.businessPhone,
      
      // Customer info
      customerId: order.customerId || order.userId,
      customerName: order.customerName || order.deliveryName,
      deliveryAddress: order.deliveryAddress || order.customerAddress, // Full address object
      customerAddress: order.customerAddress || order.deliveryAddress, // Keep for backward compatibility
      customerLat: order.customerLat || order.deliveryLatitude || (order.deliveryAddress && order.deliveryAddress.lat),
      customerLng: order.customerLng || order.deliveryLongitude || (order.deliveryAddress && order.deliveryAddress.lng),
      customerPhone: order.customerPhone || order.userPhone,
      customerLandmark: order.customerLandmark || order.deliveryLandmark || (order.deliveryAddress && order.deliveryAddress.landmark),
      
      // Order details
      orderNumber: order.orderNumber,
      total: order.total || order.totalAmount || 0,
      totalAmount: order.total || order.totalAmount || 0,
      paymentMethod: order.paymentMethod || 'cash',
      items: order.items || [],
      specialInstructions: order.specialInstructions || order.notes,
      
      // Pricing breakdown (NEW - for frontend display)
      pricing: order.pricing || null,
      
      // Timestamps
      acceptedAt: order.acceptedAt,
      arrivedAtStoreAt: order.arrivedAtStoreAt,
      pickedUpAt: order.pickedUpAt,
      arrivedAtCustomerAt: order.arrivedAtCustomerAt,
      deliveredAt: order.deliveredAt,
      createdAt: order.createdAt,
      updatedAt: order.updatedAt
    };
    
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify(response)
    };
    
  } catch (error) {
    console.error('❌ Error fetching order:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({
        error: 'Failed to fetch order',
        message: 'فشل في جلب بيانات الطلب'
      })
    };
  }
}

/**
 * Get driver's current active order
 * GET /driver/active-order
 */
async function getActiveOrder(driverId, corsHeaders) {
  try {
    console.log(`🔍 Checking active order for driver ${driverId}`);
    
    // Check driver's live state for current order
    const liveStateResult = await dynamodb.send(new GetCommand({
      TableName: DRIVER_LIVE_STATE_TABLE,
      Key: { driverId }
    }));
    
    console.log(`📊 Driver live state:`, JSON.stringify(liveStateResult.Item, null, 2));
    
    if (!liveStateResult.Item || !liveStateResult.Item.currentOrderId) {
      console.log(`ℹ️ No active order found for driver ${driverId}`);
      return {
        statusCode: 200,
        headers: corsHeaders,
        body: JSON.stringify({
          hasActiveOrder: false,
          order: null
        })
      };
    }
    
    const currentOrderId = liveStateResult.Item.currentOrderId;
    console.log(`✅ Driver has active order: ${currentOrderId}`);
    
    // Fetch order details
    const orderResponse = await getOrderById(driverId, currentOrderId, corsHeaders);
    
    // Check if order fetch was successful
    if (orderResponse.statusCode !== 200) {
      console.error(`❌ Failed to fetch order ${currentOrderId}:`, orderResponse);
      return {
        statusCode: 200,
        headers: corsHeaders,
        body: JSON.stringify({
          hasActiveOrder: false,
          order: null
        })
      };
    }
    
    // Parse order data
    const orderData = JSON.parse(orderResponse.body);
    
    console.log(`✅ Active order fetched successfully: ${currentOrderId}, status: ${orderData.status}`);
    
    // Return in expected format with hasActiveOrder flag
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({
        hasActiveOrder: true,
        order: orderData
      })
    };
    
  } catch (error) {
    console.error('❌ Error fetching active order:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({
        error: 'Failed to fetch active order',
        message: 'فشل في جلب الطلب النشط'
      })
    };
  }
}

/**
 * 🆕 Unassign driver from active order (order stays active, gets reassigned)
 * POST /driver/active-order/unassign
 * Body: { reason: string }
 * 
 * الفرق عن cancel-by-driver:
 * - unassign: الطلب يبقى نشط، يتم البحث عن سائق بديل (reassigning)
 * - cancel: الطلب يُلغى نهائياً للجميع (canceled_by_driver)
 */
async function unassignActiveOrder(driverId, body, corsHeaders) {
  console.log(`\n\n🚨 UNASSIGN FUNCTION CALLED! driverId=${driverId}, body=`, JSON.stringify(body));
  try {
    console.log(`🔄 Driver ${driverId} requesting unassignment:`, body);
    
    const now = new Date().toISOString();
    const { reason } = body;
    
    if (!reason) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({
          error: 'Missing reason',
          message: 'يجب تحديد سبب فك الارتباط'
        })
      };
    }
    
    // ===== STEP 1: Get driver's active order =====
    const liveStateResult = await dynamodb.send(new GetCommand({
      TableName: DRIVER_LIVE_STATE_TABLE,
      Key: { driverId }
    }));
    
    if (!liveStateResult.Item || !liveStateResult.Item.currentOrderId) {
      return {
        statusCode: 404,
        headers: corsHeaders,
        body: JSON.stringify({
          error: 'No active order',
          message: 'لا يوجد طلب نشط حالياً'
        })
      };
    }
    
    const orderId = liveStateResult.Item.currentOrderId;
    console.log(`📋 Found active order: ${orderId}`);
    
    // ===== STEP 2: Get order to verify status =====
    const orderResult = await dynamodb.send(new GetCommand({
      TableName: ORDERS_TABLE,
      Key: {
        PK: `ORDER#${orderId}`,
        SK: 'META'
      }
    }));
    
    if (!orderResult.Item) {
      return {
        statusCode: 404,
        headers: corsHeaders,
        body: JSON.stringify({
          error: 'Order not found',
          message: 'الطلب غير موجود'
        })
      };
    }
    
    const order = orderResult.Item;
    
    // Verify this order belongs to the driver
    if (order.driverId !== driverId) {
      return {
        statusCode: 403,
        headers: corsHeaders,
        body: JSON.stringify({
          error: 'Forbidden',
          message: 'هذا الطلب غير مخصص لك'
        })
      };
    }
    
    // Verify order can be unassigned (only before pickup)
    const allowedStatuses = ['accepted', 'heading_to_store', 'arrived_at_store'];
    if (!allowedStatuses.includes(order.status)) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({
          error: 'Cannot unassign',
          message: order.status === 'picked_up' || order.status === 'heading_to_customer' || order.status === 'arrived_at_customer'
            ? 'لا يمكن فك الارتباط بعد استلام الطلب من المطعم. يجب إلغاء الطلب بدلاً من ذلك.'
            : `لا يمكن فك الارتباط في حالة ${order.status}`
        })
      };
    }
    
    // ===== STEP 3: Call Order Service (handles Hold release + DB update + WebSocket) =====
    try {
      const orderServiceResult = await callOrderServiceUnassign(
        orderId,
        driverId,
        reason,
        driverId
      );
      
      console.log('✅ Order Service Unassign completed:', orderServiceResult);
      
      // ===== STEP 4: Update WizzDriverLiveState - Make driver available again =====
      console.log(`📊 Updating WizzDriverLiveState for driver ${driverId}`);
      await dynamodb.send(new UpdateCommand({
        TableName: DRIVER_LIVE_STATE_TABLE,
        Key: { driverId },
        UpdateExpression: 'REMOVE currentOrderId, currentWaveOfferId SET #status = :status, isSearching = :searching, activeOrdersCount = if_not_exists(activeOrdersCount, :one) - :one, lastUpdated = :now',
        ExpressionAttributeNames: {
          '#status': 'status'
        },
        ConditionExpression: 'attribute_exists(driverId)',
        ExpressionAttributeValues: {
          ':status': 'available',
          ':searching': true,
          ':one': 1,
          ':now': now
        }
      }));
      console.log('✅ Driver live state updated - Driver is now available for new orders');
      
      // ===== STEP 5: Update driver metrics (unassignment tracking) =====
      try {
        await dynamodb.send(new UpdateCommand({
          TableName: DRIVER_PERFORMANCE_METRICS_TABLE,
          Key: {
            PK: `DRIVER#${driverId}`,
            SK: 'METRICS'
          },
          UpdateExpression: 'ADD totalUnassigned :one SET unassignmentRate = if_not_exists(unassignmentRate, :zero) + :increment, updatedAt = :updatedAt',
          ExpressionAttributeValues: {
            ':one': 1,
            ':zero': 0,
            ':increment': 0.01,
            ':updatedAt': now
          }
        }));
      } catch (metricsError) {
        console.warn('⚠️ Failed to update metrics:', metricsError);
      }
      
      return {
        statusCode: 200,
        headers: corsHeaders,
        body: JSON.stringify({
          success: true,
          message: orderServiceResult.holdReleased 
            ? 'تم فك ارتباطك من الطلب وإعادة المبلغ المحجوز. يتم البحث عن سائق بديل.' 
            : 'تم فك ارتباطك من الطلب. يتم البحث عن سائق بديل.',
          orderId,
          unassignedAt: now,
          holdReleased: orderServiceResult.holdReleased,
          newStatus: orderServiceResult.newStatus
        })
      };
      
    } catch (orderServiceError) {
      console.error('❌ Order Service Unassign failed:', orderServiceError);
      
      // Return error to driver
      return {
        statusCode: 500,
        headers: corsHeaders,
        body: JSON.stringify({
          error: 'Order Service Unassign failed',
          message: 'فشل في فك الارتباط، يرجى المحاولة مرة أخرى',
          details: orderServiceError.message
        })
      };
    }
    
  } catch (error) {
    console.error('❌ Error unassigning from order:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({
        error: 'Failed to unassign from order',
        message: 'فشل في فك الارتباط من الطلب'
      })
    };
  }
}

/**
 * Update order status to heading to store (driver started journey)
 * POST /driver/orders/:orderId/start-heading
 */
async function startHeadingToStore(driverId, orderId, corsHeaders) {
  try {
    console.log(`🚗 Driver ${driverId} started heading to store for order ${orderId}`);
    
    const now = new Date().toISOString();
    
    // Update order status
    await dynamodb.send(new UpdateCommand({
      TableName: ORDERS_TABLE,
      Key: {
        PK: `ORDER#${orderId}`,
        SK: 'META'
      },
      UpdateExpression: 'SET #status = :status, orderStatus = :status, startHeadingToStoreAt = :startedAt, updatedAt = :updatedAt, updatedBy = :updatedBy',
      ExpressionAttributeNames: {
        '#status': 'status'
      },
      ExpressionAttributeValues: {
        ':status': 'heading_to_store',
        ':startedAt': now,
        ':updatedAt': now,
        ':updatedBy': 'driver_app',
        ':driverId': driverId
      },
      ConditionExpression: 'driverId = :driverId'
    }));
    
    console.log(`✅ Order ${orderId} status updated to heading_to_store`);
    
    // Get updated order
    return await getOrderById(driverId, orderId, corsHeaders);
    
  } catch (error) {
    console.error('❌ Error updating start heading to store:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({
        error: 'Failed to update status',
        message: 'فشل في تحديث حالة بدء التوجه للمطعم'
      })
    };
  }
}

/**
 * Update order status to arrived at store
 * POST /driver/orders/:orderId/arrive-store
 */
async function arriveAtStore(driverId, orderId, corsHeaders) {
  try {
    console.log(`🏪 Driver ${driverId} arrived at store for order ${orderId}`);
    
    const now = new Date().toISOString();
    
    // 🚗 Get driver info to add to order
    const driverInfo = await getDriverInfo(driverId);
    
    // Update order status with driver info
    const updateExpression = driverInfo 
      ? 'SET #status = :status, arrivedAtStoreAt = :arrivedAt, updatedAt = :updatedAt, driverName = :driverName, driverPhone = :driverPhone, vehicleType = :vehicleType, vehiclePlate = :vehiclePlate'
      : 'SET #status = :status, arrivedAtStoreAt = :arrivedAt, updatedAt = :updatedAt';
    
    const expressionValues = {
      ':status': 'arrived_at_store',
      ':arrivedAt': now,
      ':updatedAt': now,
      ':driverId': driverId
    };
    
    if (driverInfo) {
      Object.assign(expressionValues, {
        ':driverName': driverInfo.driverName,
        ':driverPhone': driverInfo.driverPhone,
        ':vehicleType': driverInfo.vehicleType,
        ':vehiclePlate': driverInfo.vehiclePlate
      });
    }
    
    await dynamodb.send(new UpdateCommand({
      TableName: ORDERS_TABLE,
      Key: {
        PK: `ORDER#${orderId}`,
        SK: 'META'
      },
      UpdateExpression: updateExpression,
      ExpressionAttributeNames: {
        '#status': 'status'
      },
      ExpressionAttributeValues: expressionValues,
      ConditionExpression: 'driverId = :driverId'
    }));
    
    // Get updated order
    return await getOrderById(driverId, orderId, corsHeaders);
    
  } catch (error) {
    console.error('❌ Error updating arrived at store:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({
        error: 'Failed to update status',
        message: 'فشل في تحديث حالة الوصول للمطعم'
      })
    };
  }
}

/**
 * Update order status to picked up
 * POST /driver/orders/:orderId/pickup
 */
async function pickupOrder(driverId, orderId, corsHeaders) {
  try {
    console.log(`📦 Driver ${driverId} picked up order ${orderId}`);
    
    const now = new Date().toISOString();
    
    // 🚗 Get driver info to add to order
    const driverInfo = await getDriverInfo(driverId);
    
    // Update order status with driver info
    const updateExpression = driverInfo 
      ? 'SET #status = :status, pickedUpAt = :pickedUpAt, updatedAt = :updatedAt, driverName = :driverName, driverPhone = :driverPhone, vehicleType = :vehicleType, vehiclePlate = :vehiclePlate'
      : 'SET #status = :status, pickedUpAt = :pickedUpAt, updatedAt = :updatedAt';
    
    const expressionValues = {
      ':status': 'picked_up',
      ':pickedUpAt': now,
      ':updatedAt': now,
      ':driverId': driverId
    };
    
    if (driverInfo) {
      Object.assign(expressionValues, {
        ':driverName': driverInfo.driverName,
        ':driverPhone': driverInfo.driverPhone,
        ':vehicleType': driverInfo.vehicleType,
        ':vehiclePlate': driverInfo.vehiclePlate
      });
    }
    
    await dynamodb.send(new UpdateCommand({
      TableName: ORDERS_TABLE,
      Key: {
        PK: `ORDER#${orderId}`,
        SK: 'META'
      },
      UpdateExpression: updateExpression,
      ExpressionAttributeNames: {
        '#status': 'status'
      },
      ExpressionAttributeValues: expressionValues,
      ConditionExpression: 'driverId = :driverId'
    }));
    
    // Get updated order
    return await getOrderById(driverId, orderId, corsHeaders);
    
  } catch (error) {
    console.error('❌ Error updating pickup:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({
        error: 'Failed to update pickup status',
        message: 'فشل في تحديث حالة استلام الطلب'
      })
    };
  }
}

/**
 * Update order status to heading to customer (after pickup)
 * POST /driver/orders/:orderId/start-heading-to-customer
 */
async function startHeadingToCustomer(driverId, orderId, corsHeaders) {
  try {
    console.log(`🚗 Driver ${driverId} started heading to customer for order ${orderId}`);
    
    const now = new Date().toISOString();
    
    // 🚗 Get driver info to add to order
    const driverInfo = await getDriverInfo(driverId);
    
    // Update order status with driver info
    const updateExpression = driverInfo 
      ? 'SET #status = :status, orderStatus = :status, startHeadingToCustomerAt = :startedAt, updatedAt = :updatedAt, updatedBy = :updatedBy, driverName = :driverName, driverPhone = :driverPhone, vehicleType = :vehicleType, vehiclePlate = :vehiclePlate'
      : 'SET #status = :status, orderStatus = :status, startHeadingToCustomerAt = :startedAt, updatedAt = :updatedAt, updatedBy = :updatedBy';
    
    const expressionValues = {
      ':status': 'heading_to_customer',
      ':startedAt': now,
      ':updatedAt': now,
      ':updatedBy': 'driver_app',
      ':driverId': driverId
    };
    
    if (driverInfo) {
      Object.assign(expressionValues, {
        ':driverName': driverInfo.driverName,
        ':driverPhone': driverInfo.driverPhone,
        ':vehicleType': driverInfo.vehicleType,
        ':vehiclePlate': driverInfo.vehiclePlate
      });
    }
    
    await dynamodb.send(new UpdateCommand({
      TableName: ORDERS_TABLE,
      Key: {
        PK: `ORDER#${orderId}`,
        SK: 'META'
      },
      UpdateExpression: updateExpression,
      ExpressionAttributeNames: {
        '#status': 'status'
      },
      ExpressionAttributeValues: expressionValues,
      ConditionExpression: 'driverId = :driverId'
    }));
    
    console.log(`✅ Order ${orderId} status updated to heading_to_customer`);
    
    // Get updated order
    return await getOrderById(driverId, orderId, corsHeaders);
    
  } catch (error) {
    console.error('❌ Error updating start heading to customer:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({
        error: 'Failed to update status',
        message: 'فشل في تحديث حالة بدء التوجه للعميل'
      })
    };
  }
}

/**
 * Update order status to arrived at customer
 * POST /driver/orders/:orderId/arrive-customer
 */
async function arriveAtCustomer(driverId, orderId, corsHeaders) {
  try {
    console.log(`🏠 Driver ${driverId} arrived at customer for order ${orderId}`);
    
    const now = new Date().toISOString();
    
    // 🚗 Get driver info to add to order
    const driverInfo = await getDriverInfo(driverId);
    
    // Update order status with driver info
    const updateExpression = driverInfo 
      ? 'SET #status = :status, arrivedAtCustomerAt = :arrivedAt, updatedAt = :updatedAt, driverName = :driverName, driverPhone = :driverPhone, vehicleType = :vehicleType, vehiclePlate = :vehiclePlate'
      : 'SET #status = :status, arrivedAtCustomerAt = :arrivedAt, updatedAt = :updatedAt';
    
    const expressionValues = {
      ':status': 'arrived_at_customer',
      ':arrivedAt': now,
      ':updatedAt': now,
      ':driverId': driverId
    };
    
    if (driverInfo) {
      Object.assign(expressionValues, {
        ':driverName': driverInfo.driverName,
        ':driverPhone': driverInfo.driverPhone,
        ':vehicleType': driverInfo.vehicleType,
        ':vehiclePlate': driverInfo.vehiclePlate
      });
    }
    
    await dynamodb.send(new UpdateCommand({
      TableName: ORDERS_TABLE,
      Key: {
        PK: `ORDER#${orderId}`,
        SK: 'META'
      },
      UpdateExpression: updateExpression,
      ExpressionAttributeNames: {
        '#status': 'status'
      },
      ExpressionAttributeValues: expressionValues,
      ConditionExpression: 'driverId = :driverId'
    }));
    
    // Get updated order
    return await getOrderById(driverId, orderId, corsHeaders);
    
  } catch (error) {
    console.error('❌ Error updating arrived at customer:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({
        error: 'Failed to update status',
        message: 'فشل في تحديث حالة الوصول للعميل'
      })
    };
  }
}

/**
 * Complete order delivery
 * POST /driver/orders/:orderId/deliver
 * Body: { cashCollected?: number, deliveryNotes?: string }
 */
async function deliverOrder(driverId, orderId, body, corsHeaders) {
  try {
    console.log(`✅ Driver ${driverId} delivering order ${orderId}`, body);
    
    const now = new Date().toISOString();
    
    // 🚗 Get driver info to add to order
    const driverInfo = await getDriverInfo(driverId);
    
    // 🔍 GET ORDER FIRST to check holdId and holdAmount
    const getOrderResult = await dynamodb.send(new GetCommand({
      TableName: ORDERS_TABLE,
      Key: {
        PK: `ORDER#${orderId}`,
        SK: 'META'
      }
    }));
    
    const order = getOrderResult.Item;
    if (!order) {
      throw new Error(`Order ${orderId} not found`);
    }
    
    // 💰 CAPTURE HOLD if exists and is ACTIVE
    let captureResult = null;
    if (order.holdId && order.holdStatus === 'ACTIVE') {
      console.log(`💰 Order has active hold: ${order.holdId}, capturing...`);
      console.log(`💰 Hold Amount to capture: ${order.holdAmount} IQD`);
      
      captureResult = await captureWalletHold(
        order.holdId,
        order.holdAmount, // Capture the full hold amount (goodsSubtotal only)
        'Order delivered successfully',
        orderId
      );
      
      if (!captureResult.success) {
        console.error(`❌ WARNING: Failed to capture hold for order ${orderId}:`, captureResult.error);
        // ⚠️ Continue anyway - don't block delivery, but log for manual intervention
        // The driver delivered the order physically, we can't rollback that
      } else {
        console.log(`✅ Hold captured successfully: ${captureResult.capturedAmount} IQD`);
      }
    } else {
      console.log(`ℹ️ No active hold to capture for order ${orderId}`);
      console.log(`   - holdId: ${order.holdId || 'null'}`);
      console.log(`   - holdStatus: ${order.holdStatus || 'null'}`);
    }
    
    // ✅ Get cashCollected checkbox value from request body
    const cashCollected = body.cashCollected === true; // boolean
    const cashCollectedAmount = body.cashAmount || body.cashCollected || null; // المبلغ الفعلي
    
    console.log(`💵 Cash Collection Info:`);
    console.log(`   - Checkbox Confirmed: ${cashCollected}`);
    console.log(`   - Cash Amount: ${cashCollectedAmount} IQD`);
    
    // Update order status with driver info AND hold status AND cashCollected
    const updateExpression = driverInfo 
      ? 'SET #status = :status, deliveredAt = :deliveredAt, cashCollected = :cashCollected, cashCollectedAmount = :cashAmount, deliveryNotes = :deliveryNotes, holdStatus = :holdStatus, updatedAt = :updatedAt, driverName = :driverName, driverPhone = :driverPhone, vehicleType = :vehicleType, vehiclePlate = :vehiclePlate'
      : 'SET #status = :status, deliveredAt = :deliveredAt, cashCollected = :cashCollected, cashCollectedAmount = :cashAmount, deliveryNotes = :deliveryNotes, holdStatus = :holdStatus, updatedAt = :updatedAt';
    
    const expressionValues = {
      ':status': 'delivered',
      ':deliveredAt': now,
      ':cashCollected': cashCollected, // ← من checkbox
      ':cashAmount': cashCollectedAmount, // ← المبلغ الفعلي المستلم
      ':deliveryNotes': body.deliveryNotes || null,
      ':holdStatus': captureResult?.success ? 'CAPTURED' : order.holdStatus, // Update hold status
      ':updatedAt': now,
      ':driverId': driverId
    };
    
    if (driverInfo) {
      Object.assign(expressionValues, {
        ':driverName': driverInfo.driverName,
        ':driverPhone': driverInfo.driverPhone,
        ':vehicleType': driverInfo.vehicleType,
        ':vehiclePlate': driverInfo.vehiclePlate
      });
    }
    
    await dynamodb.send(new UpdateCommand({
      TableName: ORDERS_TABLE,
      Key: {
        PK: `ORDER#${orderId}`,
        SK: 'META'
      },
      UpdateExpression: updateExpression,
      ExpressionAttributeNames: {
        '#status': 'status'
      },
      ExpressionAttributeValues: expressionValues,
      ConditionExpression: 'driverId = :driverId'
    }));
    
    // Update driver live state - make driver available again
    await dynamodb.send(new UpdateCommand({
      TableName: DRIVER_LIVE_STATE_TABLE,
      Key: { driverId },
      UpdateExpression: 'REMOVE currentOrderId, currentDeliveryJob SET #status = :status, isAvailable = :available, isSearching = :searching, activeOrdersCount = if_not_exists(activeOrdersCount, :one) - :one, lastOnlineAt = :now, updatedAt = :now',
      ExpressionAttributeNames: {
        '#status': 'status'
      },
      ConditionExpression: 'attribute_exists(driverId) AND activeOrdersCount > :zero',
      ExpressionAttributeValues: {
        ':status': 'available',
        ':available': true,
        ':searching': true,
        ':zero': 0,
        ':one': 1,
        ':now': now
      }
    }));
    
    // Update dispatch job status to completed
    try {
      if (!DISPATCH_JOBS_TABLE) {
        console.log('ℹ️ DISPATCH_JOBS_TABLE not configured - skipping dispatch job update');
      } else {
      const dispatchJobId = `DISPATCH_${orderId}_${Date.now()}`;
      await dynamodb.send(new UpdateCommand({
        TableName: DISPATCH_JOBS_TABLE,
        Key: {
          orderId: orderId,
          SK: 'METADATA'
        },
        UpdateExpression: 'SET #status = :status, completedAt = :completedAt, updatedAt = :updatedAt',
        ExpressionAttributeNames: {
          '#status': 'status'
        },
        ExpressionAttributeValues: {
          ':status': 'completed',
          ':completedAt': now,
          ':updatedAt': now
        }
      }));
      }
    } catch (dispatchError) {
      console.warn('⚠️ Failed to update dispatch job:', dispatchError);
    }
    
    // Update driver metrics (total trips, completion rate)
    try {
      console.log(`📊 ========================================`);
      console.log(`📊 UPDATING DRIVER METRICS`);
      console.log(`📊 Driver ID: ${driverId}`);
      console.log(`📊 Order ID: ${orderId}`);
      console.log(`📊 Table: ${DRIVER_PERFORMANCE_METRICS_TABLE}`);
      console.log(`📊 ========================================`);
      
      // First, increment counters (CREATE if not exists)
      // ⚠️ CRITICAL: Use separate SET for totalTrips/totalCompleted to handle initialization
      const metricsResult = await dynamodb.send(new UpdateCommand({
        TableName: DRIVER_PERFORMANCE_METRICS_TABLE,
        Key: {
          PK: `DRIVER#${driverId}`,
          SK: 'METRICS'
        },
        UpdateExpression: 'SET totalTrips = if_not_exists(totalTrips, :zero) + :one, totalCompleted = if_not_exists(totalCompleted, :zero) + :one, driverId = :driverId, lastEventType = :eventType, lastEventOrderId = :orderId, lastEventTimestamp = :now, lastCompletedAt = :now, updatedAt = :now',
        ExpressionAttributeValues: {
          ':one': 1,
          ':zero': 0,
          ':driverId': driverId,
          ':eventType': 'ORDER_DELIVERED',
          ':orderId': orderId,
          ':now': now
        },
        ReturnValues: 'ALL_NEW'
      }));
      
      console.log(`📊 After increment - Raw result:`, JSON.stringify(metricsResult.Attributes, null, 2));
      
      // Calculate completion rate: totalCompleted / totalAccepted
      const totalAccepted = metricsResult.Attributes?.totalAccepted || 1;
      const totalCompleted = metricsResult.Attributes?.totalCompleted || 1;
      const totalTrips = metricsResult.Attributes?.totalTrips || 1;
      const newCompletionRate = totalCompleted / totalAccepted;
      
      console.log(`📊 Calculations:`);
      console.log(`   totalAccepted: ${totalAccepted}`);
      console.log(`   totalCompleted: ${totalCompleted}`);
      console.log(`   totalTrips: ${totalTrips}`);
      console.log(`   completionRate: ${newCompletionRate}`);
      
      // Update completion rate with calculated value
      await dynamodb.send(new UpdateCommand({
        TableName: DRIVER_PERFORMANCE_METRICS_TABLE,
        Key: {
          PK: `DRIVER#${driverId}`,
          SK: 'METRICS'
        },
        UpdateExpression: 'SET completionRate = :rate',
        ExpressionAttributeValues: {
          ':rate': newCompletionRate
        }
      }));
      
      console.log(`✅ ========================================`);
      console.log(`✅ METRICS UPDATED SUCCESSFULLY!`);
      console.log(`✅ totalTrips: ${totalTrips}`);
      console.log(`✅ totalCompleted: ${totalCompleted}`);
      console.log(`✅ completionRate: ${newCompletionRate}`);
      console.log(`✅ lastEventOrderId: ${orderId}`);
      console.log(`✅ ========================================`);
    } catch (metricsError) {
      console.error(`❌ ========================================`);
      console.error(`❌ FAILED TO UPDATE METRICS!`);
      console.error(`❌ Error:`, metricsError);
      console.error(`❌ Error name:`, metricsError.name);
      console.error(`❌ Error message:`, metricsError.message);
      console.error(`❌ Driver ID:`, driverId);
      console.error(`❌ Order ID:`, orderId);
      console.error(`❌ Stack:`, metricsError.stack);
      console.error(`❌ ========================================`);
      // لا نرمي الخطأ - نكمل العملية حتى لو فشل تحديث المقاييس
    }
    
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({
        success: true,
        message: 'تم تسليم الطلب بنجاح',
        orderId,
        deliveredAt: now,
        holdCaptured: captureResult?.success || false,
        capturedAmount: captureResult?.capturedAmount || 0,
        cashCollected: cashCollected,
        cashCollectedAmount: cashCollectedAmount
      })
    };
    
  } catch (error) {
    console.error('❌ Error delivering order:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({
        error: 'Failed to deliver order',
        message: 'فشل في تسليم الطلب'
      })
    };
  }
}

/**
 * Report store issue
 * POST /driver/orders/:orderId/issue
 * Body: { issueType: string, notes: string }
 */
async function reportStoreIssue(driverId, orderId, body, corsHeaders) {
  try {
    console.log(`⚠️ Driver ${driverId} reporting issue for order ${orderId}:`, body);
    
    const now = new Date().toISOString();
    const { issueType, notes } = body;
    
    if (!issueType) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({
          error: 'Missing issueType',
          message: 'يجب تحديد نوع المشكلة'
        })
      };
    }
    
    // Add issue to order
    await dynamodb.send(new UpdateCommand({
      TableName: ORDERS_TABLE,
      Key: {
        PK: `ORDER#${orderId}`,
        SK: 'META'
      },
      UpdateExpression: 'SET storeIssue = :issue, storeIssueReportedAt = :reportedAt, updatedAt = :updatedAt',
      ExpressionAttributeValues: {
        ':issue': { type: issueType, notes, reportedBy: driverId, reportedAt: now },
        ':reportedAt': now,
        ':updatedAt': now,
        ':driverId': driverId
      },
      ConditionExpression: 'driverId = :driverId'
    }));
    
    // TODO: Send notification to support team
    
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({
        success: true,
        message: 'تم الإبلاغ عن المشكلة بنجاح',
        orderId,
        issueType
      })
    };
    
  } catch (error) {
    console.error('❌ Error reporting store issue:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({
        error: 'Failed to report issue',
        message: 'فشل في الإبلاغ عن المشكلة'
      })
    };
  }
}

/**
 * Report customer unreachable
 * POST /driver/orders/:orderId/customer-unreachable
 */
async function reportCustomerUnreachable(driverId, orderId, corsHeaders) {
  try {
    console.log(`📵 Driver ${driverId} reporting customer unreachable for order ${orderId}`);
    
    const now = new Date().toISOString();
    
    // Get current attempts count
    const orderResult = await dynamodb.send(new GetCommand({
      TableName: ORDERS_TABLE,
      Key: {
        PK: `ORDER#${orderId}`,
        SK: 'META'
      }
    }));
    
    if (!orderResult.Item) {
      return {
        statusCode: 404,
        headers: corsHeaders,
        body: JSON.stringify({
          error: 'Order not found',
          message: 'الطلب غير موجود'
        })
      };
    }
    
    const customerUnreachableAttempts = (orderResult.Item.customerUnreachableAttempts || 0) + 1;
    
    // Update order
    await dynamodb.send(new UpdateCommand({
      TableName: ORDERS_TABLE,
      Key: {
        PK: `ORDER#${orderId}`,
        SK: 'META'
      },
      UpdateExpression: 'SET customerUnreachableAttempts = :attempts, lastUnreachableAttemptAt = :attemptAt, updatedAt = :updatedAt',
      ExpressionAttributeValues: {
        ':attempts': customerUnreachableAttempts,
        ':attemptAt': now,
        ':updatedAt': now,
        ':driverId': driverId
      },
      ConditionExpression: 'driverId = :driverId'
    }));
    
    // If 3+ attempts, initiate cancellation protocol
    if (customerUnreachableAttempts >= 3) {
      await dynamodb.send(new UpdateCommand({
        TableName: ORDERS_TABLE,
        Key: {
          PK: `ORDER#${orderId}`,
          SK: 'META'
        },
        UpdateExpression: 'SET #status = :status, cancelledAt = :cancelledAt, cancellationReason = :reason',
        ExpressionAttributeNames: {
          '#status': 'status'
        },
        ExpressionAttributeValues: {
          ':status': 'cancelled',
          ':cancelledAt': now,
          ':reason': 'customer_unreachable'
        }
      }));
      
      // Clear driver's current order
      await dynamodb.send(new UpdateCommand({
        TableName: DRIVER_LIVE_STATE_TABLE,
        Key: { driverId },
        UpdateExpression: 'REMOVE currentOrderId SET isAvailable = :available',
        ExpressionAttributeValues: {
          ':available': true
        }
      }));
      
      return {
        statusCode: 200,
        headers: corsHeaders,
        body: JSON.stringify({
          success: true,
          message: 'تم إلغاء الطلب بسبب عدم الوصول للعميل',
          orderId,
          attempts: customerUnreachableAttempts,
          cancelled: true
        })
      };
    }
    
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({
        success: true,
        message: `تم تسجيل المحاولة (${customerUnreachableAttempts}/3)`,
        orderId,
        attempts: customerUnreachableAttempts,
        cancelled: false
      })
    };
    
  } catch (error) {
    console.error('❌ Error reporting customer unreachable:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({
        error: 'Failed to report customer unreachable',
        message: 'فشل في الإبلاغ عن عدم الوصول للعميل'
      })
    };
  }
}

/**
 * Cancel order by driver
 * POST /driver/orders/:orderId/cancel-by-driver
 * Body: { reason: string, notes?: string }
 */
async function cancelOrderByDriver(driverId, orderId, body, corsHeaders) {
  try {
    console.log(`❌ Driver ${driverId} cancelling order ${orderId}:`, body);
    
    const now = new Date().toISOString();
    const { reason, notes } = body;
    
    if (!reason) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({
          error: 'Missing reason',
          message: 'يجب تحديد سبب الإلغاء'
        })
      };
    }
    
    // ===== STEP 1: Get order to verify ownership and status =====
    const orderResult = await dynamodb.send(new GetCommand({
      TableName: ORDERS_TABLE,
      Key: {
        PK: `ORDER#${orderId}`,
        SK: 'META'
      }
    }));
    
    if (!orderResult.Item) {
      return {
        statusCode: 404,
        headers: corsHeaders,
        body: JSON.stringify({
          error: 'Order not found',
          message: 'الطلب غير موجود'
        })
      };
    }
    
    const order = orderResult.Item;
    
    // Verify this order belongs to the driver
    if (order.driverId !== driverId) {
      return {
        statusCode: 403,
        headers: corsHeaders,
        body: JSON.stringify({
          error: 'Forbidden',
          message: 'هذا الطلب غير مخصص لك'
        })
      };
    }
    
    // Verify order can be cancelled
    const allowedStatuses = ['accepted', 'heading_to_store', 'arrived_at_store'];
    if (!allowedStatuses.includes(order.status)) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({
          error: 'Cannot cancel',
          message: `لا يمكن إلغاء الطلب في حالة ${order.status}`
        })
      };
    }
    
    // ===== STEP 2: Call Order Service (handles Hold release + DB update) =====
    try {
      const orderServiceResult = await callOrderService(
        orderId,
        'driver',
        reason + (notes ? ` - ${notes}` : ''),
        driverId
      );
      
      console.log('✅ Order Service completed:', orderServiceResult);
      
      // ===== STEP 3: Update WizzDriverLiveState - Make driver available again =====
      console.log(`📊 Updating WizzDriverLiveState for driver ${driverId}`);
      await dynamodb.send(new UpdateCommand({
        TableName: DRIVER_LIVE_STATE_TABLE,
        Key: { driverId },
        UpdateExpression: 'REMOVE currentOrderId, currentWaveOfferId SET #status = :status, isSearching = :searching, activeOrdersCount = if_not_exists(activeOrdersCount, :one) - :one, lastUpdated = :now',
        ExpressionAttributeNames: {
          '#status': 'status'
        },
        ConditionExpression: 'attribute_exists(driverId) AND activeOrdersCount > :zero',
        ExpressionAttributeValues: {
          ':status': 'available',
          ':searching': true,
          ':zero': 0,
          ':one': 1,
          ':now': now
        }
      }));
      console.log('✅ Driver live state updated - Driver is now available for new orders');
      
      // ===== STEP 4: Update driver metrics (cancellation rate) =====
      try {
        await dynamodb.send(new UpdateCommand({
          TableName: DRIVER_PERFORMANCE_METRICS_TABLE,
          Key: {
            PK: `DRIVER#${driverId}`,
            SK: 'METRICS'
          },
          UpdateExpression: 'ADD totalCancelled :one SET cancellationRate = if_not_exists(cancellationRate, :zero) + :increment, updatedAt = :updatedAt',
          ExpressionAttributeValues: {
            ':one': 1,
            ':zero': 0,
            ':increment': 0.01,
            ':updatedAt': now
          }
        }));
      } catch (metricsError) {
        console.warn('⚠️ Failed to update metrics:', metricsError);
      }
      
      return {
        statusCode: 200,
        headers: corsHeaders,
        body: JSON.stringify({
          success: true,
          message: orderServiceResult.holdReleased 
            ? 'تم إلغاء الطلب وإعادة المبلغ المحجوز' 
            : 'تم إلغاء الطلب',
          orderId,
          cancelledAt: now,
          holdReleased: orderServiceResult.holdReleased,
          newStatus: orderServiceResult.newStatus
        })
      };
      
    } catch (orderServiceError) {
      console.error('❌ Order Service failed:', orderServiceError);
      
      // Return error to driver
      return {
        statusCode: 500,
        headers: corsHeaders,
        body: JSON.stringify({
          error: 'Order Service failed',
          message: 'فشل في إلغاء الطلب، يرجى المحاولة مرة أخرى',
          details: orderServiceError.message
        })
      };
    }
    
  } catch (error) {
    console.error('❌ Error cancelling order:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({
        error: 'Failed to cancel order',
        message: 'فشل في إلغاء الطلب'
      })
    };
  }
}

