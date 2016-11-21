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

    @IBAction func onClickExtractButton(_ sender: AnyObject) {
        self.progressIndicator.startAnimation(self)

        let exportDir = self.getExportDirectory()?.path
        if exportDir == nil {
            return
        }

        DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated).async {
            self.runExport(exportDir!)
        }
    }

    @IBOutlet weak var progressIndicator: NSProgressIndicator!

    var books: [Book] = []


    override func viewDidLoad() {
        super.viewDidLoad()
        self.getUserBooks()
        self.progressIndicator.maxValue = Double(self.books.count)
        self.progressIndicator.minValue = 0
        self.progressIndicator.isIndeterminate = false
        self.tableView.dataSource = self
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    func runExport(_ exportDir: String) {
        let filemanager = FileManager()
        var error: NSError?
        
        let isDir = UnsafeMutablePointer<ObjCBool>.allocate(capacity: 1)
        let exists = filemanager.fileExists(atPath: exportDir, isDirectory: isDir)
        if !exists && isDir.pointee.boolValue {
            do {
                try filemanager.createDirectory(atPath: exportDir, withIntermediateDirectories: false, attributes: nil)
            } catch let error1 as NSError {
                error = error1
            } catch {
                fatalError()
            }
        }
        
        if error != nil {
            print(error as Any)
        }
        
        for book in self.books {
            self.exportBook(filemanager, exportDir: exportDir, book: book)
        }

        self.onExport()
    }
    
    func exportBook(_ filemanager: FileManager, exportDir: String, book: Book) {
        if let targetPath = self.targetPath(book) {
            if filemanager.fileExists(atPath: exportDir + "/" + targetPath) {
                self.progressIndicator.increment(by: 1)
                return
            }
            
            var error: NSError?
            do {
                try filemanager.copyItem(atPath: book.path, toPath: exportDir + "/" + targetPath)
            } catch let error1 as NSError {
                error = error1
            } catch {
                fatalError()
            }
            if error != nil {
                print(error ?? "Unknown error")
            }
        }
        
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            self.progressIndicator.increment(by: 1)
        }
    }
    
    func onExport() {
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            self.progressIndicator.stopAnimation(self)
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView != self.tableView {
            return 0
        }

        return self.books.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
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
                return (book.path as NSString).lastPathComponent
            default:
                return nil
        }
    }

    func getExportDirectory() -> URL? {
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

    fileprivate func targetPath(_ book: Book) -> String? {
        if book.displayName != "" {
            if let itemName = book.itemName {
                return itemName + "." + (book.path as NSString).pathExtension
            }
            return nil
        }
        return book.displayName
    }
    
    fileprivate func getUserBooks() {
        let info = self.getUserBooksPlist()
        if let infoBooks: AnyObject = info?.object(forKey: "Books") as AnyObject? {
            for info in infoBooks as! [AnyObject] {
                let path = info.object(forKey: "path") as! String
                let displayName = info.object(forKey: "BKDisplayName") as! String
                let itemName = info.object(forKey: "itemName") as? String
                self.books.append(Book(itemName: itemName, displayName: displayName, path: path))
            }
        }
    }

    fileprivate func getUserBooksPlist() -> NSDictionary? {
        let home = NSHomeDirectory()
        let path = home + "/Library/Containers/com.apple.BKAgentService/Data/Documents/iBooks/Books/Books.plist"
        return NSDictionary(contentsOfFile: path)
    }
}

