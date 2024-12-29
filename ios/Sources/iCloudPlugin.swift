import Foundation
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

class ReadImageFileArgs: Decodable {
  let path: String
}

class WriteTextFileArgs: Decodable {
  let path: String
  let content: String
}

class ExistsArgs: Decodable {
  let path: String
}

class CreateFolderArgs: Decodable {
  let path: String
}

class RenameArgs: Decodable {
  let old: String
  let new: String
}

class iCloudPlugin: Plugin {
  private var documentPickerDelegate: DocumentPickerDelegate?
  private let bookmarkKey = "FolderBookmark"

  // #region helper functions
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

  // #endregion

  // #region helper classes
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
  // #endregion

  // #region plugin functions
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
      // Use fileURLWithPath instead of URL(string:)
      let url = URL(fileURLWithPath: path)

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
        // Add some debugging information
        NSLog("iCloudPlugin: Attempting to read file at path: \(url.path)")

        // Check if file exists and is readable
        guard FileManager.default.fileExists(atPath: url.path) else {
          invoke.reject("File does not exist at path: \(url.path)")
          return
        }

        // Try to read the file
        let text = try String(contentsOf: url, encoding: .utf8)
        let response: [String: Any] = ["content": text]
        invoke.resolve(response)

      } catch {
        NSLog("iCloudPlugin: Error reading file: \(error)")
        invoke.reject("Error reading text file: \(error.localizedDescription)")
      }
    }
  }

  @objc public func readImageFile(_ invoke: Invoke) throws {
    NSLog("iCloudPlugin: Starting readImageFile function")
    let args = try invoke.parseArgs(ReadImageFileArgs.self)
    let path = args.path

    DispatchQueue.global(qos: .userInitiated).async {
      let url = URL(fileURLWithPath: path)

      // Resolve security-scoped bookmark
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
        // Ensure file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
          invoke.reject("Image file does not exist at path: \(url.path)")
          return
        }

        // Load image data
        let imageData = try Data(contentsOf: url)

        // Convert to a Base64 string
        let base64String = imageData.base64EncodedString()

        // Respond with the base64 encoded image
        let response = [
          "content": base64String
        ]
        invoke.resolve(response)
      } catch {
        NSLog("iCloudPlugin: Error reading image file: \(error)")
        invoke.reject("Error reading image file: \(error.localizedDescription)")
      }
    }
  }

  @objc public func writeTextFile(_ invoke: Invoke) throws {
    NSLog("iCloudPlugin: Starting writeTextFile function")
    let args = try invoke.parseArgs(WriteTextFileArgs.self)
    let path = args.path
    let content = args.content

    DispatchQueue.global(qos: .userInitiated).async {
      let url = URL(fileURLWithPath: path)

      // Resolve security-scoped bookmark
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
        // Create intermediate directories if they don't exist
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(
          at: directory,
          withIntermediateDirectories: true)

        // Write the content to file
        try content.write(to: url, atomically: true, encoding: .utf8)

        // Return success response
        let response = [
          "success": true,
          "path": url.path,
        ]
        invoke.resolve(response)

        NSLog("iCloudPlugin: Successfully wrote file to \(url.path)")

      } catch {
        NSLog("iCloudPlugin: Error writing file: \(error)")
        invoke.reject("Error writing text file: \(error.localizedDescription)")
      }
    }
  }

  @objc public func exists(_ invoke: Invoke) throws {
    NSLog("iCloudPlugin: Starting exists function")
    let args = try invoke.parseArgs(ExistsArgs.self)
    let path = args.path

    DispatchQueue.global(qos: .userInitiated).async {
      let url = URL(fileURLWithPath: path)

      // Resolve security-scoped bookmark
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

      let exists = FileManager.default.fileExists(atPath: url.path)
      let response = ["exists": exists]
      invoke.resolve(response)
    }
  }

  @objc public func createFolder(_ invoke: Invoke) throws {
    NSLog("iCloudPlugin: Starting createFolder function")
    let args = try invoke.parseArgs(CreateFolderArgs.self)
    let path = args.path

    DispatchQueue.global(qos: .userInitiated).async {
      let url = URL(fileURLWithPath: path)

      // Resolve security-scoped bookmark
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
        try FileManager.default.createDirectory(
          at: url,
          withIntermediateDirectories: true,
          attributes: nil)

        let response = ["success": true, "path": url.path]
        invoke.resolve(response)

        NSLog("iCloudPlugin: Successfully created folder at \(url.path)")

      } catch {
        NSLog("iCloudPlugin: Error creating folder: \(error)")
        invoke.reject("Error creating folder: \(error.localizedDescription)")
      }
    }
  }

  @objc public func rename(_ invoke: Invoke) throws {
    NSLog("iCloudPlugin: Starting rename function")
    let args = try invoke.parseArgs(RenameArgs.self)
    let old = args.old
    let new = args.new

    DispatchQueue.global(qos: .userInitiated).async {
      let oldURL = URL(fileURLWithPath: old)
      let newURL = URL(fileURLWithPath: new)

      // Resolve security-scoped bookmark
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
        // Ensure paths are accessible
        guard try oldURL.checkResourceIsReachable() else {
          invoke.reject("Source file does not exist at path: \(oldURL.path)")
          return
        }
        if FileManager.default.fileExists(atPath: newURL.path) {
          invoke.reject("Destination file already exists: \(newURL.path)")
          return
        }

        // Rename file
        try FileManager.default.moveItem(at: oldURL, to: newURL)

        let response = ["success": true, "old": oldURL.path, "new": newURL.path]
        invoke.resolve(response)
        NSLog("iCloudPlugin: Successfully renamed file to \(newURL.path)")

      } catch {
        NSLog("iCloudPlugin: Error renaming file: \(error)")
        invoke.reject("Error renaming file: \(error.localizedDescription)")
      }
    }
  }
  // #endregion
}

@_cdecl("init_plugin_icloud")
func initPlugin() -> Plugin {
  NSLog("iCloudPlugin: Initializing plugin")
  return iCloudPlugin()
}
