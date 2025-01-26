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

class BulkReadTextFileArgs: Decodable {
  let paths: [String]
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

  // serial queue for handling file operations
  private let fileOperationQueue = DispatchQueue(label: "com.icloud.plugin.fileops")

  // semaphore to control concurrent access
  private let accessSemaphore = DispatchSemaphore(value: 1)

  // helper functions

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
        if url.startAccessingSecurityScopedResource() {
          defer { url.stopAccessingSecurityScopedResource() }
          _ = try? saveSecurityScopedBookmark(for: url)
        }
      }

      return url
    } catch {
      return nil
    }
  }

  private func performSecureOperation<T>(
    _ operation: @escaping (URL) throws -> T, completion: @escaping (Result<T, Error>) -> Void
  ) {
    fileOperationQueue.async {
      self.accessSemaphore.wait()

      guard let bookmarkURL = self.resolveSecurityScopedBookmark() else {
        self.accessSemaphore.signal()
        completion(
          .failure(
            NSError(
              domain: "iCloudPlugin", code: -1,
              userInfo: [NSLocalizedDescriptionKey: "Could not resolve security-scoped bookmark"])))
        return
      }

      let granted = bookmarkURL.startAccessingSecurityScopedResource()
      defer {
        if granted {
          bookmarkURL.stopAccessingSecurityScopedResource()
        }
        self.accessSemaphore.signal()
      }

      do {
        let result = try operation(bookmarkURL)
        completion(.success(result))
      } catch {
        completion(.failure(error))
      }
    }
  }

  // helper classes

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

  // plugin functions

  @objc public func openFolder(_ invoke: Invoke) throws {
    DispatchQueue.main.async {
      guard let rootViewController = UIApplication.shared.windows.first?.rootViewController else {
        invoke.reject("No root view controller found")
        return
      }

      let documentPicker = UIDocumentPickerViewController(
        documentTypes: ["public.folder"], in: .open)
      documentPicker.allowsMultipleSelection = false

      self.documentPickerDelegate = DocumentPickerDelegate { urls in
        if let selectedURL = urls.first {
          let accessGranted = selectedURL.startAccessingSecurityScopedResource()
          defer {
            if accessGranted {
              selectedURL.stopAccessingSecurityScopedResource()
            }
          }

          do {
            let reachable = try selectedURL.checkResourceIsReachable()
            guard reachable else {
              throw NSError(
                domain: "iCloudPlugin", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Selected folder is not reachable"])
            }

            let bookmarkData = try selectedURL.bookmarkData(
              options: [],
              includingResourceValuesForKeys: nil,
              relativeTo: nil
            )

            UserDefaults.standard.set(bookmarkData, forKey: self.bookmarkKey)

            let result = [
              "path": selectedURL.path,
              "url": selectedURL.absoluteString,
            ]

            invoke.resolve(result)

          } catch {
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
    let args = try invoke.parseArgs(ReadDirArgs.self)
    let path = args.path

    guard let url = URL(string: path) else {
      invoke.reject("Invalid URL path")
      return
    }

    performSecureOperation({ _ in
      try FileManager.default.contentsOfDirectory(
        at: url,
        includingPropertiesForKeys: nil,
        options: []
      ).map { fileURL -> [String: String] in
        ["name": fileURL.lastPathComponent]
      }
    }) { result in
      switch result {
      case .success(let entries):
        invoke.resolve(["entries": entries])
      case .failure(let error):
        invoke.reject("Error reading directory: \(error.localizedDescription)")
      }
    }
  }

  @objc public func readTextFile(_ invoke: Invoke) throws {
    let args = try invoke.parseArgs(ReadTextFileArgs.self)
    let path = args.path
    let url = URL(fileURLWithPath: path)
    performSecureOperation({ _ in
      guard FileManager.default.fileExists(atPath: url.path) else {
        throw NSError(
          domain: "iCloudPlugin",
          code: -1,
          userInfo: [NSLocalizedDescriptionKey: "File does not exist at path: \(url.path)"]
        )
      }
      return try String(contentsOf: url, encoding: .utf8)
    }) { result in
      switch result {
      case .success(let content):
        invoke.resolve(["content": content])
      case .failure(let error):
        invoke.reject("Error reading text file: \(error.localizedDescription)")
      }
    }
  }

  @objc public func bulkReadTextFile(_ invoke: Invoke) throws {
    let args = try invoke.parseArgs(BulkReadTextFileArgs.self)
    let paths = args.paths
    performSecureOperation({ _ in
      try paths.map { path -> [String: String] in
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
          throw NSError(
            domain: "iCloudPlugin",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "File does not exist at path: \(url.path)"]
          )
        }
        return ["path": path, "content": try String(contentsOf: url, encoding: .utf8)]
      }
    }) { result in
      switch result {
      case .success(let entries):
        invoke.resolve(["entries": entries])
      case .failure(let error):
        invoke.reject("Error reading text files: \(error.localizedDescription)")
      }
    }
  }

  @objc public func readImageFile(_ invoke: Invoke) throws {
    let args = try invoke.parseArgs(ReadImageFileArgs.self)
    let path = args.path
    let url = URL(fileURLWithPath: path)
    performSecureOperation({ _ in
      guard FileManager.default.fileExists(atPath: url.path) else {
        throw NSError(
          domain: "iCloudPlugin",
          code: -1,
          userInfo: [NSLocalizedDescriptionKey: "Image file does not exist at path: \(url.path)"]
        )
      }
      let imageData = try Data(contentsOf: url)
      return imageData.base64EncodedString()
    }) { result in
      switch result {
      case .success(let base64String):
        invoke.resolve(["content": base64String])
      case .failure(let error):
        invoke.reject("Error reading image file: \(error.localizedDescription)")
      }
    }
  }

  @objc public func writeTextFile(_ invoke: Invoke) throws {
    let args = try invoke.parseArgs(WriteTextFileArgs.self)
    let path = args.path
    let content = args.content

    let url = URL(fileURLWithPath: path)

    performSecureOperation({ _ in
      let directory = url.deletingLastPathComponent()
      try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
      )
      try content.write(to: url, atomically: true, encoding: .utf8)
      return url.path
    }) { result in
      switch result {
      case .success(let path):
        invoke.resolve([
          "success": true,
          "path": path,
        ])
      case .failure(let error):
        invoke.reject("Error writing text file: \(error.localizedDescription)")
      }
    }
  }

  @objc public func exists(_ invoke: Invoke) throws {
    let args = try invoke.parseArgs(ExistsArgs.self)
    let path = args.path
    let url = URL(fileURLWithPath: path)
    performSecureOperation({ _ in
      return FileManager.default.fileExists(atPath: url.path)
    }) { result in
      switch result {
      case .success(let exists):
        invoke.resolve(["exists": exists])
      case .failure(let error):
        invoke.reject("Error checking file existence: \(error.localizedDescription)")
      }
    }
  }

  @objc public func createFolder(_ invoke: Invoke) throws {
    let args = try invoke.parseArgs(CreateFolderArgs.self)
    let path = args.path
    let url = URL(fileURLWithPath: path)
    performSecureOperation({ _ in
      try FileManager.default.createDirectory(
        at: url,
        withIntermediateDirectories: true,
        attributes: nil
      )
      return url.path
    }) { result in
      switch result {
      case .success(let path):
        invoke.resolve(["success": true, "path": path])
      case .failure(let error):
        invoke.reject("Error creating folder: \(error.localizedDescription)")
      }
    }
  }

  @objc public func rename(_ invoke: Invoke) throws {
    let args = try invoke.parseArgs(RenameArgs.self)
    let old = args.old
    let new = args.new
    let oldURL = URL(fileURLWithPath: old)
    let newURL = URL(fileURLWithPath: new)
    performSecureOperation({ _ in
      guard try oldURL.checkResourceIsReachable() else {
        throw NSError(
          domain: "iCloudPlugin",
          code: -1,
          userInfo: [
            NSLocalizedDescriptionKey: "Source file does not exist at path: \(oldURL.path)"
          ]
        )
      }
      if FileManager.default.fileExists(atPath: newURL.path) {
        throw NSError(
          domain: "iCloudPlugin",
          code: -1,
          userInfo: [NSLocalizedDescriptionKey: "Destination file already exists: \(newURL.path)"]
        )
      }
      try FileManager.default.moveItem(at: oldURL, to: newURL)
      return ["old": oldURL.path, "new": newURL.path]
    }) { result in
      switch result {
      case .success(let response):
        invoke.resolve(["success": true].merging(response) { (_, new) in new })
      case .failure(let error):
        invoke.reject("Error renaming file: \(error.localizedDescription)")
      }
    }
  }
}

@_cdecl("init_plugin_icloud")
func initPlugin() -> Plugin {
  return iCloudPlugin()
}
