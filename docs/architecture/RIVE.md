# Rive

**STATUS: RUNTIME IN PLACE AND PROVEN TO RENDER (HIT-032).** The renderer that shows an exercise's animation is HIT-033 (#36).

The mouth, lip, tongue and jaw drills are Rive animations. This page is what the app does with a `.riv` file, and what an animation needs so the app can drive it.

## What is in the app

| | |
|---|---|
| Package | `rive` 0.14.11, declared in `pubspec.yaml` since the project foundation |
| Native runtime | `rive_native` 0.1.11, which `rive` depends on. Its prebuilt libraries are downloaded while the Android and iOS apps build |
| The door to it | `core/media/rive_runtime.dart`: `RiveRuntime`, `riveRuntimeProvider` |
| Where files live | `assets/rive/<key>.riv` (`R2_MEDIA.md`, `CONTENT_SCHEMA.md`); `assets/rive/` is already listed in `pubspec.yaml` |

## Starting the runtime

Nothing decodes or shows a `.riv` file until `riveRuntimeProvider`'s `ensureReady()` has answered true. False means Rive cannot run on this device; the screen shows its fallback.

**It asks once, and never again after a failure.** `RiveNative.init` keeps a completer of its own. When the native library cannot be loaded it throws, that completer is never completed, and every later call waits on it forever. `File.decode` and `File.asset` call `RiveNative.init` themselves, so after one failed start, opening any file would hang the screen that asked. Checked against `rive_native` 0.1.11: a second `init` after a failed first one had not returned after three seconds. `NativeRiveRuntime` keeps the first answer, keeps a throw as false, and does not ask again.

**On first use, not at start-up.** Most launches show no animation, and they should not pay for loading a native library they do not use.

## Opening a file

After `ensureReady()` is true, open the file with `File.asset('assets/rive/<key>.riv', riveFactory: ...)`.

**Nothing from Rive before that answer, not even a factory.** Reading `Factory.flutter` or `Factory.rive` already loads the native library, and throws where it cannot load. Checked with `rive` 0.14.11 on a machine without the library.

A file that imports both `package:flutter/foundation.dart` and `package:rive/rive.dart` gets two classes called `Factory`; import only what it needs from one of them.

**Not through `FileLoader`.** When loading fails, `FileLoader.file()` throws, and also fails a completer that nothing listens to. That second error surfaces as an unhandled one, next to the error the caller already handled, and a crash reporter records it as a crash. Seen with `rive` 0.14.11 on a missing asset.

## What goes wrong, and what the user reads

`mapErrorToFailure` turns Rive's errors into content failures, so a screen shows a sentence rather than a stack trace:

| What happened | Thrown | Failure code |
|---|---|---|
| `assets/rive/<key>.riv` is not in the app | `FlutterError` from the asset bundle, or `RiveFileLoaderException` wrapping it | `content.asset_missing` |
| The file would not decode | `RiveFileLoaderException` | `content.media_unavailable` |
| The artboard or state machine the content names is not in the file | `RiveArtboardException`, `RiveStateMachineException` | `content.media_unavailable` |

**A wrong state machine name throws while the controller is built.** `RiveWidgetController(file, stateMachineSelector: StateMachineSelector.byName(name))` throws `RiveStateMachineException` when the file has no state machine of that name. The renderer that builds one has to catch it.

## What an animation needs

For whoever makes the `.riv` files:

- **One file per media key**, named after the key: `ux_lips` is `assets/rive/ux_lips.riv`. The key is lower case letters, digits and `_` (`R2_MEDIA.md`).
- **The state machine is named in the content**, and the file must have one of exactly that name: `"media": {"kind": "rive", "key": "ux_lips", "stateMachine": "LipStates"}` needs a state machine called `LipStates`. The content has no field for the artboard, so the file's default artboard is the one shown.
- **Inputs are not decided yet.** Which inputs a drill's state machine takes, and what the app sets them to, is settled with the first real animation (#37, the U-X lip drill) and written here then.

The content already names two files that are not in `assets/rive/` yet: `ux_lips` (state machine `LipStates`) and `placeholder_sample` (`PlaceholderStates`). Until they arrive, loading them is the "not in the app" row above.

Not verified here: which versions of the Rive editor export files that `rive` 0.14.11 reads. Check it when the first real file is exported.

## Testing

`test/core/media/rive_runtime_test.dart` runs everywhere: the runtime asked once, a failure kept as false and not asked again, callers sharing one start, and the app having one runtime. `test/core/errors/failure_mapper_test.dart` holds the mapping of each Rive exception.

`test/core/media/rive_render_test.dart` decodes and draws a real file, `test/fixtures/rive/rocket.riv`, reports a missing file as a missing asset through the real asset bundle, and refuses a state machine the file lacks. It needs the native library for the machine running it. It is tagged `rive-native`, and `dart_test.yaml` skips that tag with its reason printed, so `flutter test` and CI report it as skipped rather than leave it out silently.

### Running the render test

```bash
dart run rive_native:setup --verbose --clean --platform windows   # or macos, linux
flutter test --run-skipped --tags rive-native
```

The setup puts the library under `build/rive_native/`, which git ignores.

**On Windows without Visual Studio**, the debug library the test looks for needs Visual Studio's debug C runtime (`MSVCP140D.dll`, `VCRUNTIME140D.dll`, `ucrtbased.dll`) and fails to load with error 126. The release library needs only what Windows already has. Copying `build/rive_native/native/build/windows/bin/lib/release/rive_native.dll` over the one in `.../lib/debug/` lets it load; that folder is under `build/` and never committed.

**CI does not run it.** CI would need the setup step above in `flutter_ci.yml`, a change for the code owners. CI's Android and iOS build jobs already pass with `rive` among the dependencies.
