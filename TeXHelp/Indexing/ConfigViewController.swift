//
//    ConfigViewController.swift
//    TeXHelp
//    Copyright © 2023 Neil Sims.
//
//    This program is free software: you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation, either version 3 of the License, or
//    (at your option) any later version.
//
//    This program is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU General Public License for more details.
//
//    You should have received a copy of the GNU General Public License
//    along with this program.  If not, see <https://www.gnu.org/licenses/>.
//

import Cocoa
import os.log
import CoreSpotlight

class ConfigViewController: NSViewController {


    var statusController: StatusViewController?
    @IBOutlet var excludeTableView: NSTableView!
    @IBOutlet var indexKeywordsTableView: NSTableView!
    @IBOutlet var indexFileInfoTableView: NSTableView!
    
    @IBOutlet var rootDirectory: NSTextField!
    //    @IBOutlet var pdfPreview: NSButton!
    //#TODO: rename this as badlist and other refactoring
    @IBOutlet var badlistTableView: NSTableView!
    
    var tableViewData: [String:[String]] = [
        "exclude":["a","b"],
        "indexFileInfo":["c","d"],
        "indexKeywords":["e","f","g"],
        "badlist":[]
        
    ]
    
    
    var appDel: AppDelegate = NSApplication.shared.delegate as! AppDelegate
    
    
    @IBAction func restoreMyDefaults(_ sender: Any) {
        try! ConfigViewController.restoreDefaults(entitledURL: appDel.entitledURL!)
        self.getDefaults()
    }
    
    
    
    @IBAction func addToBadlist(_ sender: Any) {
        let dummyUrl = URL(fileURLWithPath: "texmf-dist/doc/", isDirectory: true, relativeTo: appDel.entitledURL! as URL)
        let myDlg = NSOpenPanel()
        myDlg.directoryURL = dummyUrl
        myDlg.allowedFileTypes=["pdf","PDF"]
        myDlg.allowsMultipleSelection = false
        myDlg.allowsOtherFileTypes = false
        myDlg.canChooseDirectories = false
        let out = myDlg.runModal()
        if out == NSApplication.ModalResponse.OK{
            if tableViewData["badlist"] == nil {
                tableViewData["badlist"] = [myDlg.url!.path]
            }
            else {
                tableViewData["badlist"]!.append(myDlg.url!.path)
            }
        badlistTableView.reloadData()
        }
    }
    
    @IBAction func removeFromBadlist(_ sender: Any) {
        if badlistTableView.selectedRow >= 0 {
        tableViewData["badlist"]!.remove(at: badlistTableView.selectedRow)
        UserDefaults.standard.set(tableViewData["badlist"], forKey: "badlistPathStrings")
        badlistTableView.reloadData()
        }
    }
    
    
    static func restoreDefaults (entitledURL: NSURL) throws {
        let fileManager = FileManager.default
        let rootURL = entitledURL as URL
        let docLocation = URL(fileURLWithPath: "texmf-dist/doc/", isDirectory: true, relativeTo: rootURL)
        let urls = try fileManager.contentsOfDirectory(at: docLocation, includingPropertiesForKeys: [URLResourceKey.isDirectoryKey], options: [])
        
        let dirs = urls.map{$0.lastPathComponent}
        let dirSet = Set(dirs)
        var includeKeywordsSet: Set<String>
        //var includeKeywords: [String]?
        let includeKeywords = UserDefaults.standard.array(forKey: "indexKeywordsPathStrings") as? [String]
        if includeKeywords == nil  {
            includeKeywordsSet = Set(["latex","generic"])
        }
        else {
            includeKeywordsSet = Set(includeKeywords!)
        }
        includeKeywordsSet.formIntersection(dirs)
    
        let includeInfo = UserDefaults.standard.array(forKey: "indexFileInfoPathStrings") as? [String]
        var includeInfoSet: Set<String>
        if includeInfo == nil {
            includeInfoSet = Set(["chktex", "upmendex", "uptex", "metapost", "pdftex", "eplain", "context", "platex", "uplatex", "etex", "plain", "xetex",  "luatex", "xindy", "xelatex", "ptex", "tetex",  "bibtexu",  "bibtex8", "cstex", "tpic2pdftex",  "lualatex", "amstex", "mex"])
        }
        else {
            includeInfoSet = Set(includeInfo!)
        }
        includeInfoSet.formIntersection(dirs)
        let excludeSet: Set<String> = dirSet.subtracting(includeKeywordsSet).subtracting(includeKeywordsSet)
        
        UserDefaults.standard.set(Array(excludeSet), forKey: "excludePathStrings")
        UserDefaults.standard.set(Array(includeInfoSet), forKey: "indexFileInfoPathStrings")
        UserDefaults.standard.set(Array(includeKeywordsSet), forKey: "indexKeywordsPathStrings")
        UserDefaults.standard.set(["/usr/local/texlive/2018/texmf-dist/doc/generic/pst-cox/pst-coxcoor/pst-coxcoor_doc.pdf"], forKey: "badlistPathStrings")
        var emptyString: [String] = []
        UserDefaults.standard.set(emptyString, forKey: "badlistPathStrings")
        
//        UserDefaults.standard.set(false,forKey: "pdfPreview")
    }
    
    
    
    func getDefaults() {
        tableViewData["exclude"] = UserDefaults.standard.array(forKey: "excludePathStrings") as? [String]
        tableViewData["indexFileInfo"] = UserDefaults.standard.array(forKey: "indexFileInfoPathStrings") as? [String]
        tableViewData["indexKeywords"] = UserDefaults.standard.array(forKey: "indexKeywordsPathStrings") as? [String]
        tableViewData["badlist"] = UserDefaults.standard.array(forKey: "badlistPathStrings") as? [String]
        
//        let pdfP = UserDefaults.standard.bool(forKey: "pdfPreview")
//        if pdfP == true {
//            pdfPreview.state = NSButton.StateValue.on
//        }
//        else{
//            pdfPreview.state = NSButton.StateValue.off
//        }
        
        tableViewData["exclude"]!.sort()
        tableViewData["indexFileInfo"]!.sort()
        tableViewData["indexKeywords"]!.sort()
        
        excludeTableView.reloadData()
        indexFileInfoTableView.reloadData()
        indexKeywordsTableView.reloadData()
        badlistTableView.reloadData()

    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDel.stopIndexing()
        getDefaults()
        self.rootDirectory.stringValue =  "The database root directory is: \(appDel.entitledURL!.path!)"
        
        self.excludeTableView.delegate = self as NSTableViewDelegate
        self.indexFileInfoTableView.delegate = self as NSTableViewDelegate
        self.indexKeywordsTableView.delegate = self as NSTableViewDelegate
        self.badlistTableView.delegate = self as NSTableViewDelegate

        self.excludeTableView.dataSource = self as NSTableViewDataSource
        self.indexFileInfoTableView.dataSource = self as NSTableViewDataSource
        self.indexKeywordsTableView.dataSource = self as NSTableViewDataSource
        self.badlistTableView.dataSource = self as NSTableViewDataSource
        
        badlistTableView.reloadData()
        
        excludeTableView.registerForDraggedTypes([.string])
        excludeTableView.setDraggingSourceOperationMask([.copy, .delete], forLocal: false)
        excludeTableView.reloadData()
        
        indexFileInfoTableView.registerForDraggedTypes([.string])
        indexFileInfoTableView.setDraggingSourceOperationMask([.copy, .delete], forLocal: false)
        indexFileInfoTableView.reloadData()
        
        indexKeywordsTableView.registerForDraggedTypes([.string])
        indexKeywordsTableView.setDraggingSourceOperationMask([.copy, .delete], forLocal: false)
        indexKeywordsTableView.reloadData()
        
        //entitledURL: NSURL

    }

    
    override func viewWillLayout() {
         preferredContentSize = view.frame.size
     }
    
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.

        }
    }
    
    

    @IBAction func checkDeleteDatabase(_ sender: Any){
        let pc = appDel.myPersistentContainer!
        var existingEntries: Int
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "HelpDoc")
        do {
            try existingEntries = pc.viewContext.count(for: fetchRequest)
        } catch let error as NSError {
            os_log("%{public}@",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Error"),error.description)
            return
        }
        var myAlert = NSAlert()
        myAlert.alertStyle = NSAlert.Style.critical
        myAlert.messageText = "Are you sure you want to delete the \(existingEntries) entries in the database, and remove the spotlight index? This action cannot be undone."
        myAlert.informativeText = "The database will need to be re-indexed."
        myAlert.addButton(withTitle: "Delete")
        myAlert.addButton(withTitle: "Cancel")
        let out = myAlert.runModal()
        if out == NSApplication.ModalResponse.alertFirstButtonReturn {
            self.actuallyDeleteDatabase()
        }
    }
    
    func actuallyDeleteDatabase() {
        // TODO: delete entitlements URL as well
        // TODO: run on separate thread like splash page
        //TODO: on completion, go back to splash screen
        let storyboard = NSStoryboard(name: "MainStoryboard", bundle: nil)
        let deleteDatabaseViewController = storyboard.instantiateController(withIdentifier: "deleteDatabase") as! DeleteDataBaseViewController
        self.presentAsSheet(deleteDatabaseViewController)
        DispatchQueue.global().async() {
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "HelpDoc")
            let pc = self.appDel.myPersistentContainer!
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            deleteDatabaseViewController.setStatus("Sending batch delete request for main database")
            do {
                try pc.persistentStoreCoordinator.execute(deleteRequest, with: pc.viewContext)
            } catch let error as NSError {
                os_log("Couldn't delete the persistent container objects\n%@",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Error"),error.description)
            }
            deleteDatabaseViewController.setStatus("Saving context")
            do {
                try pc.viewContext.save()
            } catch let error as NSError {
                os_log("Couldn't save the persistent container after object deletion\n%@",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Error"),error.description)
            }
            let fetchRequest1: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Keyword")
            let deleteRequest1 = NSBatchDeleteRequest(fetchRequest: fetchRequest1)
            deleteDatabaseViewController.setStatus("Sending batch delete request for keyword database")
            do {
                try pc.persistentStoreCoordinator.execute(deleteRequest1, with: pc.viewContext)
            } catch let error as NSError {
                os_log("Couldn't delete the persistent container objects\n%@",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Error"),error.description)
            }
            deleteDatabaseViewController.setStatus("Saving context")
            do {
                try pc.viewContext.save()
            } catch let error as NSError {
                os_log("Couldn't save the persistent container after object deletion\n%@",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Error"),error.description)
            }
            deleteDatabaseViewController.setStatus("Deleting databases. Now deleting Spotlight index...")
            var waiting = true
            CSSearchableIndex(name: "com.TeXHelp.TeXHelp").deleteAllSearchableItems(completionHandler: { (error) -> Void in
                if error != nil {
                    os_log("%{public}@", log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Error"),error?.localizedDescription ?? "Error")
                }
                else {
                    DispatchQueue.main.async {
                        os_log("Deleted Spotlight Index",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Info"))
                        deleteDatabaseViewController.statusText.stringValue = "Deleted"
                        usleep(1000000)
                        waiting = false
                    }
                }
            })
            while waiting {
                usleep(200000)
            }
            UserDefaults.standard.set(nil, forKey: "entitledBookmarkData")
            DispatchQueue.main.async { [self] in
                self.dismiss(deleteDatabaseViewController)
                var wins = NSApplication.shared.windows
                for win in wins {
                    if win.contentViewController != self.appDel.landingPageViewController {
                        win.close()
                    }
                }
                self.appDel.landingPageViewController?.view.window?.makeKeyAndOrderFront(nil)
                appDel.landingPageViewController?.initialise()

            }
            
            
        }
    }
    


    @IBAction func deleteSpotlight(_ sender: Any) {
        let storyboard = NSStoryboard(name: "MainStoryboard", bundle: nil)
        let waitViewController = storyboard.instantiateController(withIdentifier: "deleteDatabase") as! DeleteDataBaseViewController
        self.presentAsSheet(waitViewController)
        waitViewController.statusText.stringValue = "Deleting Spotlight index..."
        CSSearchableIndex(name: "com.TeXHelp.TeXHelp").deleteAllSearchableItems(completionHandler: { (error) -> Void in
            if error != nil {
                os_log("%{public}@", log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Error"), error?.localizedDescription ?? "Error")
            }
            else {
                DispatchQueue.main.async {
                    os_log("Deleted Spotlight Index",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Spotlight"))
                    waitViewController.statusText.stringValue = "Deleted"
                    usleep(1000000)
                    self.dismiss(waitViewController)
                }
            }
        })
    }
    
    

    @IBAction func cancel(_ sender: Any) {
//        self.dismiss( sender)
        self.view.window?.close()
        //statusController?.configCancelled()
    }
    
    @IBAction func apply(_ sender: Any) {
        
        UserDefaults.standard.set(tableViewData["exclude"]!, forKey: "excludePathStrings")
        UserDefaults.standard.set(tableViewData["indexFileInfo"]!, forKey: "indexFileInfoPathStrings")
        UserDefaults.standard.set(tableViewData["indexKeywords"]!, forKey: "indexKeywordsPathStrings")
        UserDefaults.standard.set(tableViewData["badlist"], forKey: "badlistPathStrings")
//        UserDefaults.standard.set(pdfPreview.state, forKey: "pdfPreview")
//        let pdfP: Bool
//        if pdfPreview.state == NSButton.StateValue.on {
//             pdfP = true
//        }
//        else{
//             pdfP = false
//        }
//        UserDefaults.standard.set(pdfP, forKey: "pdfPreview")
        DispatchQueue.main.async {
            
            self.appDel.resumeIndexing()
            self.view.window?.close()
        }
    }
    
}

extension ConfigViewController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        if let cell = tableView.makeView(withIdentifier:
              (tableColumn!.identifier),
              owner: self) as? NSTableCellView {
            var val:String
            val = tableViewData[(tableView.identifier?.rawValue)!]![row]
            cell.textField?.stringValue = val
            return cell
        }
        return nil
        
    }
    
    func textDidEndEditing(_ obj: Notification) {
        print("hi")
    }

}

extension ConfigViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableViewData[tableView.identifier!.rawValue] == nil {
            return 0
        }
        else {
            return tableViewData[tableView.identifier!.rawValue]!.count
        }
        
    }
    
    func deleteEntry(tableID: String, string: String) {
        tableViewData[tableID]!.removeAll{ tableString -> Bool in
            tableString == string
        }
    }
    
    func addEntry(tableID: String, string: String) {
        tableViewData[tableID]!.append(string)
        tableViewData[tableID]!.sort()
    }
    
    
    func tableView(
        _ tableView: NSTableView,
        pasteboardWriterForRow row: Int) -> NSPasteboardWriting?
    {
        return tableViewData[tableView.identifier!.rawValue]![row] as NSString
    }
    
    
    func tableView(
        _ tableView: NSTableView,
        validateDrop info: NSDraggingInfo,
        proposedRow row: Int,
        proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation
    {
        // called when an item is dragged over the table
        
        guard dropOperation == .above else { return [] }
        
        let thisTableID = tableView.identifier?.rawValue
        var sourceTableID: String? = nil
        if let sourceTable = info.draggingSource as? NSTableView {
            sourceTableID = sourceTable.identifier?.rawValue
        }
        if thisTableID! != sourceTableID! {
            //tableView.tableColumns[0]
            tableView.setDropRow(-1, dropOperation: .on)
            return .move
        }
        else {
            return []
        }
    }
    
    func tableView(
        _ tableView: NSTableView,
        acceptDrop info: NSDraggingInfo,
        row: Int,
        dropOperation: NSTableView.DropOperation) -> Bool
    {
        // called at the point of dropping, if drop is valid
        let items = info.draggingPasteboard.pasteboardItems
        var strings: [String] = []
        for item in items! {
            strings.append(item.string(forType: .string)!)
        }
        for itemString in strings{
//            let itemString = (info.draggingPasteboard.pasteboardItems?.first?.string(forType: .string))!
            let thisTableID = tableView.identifier?.rawValue
            var sourceTableID: String? = nil
            if let sourceTable = info.draggingSource as? NSTableView {
                sourceTableID = sourceTable.identifier?.rawValue
                let sourceData = sourceTable.dataSource as! ConfigViewController
                let destinationData = tableView.dataSource as! ConfigViewController
                sourceData.deleteEntry(tableID: sourceTableID!, string: itemString)
                destinationData.addEntry(tableID: thisTableID!, string: itemString)
                sourceTable.reloadData()
                tableView.reloadData()
            }
        }
        // remove item from source table and add it to this table
        
        return true
    }
    
    func tableView(
        _ tableView: NSTableView,
        draggingSession session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation)
    {
        // called at the end of the drag operation, regardless of whether drop was valid
    }
}
