import SwiftRs
import Tauri
import UIKit
import WebKit

class PingArgs: Decodable {
  let value: String?
}

class ExamplePlugin: Plugin {
  @objc public func ping(_ invoke: Invoke) throws {
    if let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
      // iCloud Documents directory is available
        invoke.resolve(
            [
                "value": "iCloud is available and working, documentsURL: \(iCloudURL.absoluteString)"
            ]
        ) 
    } else {
      // iCloud is not available or not set up
        invoke.resolve(
            [
                "value": "iCloud is not available or not configured for this app"
            ]
        )
    }
  }
}

@_cdecl("init_plugin_icloud")
func initPlugin() -> Plugin {
  return ExamplePlugin()
}
