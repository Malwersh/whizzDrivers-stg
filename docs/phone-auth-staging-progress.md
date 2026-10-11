# Driver phone authentication — staging

Implemented: Iraq-only normalization; HMAC-bound OTP challenges; five attempts;
five-minute explicit expiry; atomic one-time consumption; atomic phone cooldown
and per-phone daily send cap; server-side OTPIQ secret; Cognito-token client;
pilot Flutter screen at /new-login/phone-otp. Existing login remains default.

Existing pool: us-east-1_RGTqUXF5C; client: 2d26d3muq0vvcuf42lkpgmkgsr.
OTP custom-auth triggers are attached and ALLOW_CUSTOM_AUTH enabled.
PostConfirmation wallet creation trigger and existing auth flows verified preserved.
Live Lambda initialization checked without sending messages.
Rollback settings: /tmp/whizzdrivers-phone-auth-cognito-backup.json.
Secret: wizz/staging/otpiq (apiKey and hmacKey). Never log values or OTP codes.
Infrastructure: backend/phone-auth-template.yaml, stack drivers-phone-auth-staging.

Audit: 12 existing Cognito accounts, 5 confirmed with verified phone; remaining
accounts need enrollment using existing credentials or reviewed recovery.
Unverified existing phones are denied custom login. No accounts migrated.

Outstanding before default rollout:
- Credential-backed enrollment/recovery for existing accounts lacking verified phone.
- New-account phone verification before provisioning identity, profile and wallet,
  with atomic phone uniqueness and retry-safe creation.
- IP/device/global send caps and monitoring in addition to existing phone limits.
- Live end-to-end OTP delivery and login test with a designated test number.
- Registration/profile/status routing tests, refresh/logout tests and rollback test.
- Only then replace default login/register routes.

Current tests verify policy, expiry, wrong answers, concurrent one-time consumption,
phone verification, rejection of unverified legacy phone, and previous approval gates.

## Registration implementation
API deployed: https://yyka17sq38.execute-api.us-east-1.amazonaws.com/staging
POST /auth/phone/send and /auth/phone/verify. Ordinary login/register routes now
use phone OTP; /login-legacy remains for transitional recovery.
OTP is consumed before identity provisioning; existing confirmed verified-phone
accounts preserve sub. New profiles are PENDING_PROFILE, isVerified=false.
Short-lived one-time proof exchanges into Cognito through Amplify custom auth.
Phone/IP/global daily limits apply to public send endpoint.
Live test: new identity, Cognito token issuance, GetUser and driver profile API,
wallet creation, denial of start-searching (403), refresh and revocation passed.
Remaining: test the full Flutter interaction and profile document submission;
implement credential-backed phone enrollment for old unverified accounts.
No Dev changes. No existing accounts migrated automatically.

## Simplified profile and registration geography
OTP success now checks the profile and navigates directly; splash is startup only.
Profile schema v2: name, Iraq country ID/code, governorate ID, work-region ID,
landmark (home_address_text), drivingLicenseUrl, registrationPaperUrl, nationalIdUrl.
Names and district lineage are server-derived. home_region_id is a compatibility
reference to the selected work region; current_work_region_id in LiveState remains
GPS-derived on work activation. Registration never activates a driver or overwrites
LiveState. No vehicle type or numeric license/national ID is required from applicant.
GET /driver/registration-options reads paginated RegionsDerived staging data,
excludes closed areas and explicit disabled delivery, and returns only governors
with eligible level-3 work regions. No synthetic fallback geography.
PUT validates selected ancestry and document S3 namespace; v2 completion leads
to PENDING_REVIEW. Legacy profile completeness remains available for old records.
Live options check: Iraq, Najaf governorate, seven open work areas.
20 server tests and Flutter analysis passed; real applicant document submission
remains to be exercised through the new UI.
