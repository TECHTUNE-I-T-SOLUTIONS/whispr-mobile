import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    let screenshotChannel = FlutterMethodChannel(
      name: "com.whispr.whisprmobile/screenshot",
      binaryMessenger: controller.binaryMessenger
    )
    
    screenshotChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "disableScreenshot":
        self?.disableScreenshot()
        result(nil)
      case "enableScreenshot":
        self?.enableScreenshot()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
  
  private func disableScreenshot() {
    DispatchQueue.main.async {
      if let window = UIApplication.shared.connectedScenes.first as? UIWindowScene {
        window.windows.forEach { window in
          let screenshotProtectionView = UIView()
          screenshotProtectionView.backgroundColor = .clear
          screenshotProtectionView.tag = 999
          
          window.addSubview(screenshotProtectionView)
          screenshotProtectionView.frame = window.bounds
          screenshotProtectionView.translatesAutoresizingMaskIntoConstraints = false
          
          // Constrain to window bounds
          NSLayoutConstraint.activate([
            screenshotProtectionView.topAnchor.constraint(equalTo: window.topAnchor),
            screenshotProtectionView.leadingAnchor.constraint(equalTo: window.leadingAnchor),
            screenshotProtectionView.trailingAnchor.constraint(equalTo: window.trailingAnchor),
            screenshotProtectionView.bottomAnchor.constraint(equalTo: window.bottomAnchor)
          ])
        }
      }
    }
  }
  
  private func enableScreenshot() {
    DispatchQueue.main.async {
      if let window = UIApplication.shared.connectedScenes.first as? UIWindowScene {
        window.windows.forEach { window in
          window.viewWithTag(999)?.removeFromSuperview()
        }
      }
    }
  }
}
