/// Central route path constants for go_router.
///
/// Full auth / shell / training routes are expanded in HIT-006 / feature issues.
abstract final class RouteNames {
  static const foundation = '/';
  static const splash = '/splash';
  static const onboarding = '/onboarding';

  static const auth = '/auth';
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const forgotPassword = '/auth/forgot-password';

  static const app = '/app';
  static const home = '/app/home';
  static const training = '/app/training';
  static const practice = '/app/practice';
  static const progress = '/app/progress';
  static const profile = '/app/profile';

  static const settings = '/settings';
}
