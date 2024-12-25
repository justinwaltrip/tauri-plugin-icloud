import SwiftRs
import Tauri
import UIKit
import WebKit

class ReadDirArgs: Decodable {
  let path: String
}

class ReadTextFileArgs: Decodable {
  let path: String
}

class iCloudPlugin: Plugin {
  private var documentPickerDelegate: DocumentPickerDelegate?
  private let bookmarkKey = "FolderBookmark"

  // Add a method to save bookmark data
  private func saveSecurityScopedBookmark(for url: URL) throws -> String {
    let bookmarkData = try url.bookmarkData(
      options: .minimalBookmark,
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    )
    // Save bookmark data to UserDefaults
    UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
    return url.absoluteString
  }

  private func resolveSecurityScopedBookmark() -> URL? {
    guard let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) else {
      NSLog("iCloudPlugin: No bookmark data found")
      return nil
    }

    var isStale = false
    do {
      let url = try URL(
        resolvingBookmarkData: bookmarkData,
        options: [],
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
      )

      if isStale {
        NSLog("iCloudPlugin: Bookmark is stale, attempting to refresh")
        if url.startAccessingSecurityScopedResource() {
          defer { url.stopAccessingSecurityScopedResource() }
          _ = try? saveSecurityScopedBookmark(for: url)
        }
      }

      return url
    } catch {
      NSLog("iCloudPlugin: Error resolving bookmark: \(error)")
      return nil
    }
  }

  @objc public func openFolder(_ invoke: Invoke) throws {
    NSLog("iCloudPlugin: Starting openFolder function")
    DispatchQueue.main.async {
      guard let rootViewController = UIApplication.shared.windows.first?.rootViewController else {
        NSLog("iCloudPlugin: Error - No root view controller found")
        invoke.reject("No root view controller found")
        return
      }

      let documentPicker = UIDocumentPickerViewController(
        documentTypes: ["public.folder"], in: .open)
      documentPicker.allowsMultipleSelection = false

      self.documentPickerDelegate = DocumentPickerDelegate { urls in
        if let selectedURL = urls.first {
          // Start accessing the security-scoped resource immediately
          let accessGranted = selectedURL.startAccessingSecurityScopedResource()
          defer {
            if accessGranted {
              selectedURL.stopAccessingSecurityScopedResource()
            }
          }

          do {
            // Verify the URL is reachable
            let reachable = try selectedURL.checkResourceIsReachable()
            guard reachable else {
              throw NSError(
                domain: "iCloudPlugin", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Selected folder is not reachable"])
            }

            // Create bookmark with additional options
            let bookmarkData = try selectedURL.bookmarkData(
              options: [],
              includingResourceValuesForKeys: nil,
              relativeTo: nil
            )

            // Save bookmark data
            UserDefaults.standard.set(bookmarkData, forKey: self.bookmarkKey)

            let result = [
              "path": selectedURL.path,
              "url": selectedURL.absoluteString,
            ]

            NSLog("iCloudPlugin: Successfully created bookmark for \(selectedURL.path)")
            invoke.resolve(result)

          } catch {
            NSLog("iCloudPlugin: Error handling folder access: \(error)")
            invoke.reject("Error handling folder access: \(error.localizedDescription)")
          }
        } else {
          invoke.reject("No folder selected")
        }
      }

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
      guard let url = URL(string: path) else {
        invoke.reject("Invalid URL path")
        return
      }

      // Try to get security-scoped access
      guard let bookmarkURL = self.resolveSecurityScopedBookmark() else {
        invoke.reject("Could not resolve security-scoped bookmark")
        return
      }

      let granted = bookmarkURL.startAccessingSecurityScopedResource()
      defer {
        if granted {
          bookmarkURL.stopAccessingSecurityScopedResource()
        }
      }

      do {
        let contents = try FileManager.default.contentsOfDirectory(
          at: url,
          includingPropertiesForKeys: nil,
          options: []
        )

        let entries = contents.map { fileURL -> [String: String] in
          return ["name": fileURL.lastPathComponent]
        }

        let response: [String: Any] = ["entries": entries]
        invoke.resolve(response)
      } catch {
        invoke.reject("Error reading directory: \(error.localizedDescription)")
      }
    }
  }

  @objc public func readTextFile(_ invoke: Invoke) throws {
    NSLog("iCloudPlugin: Starting readTextFile function")
    let args = try invoke.parseArgs(ReadTextFileArgs.self)
    let path = args.path

    DispatchQueue.global(qos: .userInitiated).async {
      guard let url = URL(string: path) else {
        invoke.reject("Invalid URL path")
        return
      }

      // Try to get security-scoped access
      guard let bookmarkURL = self.resolveSecurityScopedBookmark() else {
        invoke.reject("Could not resolve security-scoped bookmark")
        return
      }

      let granted = bookmarkURL.startAccessingSecurityScopedResource()
      defer {
        if granted {
          bookmarkURL.stopAccessingSecurityScopedResource()
        }
      }

      do {
        let text = try String(contentsOf: url)
        let response: [String: Any] = ["text": text]
        invoke.resolve(response)
      } catch {
        invoke.reject("Error reading text file: \(error.localizedDescription)")
      }
    }
  }
}

@_cdecl("init_plugin_icloud")
func initPlugin() -> Plugin {
  NSLog("iCloudPlugin: Initializing plugin")
  return iCloudPlugin()
}
