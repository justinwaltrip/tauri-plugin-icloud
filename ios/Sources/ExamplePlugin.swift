import SwiftRs
import Tauri
import UIKit
import WebKit

class PingArgs: Decodable {
  let value: String?
}

class ExamplePlugin: Plugin {
  @objc public func ping(_ invoke: Invoke) throws {
    let args = try invoke.parseArgs(PingArgs.self)
    invoke.resolve(["value": args.value ?? ""])
  }
  @objc public func isICloudAvailable(_ invoke: Invoke) {
    if let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
      // iCloud Documents directory is available
      invoke.resolve([
        "available": true,
        "message": "iCloud is available and working",
        "documentsURL": iCloudURL.absoluteString
      ])
    } else {
      // iCloud is not available or not set up
      invoke.resolve([
        "available": false,
        "message": "iCloud is not available or not configured for this app"
      ])
    }
  }
}

@_cdecl("init_plugin_tauri_plugin_icloud")
func initPlugin() -> Plugin {
  return ExamplePlugin()
}
