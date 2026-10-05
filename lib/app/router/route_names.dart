/// Central route path constants for go_router.
///
/// Full auth / shell / training routes are expanded in HIT-006 / feature issues.
abstract final class RouteNames {
  static const foundation = '/';
  static const splash = '/splash';
  static const onboarding = '/onboarding';

  static const auth = '/auth';
  static const login = '/auth/login';

  // Under login, so going to either keeps login under it for the back
  // button, and the router sees which one is showing (HIT-020).
  static const register = '/auth/login/register';
  static const forgotPassword = '/auth/login/forgot-password';

  static const app = '/app';
  static const home = '/app/home';
  static const training = '/app/training';
  static const practice = '/app/practice';
  static const progress = '/app/progress';
  static const profile = '/app/profile';

  static const settings = '/settings';
}
