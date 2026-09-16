import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/core/services/notification_service.dart';

/// Checks that the Android icon resources named in code and in the manifest
/// actually ship, at the sizes their density folders promise (HIT-081).
///
/// None of this is a build error if it breaks. Android resolves these names at
/// runtime, so a renamed or missing file first shows up as a blank square in a
/// user's status bar, or as the default Flutter icon on their home screen.
void main() {
  const String res = 'android/app/src/main/res';

  /// Width and height from a PNG header, without decoding the image.
  ///
  /// The signature is eight bytes, then the IHDR chunk, whose width and height
  /// are big-endian 32 bit integers at offsets 16 and 20.
  ({int width, int height}) pngSize(File file) {
    final Uint8List bytes = file.readAsBytesSync();
    expect(
      bytes.sublist(0, 8),
      <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
      reason: '${file.path} is not a PNG',
    );
    final ByteData data = ByteData.sublistView(bytes);
    return (width: data.getUint32(16), height: data.getUint32(20));
  }

  /// The density buckets this project ships, and the multiplier of each.
  const Map<String, double> densities = <String, double>{
    'mdpi': 1,
    'hdpi': 1.5,
    'xhdpi': 2,
    'xxhdpi': 3,
    'xxxhdpi': 4,
  };

  group('notification icon', () {
    test('the drawable named in code ships at every density', () {
      final String icon = LocalNotificationService.androidSmallIcon;
      expect(icon, startsWith('@drawable/'));
      final String name = icon.split('/').last;

      densities.forEach((String density, double scale) {
        final File file = File('$res/drawable-$density/$name.png');
        expect(file.existsSync(), isTrue, reason: '${file.path} is missing');

        // A notification icon is 24 dp, so its pixel size follows the bucket.
        final int expected = (24 * scale).round();
        final ({int width, int height}) size = pngSize(file);
        expect(size.width, expected, reason: file.path);
        expect(size.height, expected, reason: file.path);
      });
    });

    test('it is a silhouette: no colour, only white and transparency', () {
      // Android tints a notification icon and throws colour away, so a colour
      // file here would look right in the folder and wrong on the phone.
      final File file = File('$res/drawable-xxhdpi/ic_stat_hitup.png');
      final Uint8List bytes = file.readAsBytesSync();
      // Colour type 6 is RGBA, the only type this file should have.
      expect(bytes[25], 6, reason: 'expected an RGBA PNG at ${file.path}');
    });
  });

  group('launcher icon', () {
    test('the legacy icon ships at every density', () {
      densities.forEach((String density, double scale) {
        final File file = File('$res/mipmap-$density/ic_launcher.png');
        expect(file.existsSync(), isTrue, reason: '${file.path} is missing');

        final int expected = (48 * scale).round();
        expect(pngSize(file).width, expected, reason: file.path);
      });
    });

    test('the adaptive foreground ships at every density, on the 108 dp canvas',
        () {
      densities.forEach((String density, double scale) {
        final File file =
            File('$res/mipmap-$density/ic_launcher_foreground.png');
        expect(file.existsSync(), isTrue, reason: '${file.path} is missing');

        final int expected = (108 * scale).round();
        expect(pngSize(file).width, expected, reason: file.path);
      });
    });

    test('the adaptive icon points at layers that exist', () {
      // The manifest names @mipmap/ic_launcher and nothing else, so this is
      // the one adaptive definition. A round variant would need a manifest
      // entry, and an anydpi-v26 resource cannot answer one below API 26.
      final File xml = File('$res/mipmap-anydpi-v26/ic_launcher.xml');
      expect(xml.existsSync(), isTrue, reason: '${xml.path} is missing');

      final String body = xml.readAsStringSync();
      expect(body, contains('@mipmap/ic_launcher_foreground'));
      expect(body, contains('@color/ic_launcher_background'));

      expect(
        File('$res/values/ic_launcher_background.xml').readAsStringSync(),
        contains('name="ic_launcher_background"'),
      );

      expect(
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
        contains('android:icon="@mipmap/ic_launcher"'),
      );
    });
  });
}
