//
//    MainSearchViewController.swift
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

import Foundation
import AppKit
import CoreSpotlight
import Quartz
import os.log

class MainSearchViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {

    @IBOutlet var searchField: NSSearchField!
    
    
    @IBAction func performSearch(_ sender: Any) {
        //print(searchField.stringValue)
        startQuery(withString: searchField.stringValue)
    }
    
    var query: CSSearchQuery?
    var searchItems: [CSSearchableItem] = []
    let attributes = ["title", "commands",
                      "contentType", "displayName","packageName","kind","packageLongDescription"]
    var queryString: String = ""
    
    @IBOutlet var packageDetails: NSTextView!
    
    @IBOutlet var progressIndicator: NSProgressIndicator!
    
    @IBOutlet var pdfView: PDFView!
    @IBOutlet var searchResultsTable: NSTableView!
    
    @IBOutlet var searchErrorStatus: NSTextField!
    
    @objc func statusChanged(_ input: Notification){
        // update views with new values as needed
        let status = input.object as! MyStatus
        DispatchQueue.main.async {
            self.updateProgress(status: status)
        }
    }
    
    func updateProgress(status: MyStatus) {
        //os_log(OSLogType.info,"updateProgress")
        switch status.myState {
        case .starting:
            progressIndicator.isHidden = false
            progressIndicator.isIndeterminate = true
            progressIndicator.startAnimation(self)
            
        case .indexing:
            progressIndicator.stopAnimation(self)
            progressIndicator.isHidden = false
            progressIndicator.isIndeterminate = false
            progressIndicator.doubleValue = status.myProgressBar
        case .indexingSpotlight:
            progressIndicator.stopAnimation(self)
            progressIndicator.isHidden = false
            progressIndicator.isIndeterminate = false
            progressIndicator.doubleValue = status.myProgressBar
        case .completed:
            progressIndicator.isHidden = true
            progressIndicator.isIndeterminate = false
            progressIndicator.doubleValue = status.myProgressBar
        case .uninitialised:
            //os_log(OSLogType.info,"uninitialised / doc view")
            progressIndicator.isHidden = false
            progressIndicator.isIndeterminate = true
            progressIndicator.startAnimation(self)
            break
        case .paused:
            progressIndicator.isHidden = true
            progressIndicator.isIndeterminate = false
            progressIndicator.doubleValue = status.myProgressBar
            break
        }
        
    }
    
    override func viewDidLoad() {
        searchResultsTable.delegate = self
        searchResultsTable.dataSource = self
        searchResultsTable.doubleAction = #selector(doubleClickAction)
        let appDel: AppDelegate = NSApplication.shared.delegate as! AppDelegate
        updateProgress(status: appDel.lastStatus)
        NotificationCenter.default.addObserver(self, selector: #selector(statusChanged(_:)), name: .statusNotification, object: nil)
        /*
        let cellMenu = NSMenu(title: "Search Menu")
        var item = NSMenuItem (title: "Clear", action: nil, keyEquivalent: "")
        item.tag = NSSearchField.clearRecentsMenuItemTag
        cellMenu.insertItem(item, at: 0)
        item = NSMenuItem.separator()
        item.tag = NSSearchField.recentsTitleMenuItemTag
        cellMenu.insertItem(item, at: 1)
        item = NSMenuItem(title: "Recent Searches", action: nil, keyEquivalent: "")
        item.tag = NSSearchField.recentsTitleMenuItemTag
        cellMenu.insertItem(item, at: 2)
        item = NSMenuItem(title: "Recents", action: nil, keyEquivalent: "")
        item.tag = NSSearchField.recentsMenuItemTag
        cellMenu.insertItem(item, at: 3)
        searchField.searchMenuTemplate = cellMenu
       */
        
    }
    
    @objc func doubleClickAction(sender: NSTableView){
        let selectedRow = searchResultsTable.selectedRow
        if selectedRow == -1 {
            return
        }
        let theSearchItem = searchItems[selectedRow]
        let appDel = NSApplication.shared.delegate as! AppDelegate
        _ = appDel.loadDoc(withURI: theSearchItem.uniqueIdentifier)
         //self.dismiss(sender)
        
    }
    
    override func viewWillLayout() {
         preferredContentSize = view.frame.size
     }
    func createQuery(queryString: String) {
        os_log("Running query %{public}s",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Info"), queryString)
        self.queryString = queryString
        //DispatchQueue.main.async {
            self.searchErrorStatus.stringValue = "Running query:" + queryString
        //}
        query = CSSearchQuery(queryString : queryString,
                              attributes : attributes)
        query!.foundItemsHandler = { (items : [CSSearchableItem]) -> Void in
            // TODO check item count?
            
            DispatchQueue.main.async {
                self.searchItems.append(contentsOf: items)
                self.searchResultsTable.reloadData()
            }
            if self.query!.foundItemCount > 1000 {
                DispatchQueue.main.async {
                    self.searchErrorStatus.stringValue = "Over 1000 results"
                }
                os_log("Over 100 results",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Info"))
                self.query?.cancel()
            }
        }
        query!.completionHandler = { (error) -> Void in
            //sort results by title
            let sorted = try? self.searchItems.sorted(by: { (A:CSSearchableItem, B:CSSearchableItem) throws -> Bool in
                let a = A.attributeSet.title ?? ""
                let b = B.attributeSet.title ?? ""
                return  a<b })
            self.searchItems = sorted ?? self.searchItems
            DispatchQueue.main.async {
                self.searchResultsTable.reloadData()
                if error != nil {
                    self.searchErrorStatus.textColor = .systemRed
                    switch error!._domain {
                    case CSSearchQueryErrorDomain:
                        self.searchErrorStatus.stringValue = "Invalid query"
                    default:
                        self.searchErrorStatus.stringValue = error?.localizedDescription ?? ""
                    }
                    self.packageDetails.isHidden = true
                    self.pdfView.isHidden = true
                    self.searchErrorStatus.isHidden = false
                    let foundItems = self.query!.foundItemCount
                    let foundItemsStr = String(foundItems)
                    os_log("Query failed with %@ items",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Error"),foundItemsStr)
                    if self.query!.isCancelled {
                        self.searchErrorStatus.stringValue = "Query cancelled with " + foundItemsStr + " items found"
                        self.searchErrorStatus.textColor = .systemBlue
                        self.searchResultsTable.selectRowIndexes(NSIndexSet(index: 0) as IndexSet, byExtendingSelection: false)
                        self.packageDetails.isHidden = foundItems == 0
                        self.pdfView.isHidden = foundItems == 0
                    }
                    else {
                        switch error!._domain {
                        case CSSearchQueryErrorDomain:
                            self.searchErrorStatus.stringValue = "Invalid query: " + self.queryString
                        default:
                            self.searchErrorStatus.stringValue = error?.localizedDescription ?? ""
                        }
                    }
                }
                else{
                    self.searchErrorStatus.textColor = .systemBlue
                    var str = self.query!.isCancelled ? "Over " : "Completed, "
                    let foundItems = self.query!.foundItemCount
                    str = str + String(foundItems) + " items found"
                    self.searchErrorStatus.stringValue = str
                    self.searchResultsTable.selectRowIndexes(NSIndexSet(index: 0) as IndexSet, byExtendingSelection: false)
                    self.packageDetails.isHidden = foundItems == 0
                    self.pdfView.isHidden = foundItems == 0
                    self.searchErrorStatus.isHidden = false
                    os_log("Query completed",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Info"))
                }
            }
        }
    }
    
    func startQuery(withString : String) {
        searchItems = []
        pdfView.document = nil
        self.searchResultsTable.reloadData()
        if query != nil {query!.cancel()}
        let queryString = parseQuery(inString: withString)
        createQuery(queryString: queryString)
        query!.start()
    }
    
    func parseQuery(inString: String) -> String {
        
        //return inString
        if inString.contains("==") {
            return inString
        }
        else if inString.contains("!=") {
            return inString
        }
        else {
            var words = inString.split(separator: " ")
            words = Array(words.map({return "* == '\($0)'w"}))
            let outString = words.joined(separator: " || ")
            return outString
        }
    }
    
    func updateSelectedDoc(identifier: String){
        let appDel = NSApplication.shared.delegate as! AppDelegate
        let storeCoordinator = appDel.myPersistentContainer!.viewContext.persistentStoreCoordinator!
        let myURI = URL(string: identifier)!
        let selectedObjectID = storeCoordinator.managedObjectID(forURIRepresentation: myURI)
        if selectedObjectID == nil {
            os_log("Object %{public}@ missing from the Core Data store - refresh the Spotlight index",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Error"),identifier)
            return
        }
        let selectedObject = appDel.myPersistentContainer!.viewContext.object(with: selectedObjectID!)
        if "HelpDoc" == selectedObject.entity.name {
            let item = selectedObject as! HelpDoc
            if item.fileURLString == nil {return} //TODO: tidy up display and leave a message?
            let pdfDoc=PDFDocument(url: URL(string: item.fileURLString!)!) //crashes if database entry is missing
            pdfView.document = pdfDoc
            pdfView.go(to: pdfView.document!.page(at: 0)!)
            // strange behaviour: cursor down in table view causes pdf doc to scroll to last page???
            //_ = self.view
            pdfView.scaleFactor = 1
            let size: Float = Float(pdfView.rowSize(for: pdfDoc!.page(at: 0)!).width)
            let frame = pdfView.frame
            let scaleFactor = CGFloat(frame.width/CGFloat(size))
            pdfView.scaleFactor = scaleFactor
            
            var boldFont:NSFont { return  NSFont.boldSystemFont(ofSize: 12) }
            var smallFont: NSFont {return NSFont.systemFont(ofSize: 10) }
            var normalFont:NSFont { return  NSFont.systemFont(ofSize: 12) }
            
            let pStyle  = NSMutableParagraphStyle()
            pStyle.alignment = .center
            
            let bold: [NSAttributedString.Key: Any] = [
                .font: boldFont,
                .paragraphStyle: pStyle]
            let normal: [NSAttributedString.Key: Any] = [
                .font: normalFont]
            let small: [NSAttributedString.Key: Any] = [
                .font: smallFont]
            
            
            let firstString = NSMutableAttributedString(
                string: (item.packageName == nil || item.packageName == "" ) ? "No package name\n\n" : "Package: \(item.packageName!) \n\n",
                attributes: bold)
            
            let secondString = NSMutableAttributedString(
                string: (item.details == nil || item.details == "") ?  "Document details: none\n" : "Document details: \(item.details!)\n",
                attributes: normal
            )

             secondString.append(NSAttributedString(
                string: (item.language == nil || item.language == "") ?  "Language: none\n" : "Language: \(item.language!)\n",
                attributes: normal
            ))
            
            secondString.append(NSAttributedString(
                string: (item.packageShortDescription == nil || item.packageShortDescription == "") ?  "Package details: none\n\n" : "Package details: \(item.packageShortDescription!)\n\n",
                attributes: normal
            ))
            
            let thirdString = NSAttributedString(
                string: item.packageLongDescription  ?? "no package details" , attributes: small)
            
            firstString.append(secondString)
            firstString.append(thirdString)
            packageDetails.textStorage?.setAttributedString(firstString)
            
            
            
        }
    }
    
    @objc func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = searchResultsTable.selectedRow
        if selectedRow < 0 {return}
        let theSearchItem = searchItems[selectedRow]
        updateSelectedDoc(identifier: theSearchItem.uniqueIdentifier)
        pdfView.goToFirstPage(self)
        
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier:
            (tableColumn!.identifier), owner: self) as? NSTableCellView
        if cell == nil {return nil}
        switch tableColumn!.identifier.rawValue {
        case "titleID":
            cell!.textField?.stringValue = searchItems[row].attributeSet.title ?? ""
        case "packageID":
            cell!.textField?.stringValue = searchItems[row].attributeSet.value(forCustomKey: CSCustomAttributeKey(keyName: "packageName")!)! as! String
            
        default:
            break
        }
        return cell
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return searchItems.count
    }
    
    
}
