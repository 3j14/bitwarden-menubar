//
//  ContentView.swift
//  Bitwarden
//
//  Created by Jonas Drotleff on 17.10.20.
//

import SwiftUI
import WebKit

struct WebKitView: NSViewRepresentable {

    public typealias NSViewType = WKWebView
    private let webView: WKWebView = WKWebView()

    public func makeNSView(context: NSViewRepresentableContext<WebKitView>) -> WKWebView {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let bundleURL = Bundle.main.resourceURL!.absoluteURL
        let html = bundleURL.appendingPathComponent("app/popup/index.html")
        let url = URL(string: "\(html.absoluteString)?appVersion=\(version!)")
        
        webView.frame = CGRect(x: 0, y: 0, width: 375, height: 600)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.configuration.userContentController.add(context.coordinator, name: "bitwardenApp")
        webView.configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        webView.configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        webView.loadFileURL(url!, allowingReadAccessTo: bundleURL)
        return webView
    }
    
    public func updateNSView(_ nsView: WKWebView, context: NSViewRepresentableContext<WebKitView>) {
        // nsView.loadHTMLString("<b>test</b>", baseURL: nil)
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    public class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
        var popoverOpenCount: Int = 0
        
        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name != "bitwardenApp" {
                return
            }
            guard let messageBody = message.body as? String else {
                return
            }
            guard let m: AppMessage = jsonDeserialize(json: messageBody) else {
                return
            }
            let command = m.command
            NSLog("Command: \(command)")
            if command == "storage_get" {
                if let data = m.data {
                    let obj = UserDefaults.standard.string(forKey: data)
                    m.responseData = obj
                    replyMessage(message: m)
                }
            } else if command == "storage_save" {
                guard let data: StorageData = jsonDeserialize(json: m.data) else {
                    return
                }
                if let obj = data.obj {
                    UserDefaults.standard.set(obj, forKey: data.key)
                } else {
                    UserDefaults.standard.removeObject(forKey: data.key)
                }
                replyMessage(message: m)
            } else if command == "storage_remove" {
                if let data = m.data {
                    UserDefaults.standard.removeObject(forKey: data)
                    replyMessage(message: m)
                }
            } else if command == "getLocaleStrings" {
                let language = m.data ?? "en"
                guard let bundleUrl = Bundle.main.resourceURL?.absoluteURL else {
                    return
                }
                let messagesUrl = bundleUrl.appendingPathComponent("app/_locales/\(language)/messages.json")
                do {
                    let json = try String(contentsOf: messagesUrl, encoding: .utf8)
                    webView.evaluateJavaScript("window.bitwardenLocaleStrings = \(json);", completionHandler: {(result, error) in
                        guard let err = error else {
                            return;
                        }
                        NSLog("evaluateJavaScript error : %@", err.localizedDescription);
                    })
                } catch {
                    NSLog("ERROR on getLocaleStrings, \(error)")
                }
                replyMessage(message: m)
            } else if command == "tabs_query" {
                m.responseData = nil
                self.replyMessage(message: m)
            } else if command == "tabs_message" {
                m.responseData = nil
                self.replyMessage(message: m)
            } else if command == "hidePopover" {
                // dismissPopover()
                replyMessage(message: m)
            } else if command == "reloadExtension" {
                webView.reload()
                replyMessage(message: m)
            } else if command == "copyToClipboard" {
                let pasteboard = NSPasteboard.general
                pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
                pasteboard.setString(m.data ?? "", forType: NSPasteboard.PasteboardType.string)
                replyMessage(message: m)
            } else if command == "readFromClipboard" {
                let pasteboard = NSPasteboard.general
                m.responseData = pasteboard.pasteboardItems?.first?.string(forType: .string)
                replyMessage(message: m)
            } else if command == "downloadFile" {
                guard let jsonData = m.data else {
                    return
                }
                guard let dlMsg: DownloadFileMessage = jsonDeserialize(json: jsonData) else {
                    return
                }
                var blobData: Data?
                if dlMsg.blobOptions?.type == "text/plain" {
                    blobData = dlMsg.blobData?.data(using: .utf8)
                } else if let blob = dlMsg.blobData {
                    blobData = Data(base64Encoded: blob)
                }
                guard let data = blobData else {
                    return
                }
                let panel = NSSavePanel()
                panel.canCreateDirectories = true
                panel.nameFieldStringValue = dlMsg.fileName
                panel.begin { response in
                    if response == NSApplication.ModalResponse.OK {
                        if let url = panel.url {
                            do {
                                let fileManager = FileManager.default
                                if !fileManager.fileExists(atPath: url.absoluteString) {
                                    fileManager.createFile(atPath: url.absoluteString, contents: Data(),
                                                           attributes: nil)
                                }
                                try data.write(to: url)
                            } catch {
                                print(error)
                                NSLog("ERROR in downloadFile, \(error)")
                            }
                        }
                    }
                }
            }
        }
        
        func replyMessage(message: AppMessage) {
            let json = (jsonSerialize(obj: message) ?? "null")
            webView.evaluateJavaScript("window.bitwardenSafariAppMessageReceiver(\(json));", completionHandler: {(result, error) in
                guard let err = error else {
                    return;
                }
                NSLog("evaluateJavaScript error : %@", err.localizedDescription);
            })
        }
        
        var parent: WebKitView
        var webView: WKWebView

        init(parent: WebKitView) {
            self.parent = parent
            self.webView = parent.webView
        }
    }
}

func jsonSerialize<T: Encodable>(obj: T?) -> String? {
    let encoder = JSONEncoder()
    do {
        let data = try encoder.encode(obj)
        return String(data: data, encoding: .utf8) ?? "null"
    } catch _ {
        return "null"
    }
}

func jsonDeserialize<T: Decodable>(json: String?) -> T? {
    if json == nil {
        return nil
    }
    let decoder = JSONDecoder()
    do {
        let obj = try decoder.decode(T.self, from: json!.data(using: .utf8)!)
        return obj
    } catch _ {
        return nil
    }
}

class AppMessage: Decodable, Encodable {
    init() {
        id = ""
        command = ""
        data = nil
        responseData = nil
        responseError = nil
    }

    var id: String
    var command: String
    var data: String?
    var responseData: String?
    var responseError: Bool?
    var senderTab: Tab?
}

class StorageData: Decodable, Encodable {
    var key: String
    var obj: String?
}

class TabQueryOptions: Decodable, Encodable {
    var currentWindow: Bool?
    var active: Bool?
}

class Tab: Decodable, Encodable {
    init() {
        id = ""
        index = -1
        windowId = -100
        title = ""
        active = false
        url = ""
    }

    var id: String
    var index: Int
    var windowId: Int
    var title: String?
    var active: Bool
    var url: String?
}

class TabMessage: Decodable, Encodable {
    var tab: Tab
    var obj: String
    var options: TabMessageOptions?
}

class TabMessageOptions: Decodable, Encodable {
    var frameId: Int?
}

class DownloadFileMessage: Decodable, Encodable {
    var fileName: String
    var blobData: String?
    var blobOptions: DownloadFileMessageBlobOptions?
}

class DownloadFileMessageBlobOptions: Decodable, Encodable {
    var type: String?
}


struct ContentView: View {
    var body: some View {
        WebKitView().frame(width: 375, height: 600)
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

