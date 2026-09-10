import Flutter
import UIKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // audio_service configures the background AVAudioSession category during
    // plugin registration. It must be registered synchronously here (the
    // classic pattern) rather than via the newer deferred
    // FlutterImplicitEngineDelegate, or the background-audio entitlement
    // setup can miss its window and background playback silently fails.
    GeneratedPluginRegistrant.register(with: self)

    // NOTE: the external_link_account MethodChannel is NOT registered here.
    // This app uses the UIScene lifecycle, so the window and its
    // FlutterViewController belong to the scene and do not exist yet at this
    // point — registering against window?.rootViewController here hit nil and
    // was silently skipped (MissingPluginException on every call). The channel
    // now lives in SceneDelegate.scene(_:willConnectTo:), where the controller
    // is real.
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
