//
//    SearchViewController.swift
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

class SearchViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    
    var query: CSSearchQuery?
    var searchItems: [CSSearchableItem] = []
    let attributes = ["title", "commands",
                      "contentType", "displayName","packageName","kind","packageLongDescription"]
    var caller: NSSearchField?
    
    @IBOutlet var pdfView: PDFView!
    @IBOutlet var searchResultsTable: NSTableView!
    override func viewDidLoad() {
        searchResultsTable.delegate = self
        searchResultsTable.dataSource = self
        searchResultsTable.doubleAction = #selector(doubleClickAction)
    }
    
    @objc func doubleClickAction(sender: NSTableView){
        let selectedRow = searchResultsTable.selectedRow
        if selectedRow == -1 {
            return
        }
        let theSearchItem = searchItems[selectedRow]
        let appDel = NSApplication.shared.delegate as! AppDelegate
        _ = appDel.loadDoc(withURI: theSearchItem.uniqueIdentifier)
        caller!.stringValue = ""
        self.dismiss(sender)
        
    }
    
    func createQuery(queryString: String) {
        os_log("Running query %{public}s",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Info"),queryString)
//        if query.is
        if (query != nil ) {
            query?.cancel()
            
        }
        query = CSSearchQuery(queryString : queryString,
                              attributes : attributes)
        query!.foundItemsHandler = { (items : [CSSearchableItem]) -> Void in
            // TODO check item count?
            
            DispatchQueue.main.async {
            self.searchItems.append(contentsOf: items)
            self.searchResultsTable.reloadData()
            }
            if self.query!.foundItemCount > 10 {self.query?.cancel()}
        }
        query!.completionHandler = { (error) -> Void in
            if self.query?.isCancelled == true {
                let foundItems = self.query!.foundItemCount
                let foundItemsStr = String(foundItems)
                os_log("Query cancelled with %{public}@ items",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Info"),foundItemsStr)
            }
            else {
                if error != nil {
                    switch error!._domain {
                    case CSSearchQueryErrorDomain:
                        print(error.debugDescription)
                    default:
                        let foundItems = self.query!.foundItemCount
                        let foundItemsStr = String(foundItems)
                        os_log("Query failed with %@ items",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Info"),foundItemsStr)
                        break
                    }
                }
            }
        }
    }
    
    func startQuery(withString : String) {
        searchItems = []
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
    
    func updatePDF(identifier: String){
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
            let pdfDoc=PDFDocument(url: URL(string: item.fileURLString!)!)
            pdfView.document = pdfDoc
             _ = self.view
            pdfView.scaleFactor = 1
            let size: Float = Float(pdfView.rowSize(for: pdfDoc!.page(at: 0)!).width)
            let scaleFactor = CGFloat(210.0/size)
            pdfView.scaleFactor = scaleFactor
            
        }
    }
    
    @objc func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = searchResultsTable.selectedRow
        if selectedRow < 0 {return}
        let theSearchItem = searchItems[selectedRow]
        updatePDF(identifier: theSearchItem.uniqueIdentifier)
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
