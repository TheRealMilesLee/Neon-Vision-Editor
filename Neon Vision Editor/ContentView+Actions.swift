import SwiftUI
import AppKit
import Foundation

extension ContentView {
    func requestCloseTab(_ tab: TabData) {
        if tab.isDirty {
            pendingCloseTabID = tab.id
            showUnsavedCloseDialog = true
        } else {
            viewModel.closeTab(tab: tab)
        }
    }

    func saveAndClosePendingTab() {
        guard let pendingCloseTabID,
              let tab = viewModel.tabs.first(where: { $0.id == pendingCloseTabID }) else {
            self.pendingCloseTabID = nil
            return
        }

        viewModel.saveFile(tab: tab)

        if let updated = viewModel.tabs.first(where: { $0.id == pendingCloseTabID }),
           !updated.isDirty {
            viewModel.closeTab(tab: updated)
            self.pendingCloseTabID = nil
        } else {
            self.pendingCloseTabID = nil
        }
    }

    func discardAndClosePendingTab() {
        guard let pendingCloseTabID,
              let tab = viewModel.tabs.first(where: { $0.id == pendingCloseTabID }) else {
            self.pendingCloseTabID = nil
            return
        }
        viewModel.closeTab(tab: tab)
        self.pendingCloseTabID = nil
    }

    func findNext() {
        guard !findQuery.isEmpty, let tv = activeEditorTextView() else { return }
        findStatusMessage = ""
        let ns = tv.string as NSString
        let start = tv.selectedRange().upperBound
        let forwardRange = NSRange(location: start, length: max(0, ns.length - start))
        let wrapRange = NSRange(location: 0, length: max(0, start))

        if findUsesRegex {
            guard let regex = try? NSRegularExpression(pattern: findQuery, options: findCaseSensitive ? [] : [.caseInsensitive]) else {
                findStatusMessage = "Invalid regex pattern"
                NSSound.beep()
                return
            }
            let forwardMatch = regex.firstMatch(in: tv.string, options: [], range: forwardRange)
            let wrapMatch = regex.firstMatch(in: tv.string, options: [], range: wrapRange)
            if let match = forwardMatch ?? wrapMatch {
                tv.setSelectedRange(match.range)
                tv.scrollRangeToVisible(match.range)
            } else {
                findStatusMessage = "No matches found"
                NSSound.beep()
            }
        } else {
            let opts: NSString.CompareOptions = findCaseSensitive ? [] : [.caseInsensitive]
            if let range = ns.range(of: findQuery, options: opts, range: forwardRange).toOptional() ?? ns.range(of: findQuery, options: opts, range: wrapRange).toOptional() {
                tv.setSelectedRange(range)
                tv.scrollRangeToVisible(range)
            } else {
                findStatusMessage = "No matches found"
                NSSound.beep()
            }
        }
    }

    func replaceSelection() {
        guard let tv = activeEditorTextView() else { return }
        let sel = tv.selectedRange()
        guard sel.length > 0 else { return }
        let selectedText = (tv.string as NSString).substring(with: sel)
        if findUsesRegex {
            guard let regex = try? NSRegularExpression(pattern: findQuery, options: findCaseSensitive ? [] : [.caseInsensitive]) else {
                findStatusMessage = "Invalid regex pattern"
                NSSound.beep()
                return
            }
            let fullSelected = NSRange(location: 0, length: (selectedText as NSString).length)
            let replacement = regex.stringByReplacingMatches(in: selectedText, options: [], range: fullSelected, withTemplate: replaceQuery)
            tv.insertText(replacement, replacementRange: sel)
        } else {
            tv.insertText(replaceQuery, replacementRange: sel)
        }
    }

    func replaceAll() {
        guard let tv = activeEditorTextView(), !findQuery.isEmpty else { return }
        findStatusMessage = ""
        let original = tv.string

        if findUsesRegex {
            guard let regex = try? NSRegularExpression(pattern: findQuery, options: findCaseSensitive ? [] : [.caseInsensitive]) else {
                findStatusMessage = "Invalid regex pattern"
                NSSound.beep()
                return
            }
            let fullRange = NSRange(location: 0, length: (original as NSString).length)
            let count = regex.numberOfMatches(in: original, options: [], range: fullRange)
            guard count > 0 else {
                findStatusMessage = "No matches found"
                NSSound.beep()
                return
            }
            let updated = regex.stringByReplacingMatches(in: original, options: [], range: fullRange, withTemplate: replaceQuery)
            tv.string = updated
            tv.didChangeText()
            findStatusMessage = "Replaced \(count) matches"
        } else {
            let opts: NSString.CompareOptions = findCaseSensitive ? [] : [.caseInsensitive]
            let nsOriginal = original as NSString
            var count = 0
            var searchLocation = 0
            while searchLocation < nsOriginal.length {
                let r = nsOriginal.range(of: findQuery, options: opts, range: NSRange(location: searchLocation, length: nsOriginal.length - searchLocation))
                if r.location == NSNotFound { break }
                count += 1
                searchLocation = max(r.location + max(r.length, 1), searchLocation + 1)
            }
            guard count > 0 else {
                findStatusMessage = "No matches found"
                NSSound.beep()
                return
            }
            let updated = nsOriginal.replacingOccurrences(of: findQuery, with: replaceQuery, options: opts, range: NSRange(location: 0, length: nsOriginal.length))
            tv.string = updated
            tv.didChangeText()
            findStatusMessage = "Replaced \(count) matches"
        }
    }

    private func activeEditorTextView() -> NSTextView? {
        let windows = ([NSApp.keyWindow, NSApp.mainWindow].compactMap { $0 }) + NSApp.windows
        for window in windows {
            if let tv = window.firstResponder as? NSTextView, tv.isEditable {
                return tv
            }
            if let found = findTextView(in: window.contentView) {
                return found
            }
        }
        return nil
    }

    private func findTextView(in view: NSView?) -> NSTextView? {
        guard let view else { return nil }
        if let scroll = view as? NSScrollView, let tv = scroll.documentView as? NSTextView, tv.isEditable {
            return tv
        }
        if let tv = view as? NSTextView, tv.isEditable {
            return tv
        }
        for subview in view.subviews {
            if let found = findTextView(in: subview) {
                return found
            }
        }
        return nil
    }

    func applyWindowTranslucency(_ enabled: Bool) {
        for window in NSApp.windows {
            window.isOpaque = !enabled
            window.backgroundColor = enabled ? .clear : NSColor.windowBackgroundColor
            window.titlebarAppearsTransparent = enabled
            if #available(macOS 13.0, *) {
                window.titlebarSeparatorStyle = enabled ? .none : .automatic
            }
        }
    }

    func openProjectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.showsHiddenFiles = false
        if panel.runModal() == .OK, let folderURL = panel.url {
            projectRootFolderURL = folderURL
            projectTreeNodes = buildProjectTree(at: folderURL)
        }
    }

    func refreshProjectTree() {
        guard let root = projectRootFolderURL else { return }
        projectTreeNodes = buildProjectTree(at: root)
    }

    func openProjectFile(url: URL) {
        if let existing = viewModel.tabs.first(where: { $0.fileURL?.standardizedFileURL == url.standardizedFileURL }) {
            viewModel.selectedTabID = existing.id
            return
        }
        viewModel.openFile(url: url)
    }

    private func buildProjectTree(at root: URL) -> [ProjectTreeNode] {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDir), isDir.boolValue else { return [] }
        return readChildren(of: root)
    }

    private func readChildren(of directory: URL) -> [ProjectTreeNode] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .isHiddenKey, .nameKey]
        guard let urls = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys, options: [.skipsPackageDescendants, .skipsSubdirectoryDescendants]) else {
            return []
        }

        let sorted = urls.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
        var nodes: [ProjectTreeNode] = []
        for url in sorted {
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            if values.isHidden == true { continue }
            let isDirectory = values.isDirectory == true
            let children = isDirectory ? readChildren(of: url) : []
            nodes.append(ProjectTreeNode(url: url, isDirectory: isDirectory, children: children))
        }
        return nodes
    }
}
