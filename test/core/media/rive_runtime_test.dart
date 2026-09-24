import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitup/core/media/rive_runtime.dart';

void main() {
  group('starting the runtime', () {
    test('answers what the runtime says', () async {
      expect(
        await NativeRiveRuntime(init: () async => true).ensureReady(),
        isTrue,
      );
      expect(
        await NativeRiveRuntime(init: () async => false).ensureReady(),
        isFalse,
      );
    });

    test('asks once, however often it is asked', () async {
      int calls = 0;
      final NativeRiveRuntime runtime = NativeRiveRuntime(
        init: () async {
          calls++;
          return true;
        },
      );

      await runtime.ensureReady();
      await runtime.ensureReady();
      await runtime.ensureReady();

      expect(calls, 1);
    });

    test('callers that arrive while it starts share the one start', () async {
      int calls = 0;
      final Completer<bool> answer = Completer<bool>();
      final NativeRiveRuntime runtime = NativeRiveRuntime(
        init: () {
          calls++;
          return answer.future;
        },
      );

      final Future<bool> first = runtime.ensureReady();
      final Future<bool> second = runtime.ensureReady();
      answer.complete(true);

      expect(await first, isTrue);
      expect(await second, isTrue);
      expect(calls, 1);
    });

    test(
        'a runtime that throws is answered as not running, and never asked '
        'again', () async {
      // What a missing native library does: an ArgumentError, an Error and
      // not an Exception, from loading the library. Asking RiveNative.init a
      // second time after that waits forever.
      int calls = 0;
      final NativeRiveRuntime runtime = NativeRiveRuntime(
        init: () async {
          calls++;
          throw ArgumentError('Failed to load dynamic library');
        },
      );

      expect(await runtime.ensureReady(), isFalse);
      expect(await runtime.ensureReady(), isFalse);
      expect(calls, 1);
    });

    test('the app has one runtime', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        identical(
          container.read(riveRuntimeProvider),
          container.read(riveRuntimeProvider),
        ),
        isTrue,
      );
      expect(container.read(riveRuntimeProvider), isA<NativeRiveRuntime>());
    });
  });
}
