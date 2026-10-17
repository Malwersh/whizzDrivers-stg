/// A transport failure cannot prove that Cognito removed the account.
/// Keep persisted credentials for recovery, while leaving the session inactive.
bool definitiveSessionRejection(String errorType) => const {
  'UserNotFoundException',
  'NotAuthorizedException',
  'NotAuthorizedServiceException',
  'SignedOutException',
  'SessionExpiredException',
}.contains(errorType);
