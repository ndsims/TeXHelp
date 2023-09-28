//
//    AppDelegate.swift
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
import CoreSpotlight
import CoreData
import os.log





@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSAlertDelegate {

    @IBAction func loadHelp(_ sender: Any) {
        if let fileURL = Bundle.main.url(forResource: "TeXHelpUserGuide", withExtension:"pdf"){
            self.loadDoc(withURL: fileURL.absoluteString)}
    }
    
//    lazy var myPersistentContainer: MyPersistentContainer = {
//       MyPersistentContainer()
//    }()
    var myPersistentContainer: MyPersistentContainer?
    var entitledURL: NSURL?
    var favourites: [String] = Array()
    //var recents: [String] = Array()
    var openURIs: [String:[NSWindow]] = [:] //windows associated with a URI string
    var openURLs: [String:[NSWindow]] = [:] //windows associated with a fileURL String
    var myIndexer: MyIndexer?
    var operationQueue: OperationQueue = OperationQueue()
    var coreSpotlightIndex: CSSearchableIndex = CSSearchableIndex(name: "com.TeXHelp.TeXHelp")
    var lastStatus: MyStatus = MyStatus()

    var statusViewController: StatusViewController?
    var landingPageViewController: LandingPageViewController?
    var mainLog: OSLog = OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Main")
    var indexLog: OSLog = OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Index")
    
    @IBOutlet var recentsMenu: NSMenuItem!
    @IBOutlet weak var favouritesMenu: NSMenuItem!
    
    
    @objc func statusChanged(_ input: Notification){
        // update views with new values as needed
        let status = input.object as! MyStatus
//        if status.myState != lastStatus.myState {
//            os_log(OSLogType.info,"Status changed: %{public}@, %{public}@",status.description(),status.mySummaryText)
//        }
//        else {
//            os_log(OSLogType.info,"Status: %{public}@, %{public}@",status.description(),status.mySummaryText)
//        }
        DispatchQueue.main.async {
            self.lastStatus = status
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
        
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        

        NotificationCenter.default.addObserver(self, selector: #selector(statusChanged(_:)), name: .statusNotification, object: nil)

    }
    
/*
    // helpful for debugging: disable the segue and connect this to the 'search' button...
    @IBAction func search(_ sender: Any) {
        _ = loadDoc(withURL: "file:///usr/local/texlive/2018/texmf-dist/doc/generic/pst-func/pst-func-doc.pdf")
           print("appdel opened")
       }
*/
    

    @IBAction func loadPreferences(_ sender: Any?) {
        stopIndexing()
        statusViewController?.performSegue(withIdentifier: "configureSegue", sender: sender)
    }
    
    

    //MARK: - the document loading functions
    
    func loadDoc(withURI: String) -> TeXHelpDocument? {
        if openURIs[withURI] != nil {
            self.openURIs[withURI]?.first?.windowController!.showWindow(self)
            return nil //TODO: get doc object?
        }
        else {
            
            let THD = TeXHelpDocument(fromURI: withURI)
            if THD == nil {return nil}
            return THD
        }
    }


    
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        os_log("loading file: %{public}@", log:OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "App"),filename)

        let thisURLString = URL(fileURLWithPath: filename).absoluteString
        let THD =  loadDoc(withURL: thisURLString)
        if THD != nil {return true}
        return false
    }
    
    @objc func loadDocFromMenuItem(_ sender: NSMenuItem) {
        
        let withURL = sender.representedObject as! String
        _ = loadDoc(withURL: withURL)
     }

    func loadDoc(withURL: String) -> TeXHelpDocument? {
        os_log("loading URL: %{public}@", log:OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "App"),withURL)
        if self.myPersistentContainer == nil {
            os_log("loading persistent containers first", log:OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "App"))
            self.myPersistentContainer=MyPersistentContainer.init(load: true)
        }
        if openURLs[withURL] != nil {
            self.openURLs[withURL]?.first?.windowController!.showWindow(self)
            return nil // TODO (self.openURLs[withURL]?.first)
        }
        else {
            let THD = TeXHelpDocument(fromURL: withURL)
            if THD == nil {return nil}
            return THD
        }
    }

    
    //MARK: - update the favourites menu
    
    func refreshFavouritesMenu () {
        favouritesMenu.submenu?.removeAllItems()
        for fav in favourites {
            let thisFile = URL(string:fav)?.lastPathComponent
            if thisFile == nil {continue}
            let thisItem = NSMenuItem(title: thisFile!, action: #selector(loadDocFromMenuItem(_:)), keyEquivalent: "")
            //thisItem.target = fav as AnyObject
            thisItem.isEnabled = true
            thisItem.representedObject = fav as Any
            favouritesMenu.submenu?.addItem(thisItem)
        }
    }
    //MARK: - the application termination / closing the database
    @IBAction func close(_ sender: Any) {
        NSApplication.shared.terminate(self)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Save changes in the application's managed object context before the application terminates.
        if let context = myPersistentContainer?.viewContext {
            
            if !context.commitEditing() {
                NSLog("\(NSStringFromClass(type(of: self))) unable to commit editing to terminate")
                return .terminateCancel
            }
            
            if !context.hasChanges {
                return .terminateNow
            }
            
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                
                // Customize this code block to include application-specific recovery steps.
                let result = sender.presentError(nserror)
                if (result) {
                    return .terminateCancel
                }
                
                let question = NSLocalizedString("Could not save changes while quitting. Quit anyway?", comment: "Quit without saves error question message")
                let info = NSLocalizedString("Quitting now will lose any changes you have made since the last successful save", comment: "Quit without saves error question info");
                let quitButton = NSLocalizedString("Quit anyway", comment: "Quit anyway button title")
                let cancelButton = NSLocalizedString("Cancel", comment: "Cancel button title")
                let alert = NSAlert()
                alert.messageText = question
                alert.informativeText = info
                alert.addButton(withTitle: quitButton)
                alert.addButton(withTitle: cancelButton)
                
                let answer = alert.runModal()
                if answer == .alertSecondButtonReturn {
                    return .terminateCancel
                }
            }
            // If we got here, it is time to quit.
        }
        return .terminateNow
    }

    //MARK: - indexer management functions
    
    

    func stopIndexing(){
        operationQueue.cancelAllOperations()
        operationQueue.waitUntilAllOperationsAreFinished()
    }
    
    
    
    func resumeIndexing () {
        
        // indexer - should belong to the context view; as it is reinitialised
        //        appDel.myPersistentContainer.persistentStoreCoordinator.
        myIndexer = MyIndexer(withManagedObjectContext: myPersistentContainer!.newBackgroundContext(),withdefaultTeXRootURL: entitledURL! as URL)
        operationQueue = OperationQueue()
        operationQueue.qualityOfService = .utility
        operationQueue.addOperation(myIndexer!)
    }
    

    
    

    //MARK: -  the spotlight loading interface
    
    func application(_ application: NSApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([NSUserActivityRestoring]) -> Void) -> Bool {
        if userActivity.activityType == CSSearchableItemActionType {
            guard let selectedItem = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
                // if there was no user info then we can't do anything so we exit
                return false
            }
            let uri = URL(string: selectedItem)
            guard uri != nil else {
                os_log("Spotlight handoff request failed: %{public}@",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Error"),uri!.absoluteString)
                return true}
            os_log(OSLogType.info,"Spotlight handoff request: %{public}@",uri!.absoluteString)
            myPersistentContainer=MyPersistentContainer.init(load: true)
            let coordinator = myPersistentContainer!.persistentStoreCoordinator
            let context = myPersistentContainer!.viewContext
            // what if we find nil? quite safely...
            let ob = coordinator.managedObjectID(forURIRepresentation: uri!)
            guard ob != nil else{
                os_log("Managed object does not exist for %{public}@", log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Error"),uri!.absoluteString)
                return true
            }
            let myEntry: HelpDoc? = context.object(with: coordinator.managedObjectID(forURIRepresentation: uri!)!) as? HelpDoc
            guard myEntry != nil else {
                os_log("Managed object was not a HelpDoc",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Error"))
                return true
            }
            let theFilePath = URL(string: myEntry!.fileURLString!)!.path
            os_log("Handoff file to open: %{public}@", log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Info"), theFilePath )
            //             NSWorkspace.shared.openFile(theFilePath)
            // if the URI is open, activate the window:
            _ = loadDoc(withURI: selectedItem)
        }
        return true
    }
    
}
    


