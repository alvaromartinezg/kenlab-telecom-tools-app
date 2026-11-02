class AppConfig {
  const AppConfig._();

  /// Set at build time after the API domain is provided:
  /// --dart-define=MW_PROFILE_API_BASE_URL=https://api.example.com
  static const mwProfileApiBaseUrl =
      String.fromEnvironment('MW_PROFILE_API_BASE_URL');

  /// The API path can also be overridden if the existing service uses another
  /// route: --dart-define=MW_PROFILE_API_PATH=/your/profile/route
  static const mwProfileApiPath = String.fromEnvironment(
    'MW_PROFILE_API_PATH',
    defaultValue: '/api/v1/line-of-sight/profile',
  );
}
