//
//    TeXHelpDocViewController.swift
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

import Quartz
import Foundation
import CoreData
import os.log


class TeXHelpDocViewController: NSViewController, NSWindowDelegate, NSControlTextEditingDelegate {
    
    
    @IBOutlet var searchTableView: NSTableView!
    @IBOutlet var outlineView: NSOutlineView!
    @IBOutlet var keywordTableView: NSTableView!
    
    @IBOutlet var pdfDocView: PDFView!
    @IBOutlet var searchString: NSTextField!
    
    @objc var searchTableViewData:[[Int:[PDFSelection]]] = [] //array of dictionary objects. each object has a single item with a key corresponding to the page number and a value corresponding to an array of PDF selections (i.e. search hits)
    var searchTableViewDataKeywords: [[Int:[PDFSelection]]] = []
    @objc var keywordTableViewData:[[String:Int]] = []  //array of dictionary objects. each object has a single item with a key corresponding to the keyword and a value corresponding to the best page for that keyword
    @objc var outlineViewData: PDFOutline? //optional outline object, set upon load
    
    override var representedObject: Any? {
        didSet {
            // Pass down the represented object to all of the child view controllers.
            for child in children {
                child.representedObject = representedObject
            }
        }
    }
    
    @objc var sortByRank: Bool = true //default sort by rank

    
    
    @IBOutlet var bookmarksTabButton: NSButton!
    @IBOutlet var teXTabButton: NSButton!
    @IBOutlet var searchTabButton: NSButton!
    @IBOutlet var tabView: NSTabView!
    @IBOutlet var pageNumber: NSTextField!
    var oldValue: String?
    
    // switch between tabs based on the buttons
    @IBAction func tabButton(_ sender: NSButton) {
        let allButtons = [teXTabButton,bookmarksTabButton,searchTabButton]
        for button in allButtons {
            if button != sender {
                button!.state = .off
                button!.isEnabled = true
            }
            else{
                button!.state = .on
                let ind = allButtons.firstIndex(of: button!)!
                tabView.selectTabViewItem(at: ind)
                button!.isEnabled = false
            }
        }
    }
    
    @IBAction func goToPage(_ sender: Any) {
        let page = Int(pageNumber.stringValue)
        if page == nil {
            pageNumber.stringValue = pdfDocView.currentPage?.label ?? ""
            return}
        let pdfDoc = pdfDocView.document
        let pdfPage = pdfDoc?.page(at: page!)
        if pdfPage == nil {
            pageNumber.stringValue = pdfDocView.currentPage?.label ?? ""
            return}
        pdfDocView.go(to: pdfPage!)
//        pageNumber.stringValue = pdfDocView.currentPage?.label ?? ""
    }
    
    // navigation controls
    @IBAction func pageForward(sender: Any?){
        pdfDocView.goToNextPage(nil)
    }
    @IBAction func pageBackward(sender: Any?){
        pdfDocView.goToPreviousPage(nil)
    }
    
    @IBAction func pageBegin(sender: Any?){
        pdfDocView.goToFirstPage(nil)
    }
    
    @IBAction func pageEnd(sender: Any?){
        pdfDocView.goToLastPage(nil)
    }
    
    @IBAction func goForward(sender: Any?){
        pdfDocView.goForward(nil)
    }

    @IBAction func goBackward(sender: Any?){
        pdfDocView.goBack(nil)
    }

    @IBAction func openPDF(_ sender: Any) {
        let theDoc = self.representedObject as! TeXHelpDocument
        let theFilePath = URL(string: theDoc.content.fileURLString)!.path
        NSWorkspace.shared.openFile(theFilePath)
    }
    
    @IBAction func toggleFavourite(_ sender: NSButton) {
        let appDel = NSApplication.shared.delegate as! AppDelegate
        var favSet: Set<String> = Set(appDel.favourites)
        let ob = self.representedObject as! TeXHelpDocument
        let thisFile = ob.content.fileURLString
        switch  sender.state {
        case .on:
            favSet = favSet.union([thisFile])
        case .off:
            favSet.remove(thisFile)
        default:
            break
        }
        appDel.favourites = Array(favSet)
        UserDefaults.standard.set(appDel.favourites, forKey: "favourites")
        appDel.refreshFavouritesMenu()
    }
    
    
    // update page indicator whenever page changes
    @objc func pageChanged(_ input: Notification){
        let curPage = pdfDocView.currentPage
        if curPage == nil {return}
        let curIndex: Int? = pdfDocView.document?.index(for: curPage!)
        if curIndex == nil {return}
        pageNumber.stringValue = String(curIndex!)
    }
    
    @IBOutlet var favouritesButton: NSButton!
    
    override func viewWillAppear() {
        guard let ob = representedObject as? TeXHelpDocument else {return}
        pdfDocView.document = ob.content.pdfDocument
        let size: Float = Float(pdfDocView.rowSize(for: ob.content.pdfDocument!.page(at: 0)!).width)
        let scaleFactor = CGFloat(380.0/size)
        pdfDocView.scaleFactor = scaleFactor
        pdfDocView.autoScales = true
        
        // receive notifications when the pdf document finds a match or changes page
        NotificationCenter.default.addObserver(self, selector: #selector(searchResultFound(_:)), name: .PDFDocumentDidFindMatch, object: pdfDocView.document)
        NotificationCenter.default.addObserver(self, selector: #selector(pageChanged(_:)), name: .PDFViewPageChanged, object: pdfDocView)
        NotificationCenter.default.addObserver(self, selector: #selector(searchResultNewPage(_:)), name: .PDFDocumentDidEndPageFind, object: pdfDocView)


        // initialise and configure the tables / outlines
        keywordTableViewData = ob.content.keywords
        keywordTableView.delegate = self as NSTableViewDelegate
        keywordTableView.dataSource = self as NSTableViewDataSource
        
        outlineViewData = ob.content.pdfDocument?.outlineRoot
        outlineView.delegate = self as NSOutlineViewDelegate
        outlineView.dataSource = self as NSOutlineViewDataSource

        searchTableView.delegate = self as NSTableViewDelegate
        searchTableView.dataSource = self as NSTableViewDataSource
        
        keywordTableView.target = self
        keywordTableView.doubleAction = #selector(doubleClickAction)
        let tmp = keywordTableViewData.sorted(by: {(a,b) -> Bool in
            return a.keys.first!.lowercased() < b.keys.first!.lowercased()
        })
        keywordTableViewData = tmp
        resizeColumn0()
        resizeOutline()
        
        //possible but looks naff. Other search options? e.g. sort by page or matches?
        let cellMenu = NSMenu(title: "Search Menu")
        let menuItemSortByPage = NSMenuItem(title: "Sort by page order", action: #selector(toggleSearchSortOrder), keyEquivalent: "")
        menuItemSortByPage.tag = 1
        menuItemSortByPage.state = .off
        cellMenu.addItem(menuItemSortByPage)
        let menuItemSortByRank = NSMenuItem (title: "Sort by search rank", action: #selector(toggleSearchSortOrder), keyEquivalent: "")
        menuItemSortByRank.tag = 2
        menuItemSortByRank.state = .on
        sortByRank = true  // assign default here for clarity
        cellMenu.addItem(menuItemSortByRank)
        searchField.searchMenuTemplate = cellMenu
        //keywordSearchButton.menu?.addItem(menuItemSortByPage)
        //keywordSearchButton.menu?.addItem(menuItemSortByRank)
    }
    
    @objc func toggleSearchSortOrder(sender: NSMenuItem) {
        
        let theSearchMenu = sender.menu
        switch sender.tag{
        case 1:
            sortByRank = false
            theSearchMenu?.item(withTag: 1)!.state = .on
            theSearchMenu?.item(withTag: 2)!.state = .off
        case 2:
            sortByRank = true
            theSearchMenu?.item(withTag: 1)!.state = .off
            theSearchMenu?.item(withTag: 2)!.state = .on
        default:
            break
        }
        sortSearchTableViewData()
        searchTableView.reloadData()
    }

    func control(_ control: NSControl, textShouldBeginEditing fieldEditor: NSText) -> Bool {
        let theField = control as? NSTextField
        if theField != searchField {return true}
        if searchField.textColor == .systemGray {
            searchField.textColor = .black
            searchField.stringValue = ""
            return false
        }
        //print(theField!.stringValue)
        return true
    }
    
//        func controlTextDidChange(_ obj: Notification) {
//            let theField = obj.object as? NSTextField
//            if theField != searchField {return}
//            if searchField.textColor == .systemGray {
//                searchField.textColor = .black
//                searchField.stringValue = ""
//            }
//
//            print(theField!.stringValue)
//        }
    
    
    override func viewDidAppear() {
        // register window so we know which 'files' are open
        self.view.window?.delegate = self
        let appDel = NSApplication.shared.delegate as! AppDelegate
        guard self.representedObject != nil else {return}
        let ob = self.representedObject as! TeXHelpDocument
        
        if appDel.openURIs[ob.content.fileURIString] == nil {
            appDel.openURIs[ob.content.fileURIString] = [ob.windowController.window!]
        }
        else{
            appDel.openURIs[ob.content.fileURIString]?.append(ob.windowController.window!)
        }
        
        if appDel.openURLs[ob.content.fileURLString] == nil {
            appDel.openURLs[ob.content.fileURLString] = [ob.windowController.window!]
        }
        else{
            appDel.openURLs[ob.content.fileURLString]?.append(ob.windowController.window!)
        }
        
        if appDel.favourites.contains(ob.content.fileURLString) {
            favouritesButton.state = .on
        }
        NSDocumentController.shared.noteNewRecentDocumentURL(URL(fileURLWithPath: URL(string:ob.content.fileURLString)!.path))
    }
    
    func windowWillClose(_ notification: Notification) {
        // de-register window so we know which 'files' are open
        let appDel = NSApplication.shared.delegate as! AppDelegate
        let ob = self.representedObject as! TeXHelpDocument
        let win = ob.windowController.window
        var allwin = appDel.openURIs[ob.content.fileURIString]!
        allwin.removeAll(where: { (a) -> Bool in
            return a == win
        })
        
        if allwin.count > 0 {
            appDel.openURIs[ob.content.fileURIString] = allwin
            appDel.openURLs[ob.content.fileURLString] = allwin
            
        }
        else {
            appDel.openURIs.removeValue(forKey: ob.content.fileURIString)
            appDel.openURLs.removeValue(forKey: ob.content.fileURLString)
            
        }
//        print("-------")
//        print(appDel.openURIs)
//        print(appDel.openURLs)
    }
    
    @objc func tableViewSelectionDidChange(_ notification: Notification) {
        let theTableView = notification.object as! NSTableView
        switch theTableView {
        case keywordTableView:
            keywordSelectionDidChange()
        case searchTableView:
            searchSelectionDidChange()
        default:
            break
        }
    }
    
    func searchSelectionDidChange() {
        let selectedRow = searchTableView.selectedRow
        if selectedRow < 0 {
            // user de-selected a row - turn off highlighting
            pdfDocView.highlightedSelections = nil
            pdfDocView.layoutDocumentView()
            return}
        if selectedRow >= searchTableViewData.count {return} //should never happen
        let thePage = searchTableViewData[selectedRow].keys.first
        guard thePage != nil else {return}
        let hits = searchTableViewData[selectedRow].values.first
        guard hits != nil else {                // this shouldn't happen!
            pdfDocView.highlightedSelections = nil
            pdfDocView.layoutDocumentView()
            return}
        for hit in hits! {
            hit.color = NSColor.yellow
        }
        pdfDocView.go(to: hits!.first!)
        pdfDocView.highlightedSelections = hits
        pdfDocView.layoutDocumentView()
    }
    
    func sortSearchTableViewData(){
        // re-sorts the search table view data, either by page number or by page rank
        if sortByRank {
            searchTableViewData.sort(by: {(row1,row2) -> Bool in
                row1.values.first!.count > row2.values.first!.count
                })
        }
        else {
            searchTableViewData.sort(by: {(row1,row2) -> Bool in
            row1.keys.first! < row2.keys.first!
            })
        }
        
    }
    
    func keywordSelectionDidChange(){
        let selectedRow = keywordTableView.selectedRow
        if selectedRow != -1 {
            let pageInt = keywordTableViewData[selectedRow].values.first
            let pagePDF = pdfDocView.document?.page(at: pageInt!)
            let destPDF = PDFDestination(page: pagePDF!, at: NSPoint(x: 0, y: 0))
            pdfDocView.go(to: destPDF)
            let td = self.representedObject as! TeXHelpDocument
            let keyword = keywordTableViewData[selectedRow].keys.first!
            let selections = td.content.keywordsSelections[keyword]
            var allSelections: [PDFSelection] = []
            var searchdict: [Int:[PDFSelection]] = [:]
            var firstHit = true
            for sel in selections! {
                let thisPage = sel[0]
                let location = sel[1]
                let length = sel[2]
                let pdfPage = pdfDocView.document?.page(at: thisPage)
                let thisSelection = pdfDocView.document?.selection(from: pdfPage!, atCharacterIndex: location, to: pdfPage!, atCharacterIndex: location + length)
                if firstHit {
                    pdfDocView.go(to: thisSelection!)
                    firstHit = false
                }
                thisSelection?.color = NSColor.yellow
                allSelections.append(thisSelection!)
                if searchdict[thisPage] == nil {
                    searchdict[thisPage] = [thisSelection!]
                }
                else {
                    searchdict[thisPage]!.append(thisSelection!)
                }
            }
            let out = searchdict.sorted(by: { (a,b) -> Bool in
                return a.value.count > b.value.count
            })
            searchTableViewDataKeywords = []
            for el in out {
                let tmp1 = el.key
                let tmp2 = el.value
                let tmp3 = [tmp1:tmp2]
                searchTableViewDataKeywords.append(contentsOf: [tmp3])
            }
            pdfDocView.highlightedSelections = allSelections
            pdfDocView.layoutDocumentView()
            return
        }
        
    }

    
    @objc func doubleClickAction(sender: AnyObject) {
        if (sender as? NSControl)?.identifier?.rawValue != "keywordTable" {
            return
        }
        let selectedRow = keywordTableView.selectedRow
        if selectedRow == -1 {
            return
        }
        searchField.stringValue = "TeX: " + keywordTableViewData[selectedRow].keys.first!
        searchField.textColor = .systemGray
        oldValue = searchField.stringValue
        searchTableViewData = searchTableViewDataKeywords
        sortSearchTableViewData()
        tabButton(searchTabButton)
        searchTableView.reloadData()
        searchTableView.selectRowIndexes(NSIndexSet(index: 0) as IndexSet, byExtendingSelection: false)
        //searchSelectionDidChange()
        self.view.window?.makeFirstResponder(searchTableView)
        //searchString.font?.fontDescriptor.symbolicTraits
    }

        
    @IBOutlet var searchField: NSSearchField!
    
    
    @IBAction func searchRequested(_ sender: Any) {
        
        let searchString = searchField.stringValue
        if searchString == oldValue {return}
        oldValue = searchString
        
        let myDoc = pdfDocView.document! as PDFDocument
        myDoc.cancelFindString()
        searchTableViewData = []
        searchTableView.reloadData()
        if searchString == "" {
            pdfDocView.highlightedSelections = nil
            pdfDocView.layoutDocumentView()
        }
        else {
            myDoc.beginFindString(searchString, withOptions: [NSString.CompareOptions.regularExpression])
        }
    }
    
    @objc func searchResultFound(_ input: Notification){
        //let id = tabView.selectedTabViewItem!.identifier
        //print(tabView.selectedTabViewItem!.identifier as! String)
        let theDoc = input.object as! PDFDocument
        //print(input.description)
        let sel = input.userInfo!["PDFDocumentFoundSelection"]! as! PDFSelection
        let thePage = sel.pages.first!
        let thePageIndex = theDoc.index(for: thePage)
        let theDataIndex = searchTableViewData.firstIndex(where: {
            $0.keys.first! == thePageIndex
        })
        
        if theDataIndex == nil {
            searchTableViewData.append([thePageIndex: [sel]])
        }
        else {
            searchTableViewData[theDataIndex!][thePageIndex]!.append(sel)
        }
        // results are now stored in the order in which the page first had a result. Let's resort
        
        sortSearchTableViewData()
        searchTableView.reloadData()
    }
    
    @objc func searchResultNewPage(_ input: Notification) {
        if tabView.selectedTabViewItem!.identifier as! String == "keyworkTabID"{
            pdfDocView.document?.cancelFindString()
            print("cancelled search")
        }
    }
    
    
}




    // might be handy for indexing of content-based files
//    func makeRelative(absoluteURL: URL, relativeToURL: URL) -> URL? {
//        // returns a relative and root URL, if its a child
//        let absPathC = absoluteURL.pathComponents
//        let relPathC = relativeToURL.pathComponents
//        let rootPathC = absPathC[0..<relPathC.count]
//        guard rootPathC.elementsEqual(relPathC) else {
//            return nil //absoluteURL is not a child of relativeToURL
//        }
//        let endPath = (absPathC[relPathC.count...]).joined(separator: "/")
//        let outURL = URL(fileURLWithPath: endPath, relativeTo: relativeToURL)
//        return outURL
//    }
