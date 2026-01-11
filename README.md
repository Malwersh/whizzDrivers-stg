# WhizzDrivers - Staging Environment

## 📋 Overview
This is the **clean staging environment** for the WhizzDrivers application. This directory contains only the essential files needed for production deployment, without test files, debug screens, or development artifacts.

## 🗂️ Project Structure

```
whizzDrivers-stg/
├── frontend/              # Flutter driver application (Staging)
│   ├── lib/              # Clean Dart source code (no test/debug files)
│   ├── android/          # Android platform configuration
│   ├── ios/              # iOS platform configuration
│   ├── assets/           # Application assets
│   └── pubspec.yaml      # Flutter dependencies
│
└── backend/              # AWS Lambda backend (Staging)
    ├── lambda_driver_api_v2.js    # Main Lambda function
    ├── package.json               # Node.js dependencies
    └── wallet-service/            # Wallet integration service
```

## 🎯 Environment Configuration

**Environment:** Staging (`stg`)
**AWS Region:** us-east-1
**Status:** Ready for AWS resource creation

### Required AWS Resources (To Be Created):
- [ ] Cognito User Pool: `WhizzDrivers-stg`
- [ ] Lambda Function: `driver-profile-api-staging`
- [ ] API Gateway: Staging endpoints
- [ ] WebSocket API: Staging connections
- [ ] DynamoDB Tables: With environment field = 'stg'

## 🚀 Deployment Steps

### 1. Frontend Deployment
```bash
cd frontend
flutter clean
flutter pub get
flutter build apk --release  # Android
flutter build ios --release  # iOS
```

### 2. Backend Deployment
```bash
cd backend
npm install
# Deploy to AWS Lambda (staging profile)
aws lambda update-function-code \
  --function-name driver-profile-api-staging \
  --zip-file fileb://deployment.zip \
  --profile Wizz_staging_UserApp
```

## 📝 Configuration Files

### Environment Configuration
- `frontend/lib/config/environment.dart` - Main environment config (needs AWS resource IDs)
- `frontend/lib/config/environment_staging.dart` - Staging-specific config
- `frontend/lib/config/app_config.dart` - Application settings

### AWS Configuration
- Cognito User Pool ID: `STAGING_POOL_TO_BE_CREATED`
- App Client ID: `STAGING_CLIENT_TO_BE_CREATED`
- API Gateway: `STAGING_API_GATEWAY.execute-api.us-east-1.amazonaws.com`

## 🔧 Differences from Development

| Aspect | Development (dev) | Staging (stg) |
|--------|------------------|---------------|
| Size | ~5 GB | ~197 MB |
| Files | 500+ files (with tests/docs) | Essential files only |
| Debug Screens | ✅ Included | ❌ Removed |
| Test Files | ✅ Included | ❌ Removed |
| Backup Files | ✅ Included | ❌ Removed |
| Documentation | 210+ MD files | This README only |
| Environment | dev | stg |

## ✅ Cleanup Applied

The following non-essential files were **excluded** from this staging copy:
- 🚫 No debug screens or test files
- 🚫 No backup or old versions of code files
- 🚫 No Python/Shell scripts in lib/
- 🚫 No .broken, .temp, .disabled files
- 🚫 No deployment zip files in backend
- 🚫 No excessive documentation

## 🔒 Security Notes

Before deploying:
1. Update all AWS resource IDs in `environment.dart`
2. Create new Cognito User Pool for staging
3. Use separate AWS profile for staging deployments
4. Configure staging-specific API keys and secrets
5. Set up staging-specific DynamoDB tables

## 📦 Size Comparison

- **Original Development:** ~5 GB
- **Clean Staging:** ~197 MB
- **Reduction:** 96% smaller

## 🛠️ Maintenance

This is a **clean copy** for staging. Do NOT add:
- Test files or debug screens
- Multiple versions of the same file
- Development documentation
- Deployment archives
- Temporary or backup files

For development and testing, use the original `whizzDrivers` directory.

---

**Created:** December 28, 2025
**Purpose:** Clean staging environment for WhizzDrivers application
**Source:** whizzDrivers (development directory)
