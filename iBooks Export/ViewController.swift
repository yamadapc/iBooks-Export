//
//  ViewController.swift
//  iBooks Export
//
//  Created by adam on 7/11/15.
//  Copyright (c) 2015 pty. All rights reserved.
//

import Cocoa

struct Book {
    var itemName: String?
    var displayName: String
    var path: String
}

class ViewController: NSViewController, NSTableViewDataSource {
    @IBOutlet weak var tableView: NSTableView!

    @IBAction func onClickExtractButton(sender: AnyObject) {
        self.progressIndicator.startAnimation(self)

        let exportDir = self.getExportDirectory()?.path
        if exportDir == nil {
            return
        }

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) {
            let filemanager = NSFileManager()
            var error: NSError?

            var isDir = UnsafeMutablePointer<ObjCBool>.alloc(1)
            var exists = filemanager.fileExistsAtPath(exportDir!, isDirectory: isDir)
            if  exists && isDir.memory {
                filemanager.createDirectoryAtPath(exportDir!, withIntermediateDirectories: false, attributes: nil, error: &error)
            }

            if error != nil {
                println(error)
            }

            for book in self.books {
                if let targetPath = self.targetPath(book) {
                    filemanager.copyItemAtPath(book.path, toPath: exportDir! + "/" + targetPath, error: &error)
                    if error != nil {
                        println(error)
                    }
                }


                dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0)) {
                    self.progressIndicator.incrementBy(1)
                }
            }

            dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0)) {
                self.progressIndicator.stopAnimation(self)
            }
        }
    }

    @IBOutlet weak var progressIndicator: NSProgressIndicator!

    var books: [Book] = []


    override func viewDidLoad() {
        super.viewDidLoad()
        self.getUserBooks()
        self.progressIndicator.maxValue = Double(self.books.count)
        self.progressIndicator.minValue = 0
        self.progressIndicator.indeterminate = false
        self.tableView.setDataSource(self)
    }

    override var representedObject: AnyObject? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        if tableView != self.tableView {
            return 0
        }

        return self.books.count
    }

    func tableView(tableView: NSTableView, objectValueForTableColumn tableColumn: NSTableColumn?, row: Int) -> AnyObject? {
        if tableView != self.tableView {
            return nil
        }

        let book = self.books[row]
        let identifier = tableColumn?.identifier

        switch(identifier!) {
            case "itemName":
                return book.itemName
            case "displayName":
                return book.displayName
            case "path":
                return book.path.lastPathComponent
            default:
                return nil
        }
    }

    func getExportDirectory() -> NSURL? {
        let openDlg = NSOpenPanel()
        openDlg.canChooseDirectories = true
        openDlg.canChooseFiles = false
        openDlg.prompt = "Select export destination"
        openDlg.canCreateDirectories = true

        if openDlg.runModal() == NSModalResponseOK {
            return openDlg.directoryURL
        }

        return nil
    }

    private func targetPath(book: Book) -> String? {
        if book.displayName != "" {
            if let itemName = book.itemName {
                return itemName + "." + book.path.pathExtension
            }
            return nil
        }
        return book.displayName
    }
    
    private func getUserBooks() {
        let info = self.getUserBooksPlist()
        if let infoBooks: AnyObject = info?.objectForKey("Books") {
            for info in infoBooks as! [AnyObject] {
                let path = info.objectForKey("path") as! String
                let displayName = info.objectForKey("BKDisplayName") as! String
                let itemName = info.objectForKey("itemName") as? String
                self.books.append(Book(itemName: itemName, displayName: displayName, path: path))
            }
        }
    }

    private func getUserBooksPlist() -> NSDictionary? {
        let home = NSHomeDirectory()
        let path = home + "/Library/Containers/com.apple.BKAgentService/Data/Documents/iBooks/Books/Books.plist"
        return NSDictionary(contentsOfFile: path)
    }
}

