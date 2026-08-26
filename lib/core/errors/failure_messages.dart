import 'package:hitup/core/errors/failure.dart';
import 'package:hitup/core/errors/failure_code.dart';

/// **The only file in the app that holds user facing error copy.**
///
/// Everything under `errors/` above this file deals in [FailureCode] values.
/// Copy lives here so a wording change is one edit in one place, and so that
/// adding real localisation later replaces this table without touching the
/// mapper or any screen.
///
/// The table is deliberately compiled into the app rather than loaded from
/// `assets/`. Error copy is what gets shown when loading fails, so it cannot
/// itself depend on loading succeeding.
const failureMessagesTr = <String, String>{
  // Also shown for an unregistered email, on purpose, see failure_mapper.dart.
  FailureCode.authInvalidCredentials:
      'E-posta veya şifre hatalı. Kontrol edip tekrar dener misiniz?',
  FailureCode.authUserDisabled: 'Bu hesap kullanıma kapatılmış.',
  FailureCode.authEmailInUse:
      'Bu e-posta zaten kayıtlı. Giriş yapmayı deneyebilirsiniz.',
  FailureCode.authInvalidEmail: 'E-posta adresi geçerli görünmüyor.',
  FailureCode.authWeakPassword:
      'Şifre çok zayıf. Daha uzun ve karışık bir şifre seçin.',
  FailureCode.authTooManyRequests:
      'Çok fazla deneme yapıldı. Biraz bekleyip tekrar deneyin.',
  FailureCode.authRequiresRecentLogin:
      'Güvenlik için tekrar giriş yapmanız gerekiyor.',
  FailureCode.authUnknown:
      'Giriş sırasında bir sorun oldu. Tekrar dener misiniz?',
  FailureCode.networkOffline:
      'İnternet bağlantısı görünmüyor. Bağlantınızı kontrol edin.',
  FailureCode.networkTimeout: 'Bağlantı zaman aşımına uğradı. Tekrar deneyin.',
  FailureCode.networkUnavailable:
      'Sunucuya şu an ulaşılamıyor. Birazdan tekrar deneyin.',
  FailureCode.permissionDenied: 'Bu işlem için yetkiniz yok.',
  FailureCode.contentAssetMissing:
      'Egzersiz içeriği bulunamadı. Uygulamayı güncellemeyi deneyin.',
  FailureCode.contentMalformed:
      'Egzersiz içeriği okunamadı. Uygulamayı güncellemeyi deneyin.',
  FailureCode.contentMediaUnavailable: 'Bu egzersizin görseli açılamadı.',
  FailureCode.dataNotFound: 'Aradığınız kayıt bulunamadı.',
  FailureCode.dataConflict:
      'Bu kayıt başka bir yerden değişmiş. Sayfayı yenileyin.',
  FailureCode.dataUnknown: 'Bilgileriniz kaydedilirken bir sorun oldu.',
  FailureCode.unknown: 'Beklenmedik bir sorun oldu. Tekrar dener misiniz?',
};

/// Labels for the error surfaces themselves.
abstract final class FailureLabelsTr {
  const FailureLabelsTr._();

  static const dialogTitle = 'Bir sorun oldu';
  static const dismiss = 'Tamam';
  static const retry = 'Tekrar dene';
}

/// The sentence to show for [failure].
///
/// Falls back to the generic message rather than returning null or leaking
/// [Failure.technicalDetail], so a code added without copy still produces
/// something safe on screen. The message table test prevents that gap from
/// reaching a release.
String failureMessage(Failure failure) =>
    failureMessagesTr[failure.code] ?? failureMessagesTr[FailureCode.unknown]!;
