//
//  MyPersistentContainer.swift
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
import CoreData
import os.log
import AppKit



class MyPersistentContainer: NSPersistentContainer {
    // TODO: as a workaround the team identifer is added to the plist file so that the containerURL can be found programmatically.
//    static let sharedUrl =
//        FileManager.default.containerURL(
//            forSecurityApplicationGroupIdentifier:(
//                Bundle.main.infoDictionary!["TeamIdentifierPrefix"] as! String)
//                + "group.com.TeXHelp"
//        )!
    //var mainLog: OSLog = (NSApplication.shared.delegate as! AppDelegate).mainLog
    
    init () {
       // The managed object model for the application. It is a fatal error for the application not to be able to find and load its model.
        guard let modelURL = Bundle.main.url(forResource: "TeXHelp", withExtension:"momd") else {
            fatalError("Error loading model from bundle")
        }
        os_log("Loaded database %{public}s",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Info"), modelURL.absoluteString)
        guard let mom = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Error initializing mom from: \(modelURL)")
        }
//        if let path = Bundle.main.path(forResource: "YourProjectName", ofType: "entitlements") {
//            let dict = NSDictionary(contentsOfFile: path)
//            let appGroups: NSArray = dict?.object(forKey: "com.apple.security.application-groups") as! NSArray
//        }
        // The Persistent Container Name is hard coded:
        super.init(name: "TeXHelp", managedObjectModel: mom)
        
        // Enforce spotlight search interface (is this only needed for a new store?)
        for storeDescription in self.persistentStoreDescriptions {
            storeDescription.setOption(true as NSNumber,forKey: NSPersistentHistoryTrackingKey)
            storeDescription.setOption(MyCoreDataCoreSpotlightDelegate(forStoreWith:storeDescription, model: mom), forKey:NSCoreDataCoreSpotlightExporter)
        }
        os_log("Persistent container loaded and initialised",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Info"))
        
        self.viewContext.undoManager = nil
    }
    
    convenience init (load: Bool) {
        self.init()
        if load {
            self.lazyload()
        }
        os_log("Finished initialisation of the store",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Info"))
    }
    
    func lazyload (){
        //if self.persistentStoreDescriptions == nil {
        self.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                 
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                // https://www.sqlite.org/rescode.html
                DispatchQueue.main.async {
                    
                    
                    let myAlert = NSAlert()
                    myAlert.alertStyle = NSAlert.Style.critical
                    myAlert.messageText = "Error with the database.\nThe application will quit."
                    myAlert.showsHelp = false
                    myAlert.addButton(withTitle: "OK")
                    
                    switch error._domain {
                    case "NSSQLiteErrorDomain":
                        myAlert.informativeText = "The following error occured during database loading:\n"
                        + error.localizedDescription
                        + "\nSee https://www.sqlite.org/rescode.html for further details"
                    default:
                        myAlert.informativeText = "The following error occured during database loading:\n"
                        + error.localizedDescription
                    }
                    os_log("%{public}@", log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Error"), error.localizedDescription)
                    myAlert.runModal()
                    NSApplication.shared.terminate(self)
                }
            }
        })
        os_log("loaded persistent stores from %{public}@ ",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Info"),MyPersistentContainer.defaultDirectoryURL().absoluteString)
    
    }

//    override class func defaultDirectoryURL() -> URL {
//        os_log(OSLogType.info,"Setting default directory URL to %{public}s", sharedUrl.absoluteString)
//        return sharedUrl
//    }
}
