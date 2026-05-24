import AppKit
import ApplicationServices
import Foundation

private enum Constants {
    static let appName = "go2Ghostty"
    static let ghosttyBundleIdentifier = "com.mitchellh.ghostty"
    static let ghosttyAppPath = "/Applications/Ghostty.app"
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        DispatchQueue.main.async {
            self.openGhosttyAtFinderLocation()
        }
    }

    private func openGhosttyAtFinderLocation() {
        DebugLog.write("applicationDidFinishLaunching")
        let directory = FinderLocationResolver.currentDirectory() ?? FileManager.default.homeDirectoryForCurrentUser.path
        DebugLog.write("resolved directory: \(directory)")
        let ghosttyIsRunning = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == Constants.ghosttyBundleIdentifier
        }
        DebugLog.write("ghostty is running: \(ghosttyIsRunning)")

        let didOpen: Bool
        if ghosttyIsRunning {
            didOpen = GhosttyLauncher.openNewTab(at: directory)
        } else {
            didOpen = GhosttyLauncher.openNewWindow(at: directory)
        }
        DebugLog.write("did open: \(didOpen)")

        if !didOpen {
            NSAlert.show(message: "Unable to open Ghostty", detail: "Install Ghostty in /Applications, or grant Automation and Accessibility permissions to \(Constants.appName).")
        }

        NSApp.terminate(nil)
    }
}

@main
enum Main {
    static func main() {
        DebugLog.write("main")
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

private enum FinderLocationResolver {
    static func currentDirectory() -> String? {
        let script = """
        tell application "Finder"
            if (count of Finder windows) is greater than 0 then
                set finderTarget to target of front Finder window as alias
                return POSIX path of finderTarget
            else if (count of selection) is greater than 0 then
                set selectedItem to item 1 of selection
                if class of selectedItem is folder then
                    return POSIX path of (selectedItem as alias)
                else
                    return POSIX path of ((container of selectedItem) as alias)
                end if
            else
                return POSIX path of (path to home folder)
            end if
        end tell
        """

        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            return nil
        }

        let result = appleScript.executeAndReturnError(&error)
        if let error {
            DebugLog.write("Finder AppleScript error: \(error)")
            return nil
        }

        let path = result.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        return path?.isEmpty == false ? path : nil
    }
}

private enum GhosttyLauncher {
    static func openNewWindow(at directory: String) -> Bool {
        guard FileManager.default.fileExists(atPath: Constants.ghosttyAppPath) else {
            DebugLog.write("Ghostty app not found at \(Constants.ghosttyAppPath)")
            return false
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [
            "-n",
            Constants.ghosttyAppPath,
            "--args",
            "--working-directory=\(directory)"
        ]

        let success = process.runAndWait()
        DebugLog.write("open new window success: \(success)")
        return success
    }

    static func openNewTab(at directory: String) -> Bool {
        guard requestAccessibilityIfNeeded() else {
            return openNewWindow(at: directory)
        }

        NSWorkspace.shared.runningApplications
            .first { $0.bundleIdentifier == Constants.ghosttyBundleIdentifier }?
            .activate(options: [.activateAllWindows, .activateIgnoringOtherApps])

        let command = "cd \(shellQuoted(directory)); clear"
        let script = """
        set previousClipboard to the clipboard
        delay 0.15
        tell application "System Events"
            keystroke "t" using command down
        end tell
        delay 0.2
        set the clipboard to "\(appleScriptEscaped(command))"
        tell application "System Events"
            keystroke "v" using command down
            key code 36
        end tell
        delay 0.1
        set the clipboard to previousClipboard
        """

        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            return openNewWindow(at: directory)
        }

        appleScript.executeAndReturnError(&error)
        if let error {
            DebugLog.write("new tab AppleScript error: \(error)")
            return openNewWindow(at: directory)
        }

        return true
    }

    private static func requestAccessibilityIfNeeded() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func appleScriptEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}

private enum DebugLog {
    static let url = URL(fileURLWithPath: "/tmp/go2Ghostty.log")

    static func write(_ message: String) {
        let line = "\(Date()) \(message)\n"
        guard let data = line.data(using: .utf8) else {
            return
        }

        if FileManager.default.fileExists(atPath: url.path),
           let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url)
        }
    }
}

private extension Process {
    func runAndWait() -> Bool {
        do {
            try run()
            waitUntilExit()
            return terminationStatus == 0
        } catch {
            return false
        }
    }
}

private extension NSAlert {
    static func show(message: String, detail: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = detail
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
