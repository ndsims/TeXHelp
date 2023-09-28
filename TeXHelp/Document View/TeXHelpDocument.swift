//
//    TeXHelpDocument.swift
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
import Quartz
import Foundation
import CoreData
import os.log


class TeXHelpContent {
    // translates Managed Object into soemthing easier to work with...
    // fileURLString is not optional in the database
    var fileURLString: String
    var fileURIString: String
    var packageLongDescription: String?
    var packageName: String?
    var packageShortDescription: String?
    var language: String?
    var details: String?
//    var page0PDFData: Data?
    var title: String?
    var keywords: [[String:Int]] = []
    var pdfDocument: PDFDocument?
    var keywordsSelections: [String:[[Int]]] = [:] // array of [page, sel, length]
    
    init(withFileURLString: String, withfileURIString: String){
        fileURLString = withFileURLString
        fileURIString = withfileURIString
    }
}

class TeXHelpDocument  {
    // like a document, but with no file association.
    var windowController: TeXHelpWindowController
    var appDel: AppDelegate
    var contentViewController: TeXHelpDocViewController? // override with my own view controller
    var content: TeXHelpContent
    
    
    init? (fromURI fromManagedObjectURIString: String) {
        // loads a document based on a string representation of the URI (e.g. as returned by spotlight)
        appDel = NSApplication.shared.delegate as! AppDelegate
        let coordinator = appDel.myPersistentContainer!.persistentStoreCoordinator
        let context = appDel.myPersistentContainer!.viewContext
        guard let thisURL = URL(string:fromManagedObjectURIString) else {return nil}  // exit if no valid URI
        guard let thisObjectID = coordinator.managedObjectID(forURIRepresentation: thisURL) else {return nil} // exit if no valid store
        var myHelpDoc: HelpDoc
        do {
            myHelpDoc = try context.existingObject(with: thisObjectID) as! HelpDoc
        }
        catch {
            return nil // exit if no
        }
        content = TeXHelpContent(withFileURLString: myHelpDoc.fileURLString!, withfileURIString: fromManagedObjectURIString)
        content.packageLongDescription = myHelpDoc.packageLongDescription
        content.packageName = myHelpDoc.packageName
        content.packageLongDescription = myHelpDoc.packageShortDescription
        content.title = myHelpDoc.title
        guard let doc = PDFDocument(url: URL(string: content.fileURLString)!) else {
            // fails if no entitlement
            return nil
        }
        content.pdfDocument = doc
        let keywords = myHelpDoc.value(forKey: "keywords") as! Set<Keyword>
        var myKeywords: [String:Int] = [:]
        for keyword in keywords {
            let keyval = keyword.value(forKey: "keyword") as! String
            let keypag = keyword.value(forKey: "bestHit") as! Int
            myKeywords[keyval] = keypag
            content.keywords.append([keyval: keypag])
            let data = keyword.value(forKey: "keywordData") as! Data
            do {
                let dataArray = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as! [[Int]]
                content.keywordsSelections[keyval as String] = dataArray
            }
            catch {
                
            }
        }
        
        
        let storyboard = NSStoryboard(name: NSStoryboard.Name("MainStoryboard"), bundle: nil)
        windowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("Document Window Controller")) as! TeXHelpWindowController
        // Set the view controller's represented object as your document.
        if let contentVC = windowController.contentViewController as? TeXHelpDocViewController{
            contentVC.representedObject = self
            contentViewController = contentVC
        }
        windowController.window?.title = URL(string:content.fileURLString)!.lastPathComponent
        windowController.showWindow(self)

        //print(appDel.openURLs)
    }
    

    
    convenience init?(fromURL fileURLString: String) {
        // loads a document based on its file string representation, if this exists in the database
        let tmpAppDel = NSApplication.shared.delegate as! AppDelegate
        let context = tmpAppDel.myPersistentContainer!.viewContext
        let request = NSFetchRequest<NSManagedObjectID>(entityName: "HelpDoc")
        request.resultType = .managedObjectIDResultType
        // just fetch the keywords for the selected item
        let myPredicate = NSPredicate(format: "fileURLString == %@", argumentArray: [fileURLString as Any])
        request.predicate = myPredicate
        var out: [NSManagedObjectID]
        do {
            out = try context.fetch(request)
            if out.count == 0 {
                return nil
            }
        } catch {
            return nil
        }
        self.init(fromURI: out[0].uriRepresentation().absoluteString)
    }
    
    
    

}


