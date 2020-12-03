//
//  AppDelegate.swift
//  Bitwarden
//
//  Created by Jonas Drotleff on 17.10.20.
//

import Cocoa
import SwiftUI


@main
struct BitwardenMenu: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}


class AppDelegate: NSObject, NSApplicationDelegate {

    var popover: NSPopover!
    var statusBarItem: NSStatusItem!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create the SwiftUI view that provides the window contents.
        let contentView = ContentView()
        
        let _popover = NSPopover()
        
        _popover.contentSize = NSSize(width: 375, height: 600)
        _popover.behavior = .transient
        _popover.contentViewController = NSHostingController(rootView: contentView)
        
        self.popover = _popover
        
        self.statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if (self.statusBarItem.button != nil) {
            self.statusBarItem.button!.image = NSImage(named: "TrayIcon")
            self.statusBarItem.button!.action = #selector(togglePopover(_:))
        }
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if self.popover.isShown {
            self.popover.performClose(sender)
        } else if self.statusBarItem.button != nil {
            self.popover.show(
                relativeTo: self.statusBarItem.button!.bounds,
                of: self.statusBarItem.button!,
                preferredEdge: .minY
            )
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}
