//
//    TeXHelpDocTable.swift
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


extension TeXHelpDocViewController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        
        let cell = tableView.makeView(withIdentifier:
            (tableColumn!.identifier), owner: self) as? NSTableCellView
        if cell == nil {return nil}
        switch tableColumn!.identifier.rawValue {
        case "keyword":
            cell!.textField?.stringValue = keywordTableViewData[row].keys.first!
        case "page":
            cell!.textField?.stringValue = "\(keywordTableViewData[row].values.first!)"
        case "searchPagesID":
            guard row < searchTableViewData.count else {return nil}
            let pageInt = searchTableViewData[row].keys.first
            guard pageInt != nil else {return nil}
            cell!.textField?.stringValue = "Page \(pageInt!)"
            
        case "searchMatchesID":
            guard row < searchTableViewData.count else {return nil}
            let pageMatches = searchTableViewData[row].values.first!.count
            cell!.textField?.stringValue = "\(pageMatches) match\(pageMatches > 1 ? "es" : "")"
        default:
            break
        }
        return cell
    }
    
    func resizeColumn0() {
        var longest = CGFloat(0)
        let column = keywordTableView.tableColumns[0] as NSTableColumn
        for row in 0 ..< keywordTableView.numberOfRows {
            let view = keywordTableView.view(atColumn: 0, row: row, makeIfNecessary: true) as! NSTableCellView
            let width = view.textField!.attributedStringValue.size().width
            if (longest < width) {
                longest = width
            }
        }
        column.width = longest + 10
    }
}


extension TeXHelpDocViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        switch tableView.identifier!.rawValue {
        case "keywordTable":
            return keywordTableViewData.count
        case "searchTable":
            return searchTableViewData.count
        default:
            return 0
        }
    }
}



