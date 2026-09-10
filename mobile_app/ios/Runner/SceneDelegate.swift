import Flutter
import UIKit
import StoreKit

class SceneDelegate: FlutterSceneDelegate {

  // External Link Account API bridge. App Review (Guideline 3.1.1) requires
  // that linking out for account creation/management goes through StoreKit's
  // ExternalLinkAccount.open(), which presents Apple's OWN disclosure sheet
  // and then opens the URL declared in Info.plist's SKExternalLinkAccount.
  // A self-drawn dialog + url_launcher (what shipped before) does NOT satisfy
  // the entitlement and was rejected. The Dart side calls this channel
  // instead; there is no URL argument because the system reads it from
  // Info.plist.
  //
  // This MUST live in the SceneDelegate, not the AppDelegate. The app uses
  // the UIScene lifecycle (UIApplicationSceneManifest in Info.plist +
  // FlutterSceneDelegate), so the window and its FlutterViewController are
  // owned by the scene and do not exist yet when
  // AppDelegate.didFinishLaunchingWithOptions runs — window?.rootViewController
  // is nil there, the channel registration was silently skipped, and every
  // call failed with MissingPluginException ("No implementation found for
  // method canOpen on channel external_link_account"). By the time
  // scene(_:willConnectTo:) returns, the FlutterViewController is real.
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    guard let controller = window?.rootViewController as? FlutterViewController
    else { return }

    let channel = FlutterMethodChannel(
      name: "external_link_account",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      // Everything runs on @MainActor. StoreKit presents the sheet on the UI
      // thread, and Flutter requires result() to be called on the main thread
      // too. Calling result() from a plain (background) Task meant the Dart
      // side never heard back, so the tap did nothing — no sheet, no error.
      switch call.method {
      case "canOpen":
        if #available(iOS 16.0, *) {
          Task { @MainActor in
            let can = await ExternalLinkAccount.canOpen
            result(can)
          }
        } else {
          result(false)
        }
      case "open":
        if #available(iOS 16.0, *) {
          Task { @MainActor in
            do {
              try await ExternalLinkAccount.open()
              result(true)
            } catch {
              // Full error, not just localizedDescription — the StoreKit
              // error type is what tells us WHY open() failed (bad URL,
              // ineligible, cancelled, …).
              result(
                FlutterError(
                  code: "open_failed",
                  message: "\(error)",
                  details: nil
                )
              )
            }
          }
        } else {
          result(
            FlutterError(
              code: "unavailable",
              message: "Requires iOS 16 or later",
              details: nil
            )
          )
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
