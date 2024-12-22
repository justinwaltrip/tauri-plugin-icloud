import SwiftRs
import Tauri
import UIKit
import WebKit

class iCloudPlugin: Plugin {

  @objc public func openFolder(_ invoke: Invoke) throws {
    DispatchQueue.main.async {
      // Get the root view controller
      guard let rootViewController = UIApplication.shared.windows.first?.rootViewController else {
        invoke.reject("No root view controller found")
        return
      }

      // Create document picker configuration
      let documentPicker = UIDocumentPickerViewController(
        documentTypes: ["public.folder"], in: .open)
      documentPicker.allowsMultipleSelection = false

      // Set up document picker callback
      documentPicker.delegate = DocumentPickerDelegate { urls in
        if let selectedURL = urls.first {
          // Grant security-scoped resource access
          let securitySuccess = selectedURL.startAccessingSecurityScopedResource()
          defer {
            if securitySuccess {
              selectedURL.stopAccessingSecurityScopedResource()
            }
          }

          // Return the selected folder path
          invoke.resolve([
            "path": selectedURL.path,
            "url": selectedURL.absoluteString,
          ])
        } else {
          invoke.reject("No folder selected")
        }
      }

      // Present the document picker
      rootViewController.present(documentPicker, animated: true)
    }
  }

  // Helper class to handle document picker delegate
  private class DocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
    private let completion: ([URL]) -> Void

    init(completion: @escaping ([URL]) -> Void) {
      self.completion = completion
      super.init()
    }

    func documentPicker(
      _ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]
    ) {
      completion(urls)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
      completion([])
    }
  }
}

@_cdecl("init_plugin_icloud")
func initPlugin() -> Plugin {
  return iCloudPlugin()
}
