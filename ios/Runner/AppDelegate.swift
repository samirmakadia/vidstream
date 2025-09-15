import UIKit
import Flutter
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    FirebaseApp.configure()

    if #available(iOS 10.0, *) {
        UNUserNotificationCenter.current().delegate = self

        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
            print("✅ iOS Notification permission granted: \(granted)")
        }
    }

    application.registerForRemoteNotifications()

    Messaging.messaging().delegate = self

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Called when APNs has assigned the device a unique token
  override func application(_ application: UIApplication,
                            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
      Messaging.messaging().apnsToken = deviceToken
      print("✅ APNs device token set for Firebase Messaging")
  }

  // Optional: handle errors
  override func application(_ application: UIApplication,
                            didFailToRegisterForRemoteNotificationsWithError error: Error) {
      print("❌ Failed to register for remote notifications: \(error)")
  }

  // Ensure notifications are displayed while app is in foreground on iOS
  // This complements the Dart-side setForegroundNotificationPresentationOptions.
  @available(iOS 10.0, *)
  override public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                     willPresent notification: UNNotification,
                                     withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
      completionHandler([.alert, .badge, .sound])
  }

  // Firebase Messaging callback for FCM token refresh on iOS
  public func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
      print("✅ FCM registration token: \(String(describing: fcmToken))")
      // If needed, forward token to Flutter via NotificationCenter or method channel.
  }
}
