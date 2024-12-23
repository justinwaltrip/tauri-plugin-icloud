import SwiftRs
import Tauri
import UIKit
import WebKit

class ReadDirArgs: Decodable {
  let path: String
}

class iCloudPlugin: Plugin {
  private var documentPickerDelegate: DocumentPickerDelegate?

  @objc public func openFolder(_ invoke: Invoke) throws {
    NSLog("iCloudPlugin: Starting openFolder function")

    DispatchQueue.main.async {
      // Get the root view controller
      guard let rootViewController = UIApplication.shared.windows.first?.rootViewController else {
        NSLog("iCloudPlugin: Error - No root view controller found")
        invoke.reject("No root view controller found")
        return
      }
      NSLog("iCloudPlugin: Root view controller found")

      // Create document picker configuration
      let documentPicker = UIDocumentPickerViewController(
        documentTypes: ["public.folder"], in: .open)
      documentPicker.allowsMultipleSelection = false
      NSLog("iCloudPlugin: Document picker configured")

      // Set up document picker callback
      self.documentPickerDelegate = DocumentPickerDelegate { urls in
        NSLog("iCloudPlugin: Document picker callback received with \(urls.count) URLs")

        if let selectedURL = urls.first {
          NSLog("iCloudPlugin: Selected URL: \(selectedURL.absoluteString)")

          // Grant security-scoped resource access
          let securitySuccess = selectedURL.startAccessingSecurityScopedResource()
          NSLog("iCloudPlugin: Security access granted: \(securitySuccess)")

          defer {
            if securitySuccess {
              selectedURL.stopAccessingSecurityScopedResource()
              NSLog("iCloudPlugin: Security access stopped")
            }
          }

          // Return the selected folder path
          let result = [
            "path": selectedURL.path,
            "url": selectedURL.absoluteString,
          ]
          NSLog("iCloudPlugin: Resolving with path: \(selectedURL.path)")
          invoke.resolve(result)
        } else {
          NSLog("iCloudPlugin: Error - No folder selected")
          invoke.reject("No folder selected")
        }
      }

      // Present the document picker
      NSLog("iCloudPlugin: Presenting document picker")
      documentPicker.delegate = self.documentPickerDelegate
      rootViewController.present(documentPicker, animated: true)
    }
  }

  // Helper class to handle document picker delegate
  private class DocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
    private let completion: ([URL]) -> Void
    init(completion: @escaping ([URL]) -> Void) {
      self.completion = completion
      super.init()
      NSLog("DocumentPickerDelegate: Initialized")
    }
    func documentPicker(
      _ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]
    ) {
      NSLog("DocumentPickerDelegate: Documents picked: \(urls)")
      completion(urls)
    }
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
      NSLog("DocumentPickerDelegate: Picker was cancelled")
      completion([])
    }
  }

  @objc public func readDir(_ invoke: Invoke) throws {
    NSLog("iCloudPlugin: Starting readDir function")
    let args = try invoke.parseArgs(ReadDirArgs.self)
    let path = args.path
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        guard let url = URL(string: path) else {
          NSLog("iCloudPlugin: Invalid URL path")
          invoke.reject("Invalid URL path")
          return
        }

        let contents = try FileManager.default.contentsOfDirectory(
          at: url, includingPropertiesForKeys: nil, options: [])
        let contentNames = contents.map { $0.lastPathComponent }
        NSLog("iCloudPlugin: Directory contents: \(contentNames)")
        invoke.resolve(contentNames)
      } catch {
        NSLog("iCloudPlugin: Error reading directory: \(error)")
        invoke.reject("Error reading directory: \(error)")
      }
    }
  }
}

@_cdecl("init_plugin_icloud")
func initPlugin() -> Plugin {
  NSLog("iCloudPlugin: Initializing plugin")
  return iCloudPlugin()
}
