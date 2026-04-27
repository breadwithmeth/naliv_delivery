import UIKit
import Flutter
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Инициализация Firebase
    FirebaseApp.configure()
    
    GeneratedPluginRegistrant.register(with: self)

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    application.registerForRemoteNotifications()
    
    // Настройка Firebase Messaging
    Messaging.messaging().delegate = self

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // MARK: - Remote Notifications
  override func application(_ application: UIApplication,
                   didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
  
  // MARK: - UNUserNotificationCenterDelegate
  @available(iOS 10, *)
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([])
  }

  @available(iOS 10, *)
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
    let userInfo = response.notification.request.content.userInfo
    
    // Здесь можно добавить логику обработки нажатий
    print("Notification tapped with userInfo: \(userInfo)")
    
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
  // Обновление FCM токена
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("Firebase registration token: \(String(describing: fcmToken))")
    
    let dataDict: [String: String] = ["token": fcmToken ?? ""]
    NotificationCenter.default.post(
      name: Notification.Name("FCMToken"),
      object: nil,
      userInfo: dataDict
    )
  }
}

func registerPlugins(registry: FlutterPluginRegistry) {
  GeneratedPluginRegistrant.register(with: registry)
}
