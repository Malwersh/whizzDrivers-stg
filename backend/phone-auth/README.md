# Staging phone authentication

Phone-only registration can resume an abandoned Cognito UNCONFIRMED account only after a valid current OTP is consumed, the account is enabled, no verified email is present, and consistent reads find neither a driver profile nor a wallet. The original Cognito subject is preserved. Phone verification is set before a permanent random password confirms the account; retries while still UNCONFIRMED are supported. Confirmed accounts with unverified phone numbers remain blocked from this recovery path.

Driver creation remains conditional and starts in PENDING_PROFILE with isVerified=false. Phone ownership does not imply administrator approval. Wallet creation and short-lived login proof follow the existing flow. No account is manually confirmed or deleted by this correction.

Registration reads staging-Wallets with GetItem only. Runtime credentials remain in Secrets Manager. This folder has its own minimal Node package; SAM handlers are registration.handler and triggers.handler. Isolating CodeUri avoids packaging unrelated backend files and nested build artifacts.

Validation: six registration tests cover normal existing/new accounts, wrong/expired OTP, legacy account protection, abandoned registration recovery, and rejecting accounts with a profile or wallet. Live read-only verification for phone 07831367435 found UNCONFIRMED, phone unverified, no driver profile and no wallet. A fresh real OTP and user completion are needed for final acceptance.
