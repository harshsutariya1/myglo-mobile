class AppConfig {
  static const String emailConfirmationRedirectUrl = String.fromEnvironment(
    'EMAIL_CONFIRM_REDIRECT_URL',
    defaultValue: 'https://www.myglo.app/welcome',
  );
}
