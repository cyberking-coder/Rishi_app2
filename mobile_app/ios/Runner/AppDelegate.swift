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
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
