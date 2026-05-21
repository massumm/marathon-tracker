import Flutter
import UIKit

/// Subclass of FlutterSceneDelegate that intercepts custom URL-scheme deep links
/// and forwards them to Dart via the app/deep_link EventChannel.
class SceneDelegate: FlutterSceneDelegate {

  // Called when the app is already running and opened via a URL
  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    super.scene(scene, openURLContexts: URLContexts)
    guard let url = URLContexts.first?.url,
          url.scheme == "marathon-map" else { return }
    AppDelegate.shared?.sendDeepLink(url.absoluteString)
  }

  // Called at cold-start when the app is launched from a URL
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    // Capture URL before Flutter engine is ready; AppDelegate reads it later.
    if let url = connectionOptions.urlContexts.first?.url,
       url.scheme == "marathon-map" {
      AppDelegate.shared?.pendingDeepLink = url.absoluteString
    }
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }
}
