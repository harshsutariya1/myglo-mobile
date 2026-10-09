import EventKit
import EventKitUI
import Flutter
import GoogleMaps
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // The key comes from Info.plist (GMSApiKey), which Secrets.xcconfig fills
    // in. Without one the app shows a "map unavailable" placeholder rather
    // than creating a map (see SystemBridgePlugin.mapsAvailable).
    if let key = AppDelegate.mapsApiKey {
      GMSServices.provideAPIKey(key)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CalendarBridgePlugin") {
      CalendarBridgePlugin.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SystemBridgePlugin") {
      SystemBridgePlugin.register(with: registrar)
    }
  }

  static var mapsApiKey: String? {
    guard let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String else { return nil }
    let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty || trimmed.hasPrefix("$(") ? nil : trimmed
  }
}

/// App-level system queries and shortcuts (channel `app.myglo/system`).
final class SystemBridgePlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "app.myglo/system", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(SystemBridgePlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "mapsAvailable":
      result(AppDelegate.mapsApiKey != nil)
    case "notificationsEnabled":
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        let enabled = [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus)
        DispatchQueue.main.async { result(enabled) }
      }
    case "openNotificationSettings":
      let target: String
      if #available(iOS 16.0, *) {
        target = UIApplication.openNotificationSettingsURLString
      } else {
        target = UIApplication.openSettingsURLString
      }
      guard let url = URL(string: target) else {
        result(false)
        return
      }
      UIApplication.shared.open(url) { opened in result(opened) }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

/// Presents Apple's own "New Event" sheet pre-filled with a booking, so the
/// user reviews and saves it themselves (channel `app.myglo/calendar`).
///
/// From iOS 17 the sheet runs out of process and needs no calendar
/// permission. Earlier versions require calendar access first
/// (NSCalendarsUsageDescription).
final class CalendarBridgePlugin: NSObject, FlutterPlugin, EKEventEditViewDelegate {
  private let eventStore = EKEventStore()
  private var pendingResult: FlutterResult?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "app.myglo/calendar", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(CalendarBridgePlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "addEvent" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard
      let args = call.arguments as? [String: Any],
      let title = args["title"] as? String,
      let startMillis = args["startMillis"] as? NSNumber,
      let endMillis = args["endMillis"] as? NSNumber
    else {
      result(FlutterError(code: "invalid_arguments", message: "title, startMillis and endMillis are required", details: nil))
      return
    }
    guard pendingResult == nil else {
      result(FlutterError(code: "busy", message: "The calendar sheet is already open", details: nil))
      return
    }

    let present = { [weak self] in
      self?.presentEditor(
        title: title,
        start: Date(timeIntervalSince1970: startMillis.doubleValue / 1000),
        end: Date(timeIntervalSince1970: endMillis.doubleValue / 1000),
        location: args["location"] as? String,
        notes: args["notes"] as? String,
        timeZone: (args["timeZone"] as? String).flatMap(TimeZone.init(identifier:)),
        result: result
      )
    }

    if #available(iOS 17.0, *) {
      present()
    } else {
      eventStore.requestAccess(to: .event) { granted, _ in
        DispatchQueue.main.async {
          if granted {
            present()
          } else {
            result("denied")
          }
        }
      }
    }
  }

  private func presentEditor(
    title: String,
    start: Date,
    end: Date,
    location: String?,
    notes: String?,
    timeZone: TimeZone?,
    result: @escaping FlutterResult
  ) {
    guard let presenter = topViewController() else {
      result(FlutterError(code: "unavailable", message: "Nothing to present the calendar from", details: nil))
      return
    }

    let event = EKEvent(eventStore: eventStore)
    event.title = title
    event.startDate = start
    event.endDate = end
    event.location = location
    event.notes = notes
    event.timeZone = timeZone
    if #unavailable(iOS 17.0) {
      event.calendar = eventStore.defaultCalendarForNewEvents
    }

    let editor = EKEventEditViewController()
    editor.eventStore = eventStore
    editor.event = event
    editor.editViewDelegate = self
    pendingResult = result
    presenter.present(editor, animated: true)
  }

  func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
    controller.dismiss(animated: true)
    pendingResult?(action == .saved ? "saved" : "cancelled")
    pendingResult = nil
  }

  private func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.first?.windows.first
    var top = window?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }
}
