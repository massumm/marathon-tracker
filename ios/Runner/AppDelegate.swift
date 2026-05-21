import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  /// Shared reference so SceneDelegate can forward deep links here.
  static weak var shared: AppDelegate?

  /// Set by SceneDelegate at cold-start before channels are ready.
  var pendingDeepLink: String?

  private var linkSink: FlutterEventSink?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    AppDelegate.shared = self
    GMSServices.provideAPIKey("AIzaSyC8-H020Uul_SNcekGeVnr0uESLg713rEA")
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()

    // One-shot: returns the link that cold-started the app (consumed once read)
    FlutterMethodChannel(name: "app/deep_link", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        guard call.method == "getInitialLink" else {
          result(FlutterMethodNotImplemented)
          return
        }
        result(self?.pendingDeepLink)
        self?.pendingDeepLink = nil
      }

    // Stream: forwards links that arrive while the app is already running
    FlutterEventChannel(name: "app/deep_link/events", binaryMessenger: messenger)
      .setStreamHandler(self)
  }

  /// Called by SceneDelegate when a warm-start URL arrives.
  func sendDeepLink(_ link: String) {
    linkSink?(link)
  }
}

extension AppDelegate: FlutterStreamHandler {
  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    linkSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    linkSink = nil
    return nil
  }
}
