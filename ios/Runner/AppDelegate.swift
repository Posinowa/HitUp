import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // HIT-057. Without this, iOS delivers a notification tap to the system
    // default handler instead of the app, so flutter_local_notifications never
    // reports which notification was tapped and the callback that routes the
    // user into today's training never fires. FlutterAppDelegate already
    // conforms to UNUserNotificationCenterDelegate, so this only points the
    // notification centre at it.
    UNUserNotificationCenter.current().delegate = self

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
