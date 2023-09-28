//
//    TeXHelpDocOutline.swift
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

extension TeXHelpDocViewController: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return outlineViewData!.child(at: index)!
        }
        guard let ob = item as? PDFOutline else {fatalError()}
        return ob.child(at: index)!
    }
    
    func resizeOutline() {
        var longest = CGFloat(0)
        let column = outlineView.tableColumns[0] as NSTableColumn
        for row in 0 ..< outlineView.numberOfRows {
            let view = outlineView.view(atColumn: 0, row: row, makeIfNecessary: true) as! NSTableCellView
            let width = view.textField!.attributedStringValue.size().width
            if (longest < width) {
                longest = width
            }
        }
        column.width = longest + 20
        
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let ob = item as? PDFOutline else {fatalError()}
        if ob.numberOfChildren > 0 {return true}
        return false
    }
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil { // this is  the parent item
            if outlineViewData == nil { //there are no bookmarks in the document, e.g. pst-lens.pdf
                return 0
            }
            return outlineViewData!.numberOfChildren
        }
        guard let ob = item as? PDFOutline else {fatalError()}
        return ob.numberOfChildren
    }
    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        guard let ob = item as? PDFOutline else {fatalError()}
        return ob.description
    }
}


extension TeXHelpDocViewController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let cell = (outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "pdfOutlineID"), owner: self) as? NSTableCellView)!
        guard let ob = item as? PDFOutline else {fatalError()}
        cell.textField?.stringValue = ob.label ?? "<empty>"
        cell.objectValue = item
        return cell
    }
    
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        let ind = outlineView.selectedRow
        if ind < 0 {return}
        let item = outlineView.item(atRow: ind) as! PDFOutline
        guard item.destination != nil else { //TODO: deal with action items? e.g. remote go to?
            if item.action?.className == "PDFActionRemoteGoTo" {
                let action = item.action as! PDFActionRemoteGoTo
                let newDoc = TeXHelpDocument(fromURL: action.url.standardized.absoluteString)
                let pdfDoc = newDoc?.contentViewController?.pdfDocView.document
                let pdfPage = pdfDoc?.page(at: action.pageIndex)
                let dest = PDFDestination(page: pdfPage!, at: action.point)
                newDoc?.contentViewController?.pdfDocView.go(to: dest)
            }
            return} // happens if the 'outline' item was an action, not a bookmark. See for example glue.pdf
        pdfDocView.go(to: item.destination!)
        
    }
    
    
    func outlineViewItemWillCollapse (_ notification: Notification) {
                //resizeOutline() // TODO only needs to run if outlineView outline level changed?
    }
    
    func outlineViewItemWillExpand (_ notification: Notification) {
                resizeOutline() // TODO only needs to run if outlineView outline level changed?
    }
    
}
