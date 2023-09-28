//
//    LandingPageViewController.swift
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
import Cocoa
import os.log
import CoreSpotlight

class LandingPageViewController: NSViewController {
    var appDel: AppDelegate = NSApplication.shared.delegate as! AppDelegate
    
    var resetConfig: Bool = false
    var resetAttempts: Int = 0
    enum ConfigStatus {
      case noAccess, noTLDB, noDocs, ok, resuming, notSet
    }
    var myState: ConfigStatus = .notSet
    @IBOutlet var splashText: NSTextField!
    
    @IBOutlet var nextButton: NSButton!

    
    override func viewDidLoad() {
        NotificationCenter.default.addObserver(self, selector: #selector(statusChanged(_:)), name: .statusNotification, object: nil)
        nextButton.isHidden=true
    }
    func setSplashText(_ txt: String) {
        DispatchQueue.main.async {self.splashText.stringValue = txt}
    }

    override func viewDidAppear() {
        appDel.landingPageViewController = self
        self.initialise()
        return()
    }
    
    /**
     open landing page
     
     check if entitlement exists         N= ---> informative message --> setup screen
     check if entitlement has a docs subfolder N= ---> informative message --> setup screen
     check if entitlement has a TLDB    N= ---> informative message --> setup screen
     initialising indexing...
     indexing in progress? Y =---> informative message --> continue
     has a last-opened document N= ---> informative message --> search screen
     load last-opened document
     close landing page
     */
    func initialise() {
        DispatchQueue.global().async() {
            DispatchQueue.main.async{self.nextButton.isHidden = true}
            self.setSplashText("\n\nChecking entitlements...")
//            sleep(1)
            if self.entitlementExistsAndValid() == false {
                self.myState = .noAccess
                self.setDirectory()
            }
            else {
                self.setSplashText("\n\nChecking docs folders exist...")
//                sleep(1)
                if self.docFoldersExist() == false {
                    self.myState = .noDocs
                    self.setDirectory()
                }
                else {
                    self.setSplashText("\n\nChecking TLDB exists")
//                    sleep(1)
                    if self.teXLiveDatabaseExists() == false {
                        self.myState = .noTLDB
                        self.setDirectory()
                    }
                    else {
                        self.setSplashText("\n\nInitialising TeXHelp...")
                        self.myState = .resuming
//                        sleep(1)
                        
                        os_log("Initialising",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Info"))
                        if self.appDel.myPersistentContainer == nil {
                            self.appDel.myPersistentContainer=MyPersistentContainer.init(load: true)
                        }
                        self.appDel.favourites = (UserDefaults.standard.array(forKey: "favourites") as? [String]) ?? (Array() as [String])
                        DispatchQueue.main.async{self.appDel.refreshFavouritesMenu()}
                        self.appDel.resumeIndexing()
//                        DispatchQueue.main.async {self.view.window?.close()}
                    }
                }
            }
        }
    }
    
    func setDirectory() {
        switch myState {
        case .noAccess:
            self.setSplashText(
                """
                Welcome to TeXHelp!
                
                TeXHelp indexes the help documents, in pdf format, from your TeXLive installation.
                
                To do this you must allow access to the TeXLive root folder.
                
                Press Next, then select the TeXLive root folder.
                
                The default TeXLive root folder is normally:
                /usr/local/texlive/<yyyy>
                """
            )
            DispatchQueue.main.async{self.nextButton.isHidden = false}
        case .noTLDB:
            self.setSplashText(
                """
                TeXHelp could not find the TeXLive Database, probably because the root folder was set incorrectly.
                Press Next, then select the TeXLive root folder.
                The default TeXLive root folder is normally:
                /usr/local/texlive/<yyyy>
                """
            )
            DispatchQueue.main.async{self.nextButton.isHidden = false}
        case .noDocs:
            self.setSplashText(
            """
            TeXHelp could not find the 'doc' subfolder, probably because the root folder was set incorrectly.
            Press Next, then select the TeXLive root folder.
            The default TeXLive root folder is normally:
            /usr/local/texlive/<yyyy>
            """
            )
            DispatchQueue.main.async{self.nextButton.isHidden = false}
        default:
            fatalError("shouldn't happen")
        }
    }
    

    @objc func statusChanged(_ input: Notification){
        // update views with new values as needed
        let status = input.object as! MyStatus
        switch status.myState {
        case .indexing:
            self.setSplashText(
                "\n\nIndexing is in progress, but you can still search the database. \n\nPress Next to open the search window."
            )
            DispatchQueue.main.async{self.nextButton.isHidden = false}
        case .completed:
            DispatchQueue.main.async {
                // if the splash window is still open then move to search window
                if (self.view.window != nil) {
                    self.performSegue(withIdentifier: "search", sender: self)
                    self.view.window?.close()
                }
            }
        default:
            break
        }
    }
    

    func myAlert(msg: String) {
        let alert = NSAlert()
        alert.messageText = msg
        alert.alertStyle = NSAlert.Style.warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @IBAction func next(_ sender: Any) {
        if myState == .resuming {
            self.performSegue(withIdentifier: "search", sender: self)
            self.view.window?.close()
            return
        }

        let defaultURL = URL(fileURLWithPath: "/usr/local/texlive/2015")
        let myPanel = NSOpenPanel()
        myPanel.canChooseFiles = false
        myPanel.canChooseDirectories = true
        myPanel.canCreateDirectories = false
        myPanel.allowsMultipleSelection = false
        myPanel.prompt = "Allow Access"
        myPanel.directoryURL = defaultURL
        let out = myPanel.runModal()
        if out == NSApplication.ModalResponse.OK {
            // quit?
            let chosenURL = myPanel.url as NSURL?
            let docLocation = NSURL(fileURLWithPath: "texmf-dist/doc/", isDirectory: true, relativeTo: myPanel.url)
            let reachable = FileManager().isReadableFile(atPath: docLocation.path!)
            if !reachable {
                myAlert(msg: "Chosen directory does not have the correct format")
                return
            }
            var entitledBookmarkData = Data()
            do {
                try entitledBookmarkData = chosenURL!.bookmarkData(options: NSURL.BookmarkCreationOptions.withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                UserDefaults.standard.set(entitledBookmarkData, forKey: "entitledBookmarkData") // saves the bookmark as data
                appDel.entitledURL = chosenURL // update the application
            }
            catch
            {
                myAlert(msg: "Could not set url")
                return
            }
//             we assume all the configuration needs resetting.
            do {
                try ConfigViewController.restoreDefaults(entitledURL: appDel.entitledURL!)
            }
            catch {
                myAlert(msg: "Problem setting default app configuration")
            }
            self.initialise()
        }
    }
    

    
    //MARK: - the helper functions for initiation
    func entitlementExistsAndValid() -> Bool{
        var stale: ObjCBool = true
        //entitledURL: NSURL
        var entitledBookmarkData: Data
        let tmpData = UserDefaults.standard.object(forKey: "entitledBookmarkData")
        if tmpData==nil {
            return false
        }

        entitledBookmarkData = tmpData as! Data
        do {
            try  appDel.entitledURL = NSURL(resolvingBookmarkData: entitledBookmarkData, options: NSURL.BookmarkResolutionOptions.withSecurityScope, relativeTo: nil, bookmarkDataIsStale:  &stale)
        }
        catch {
            //error scenario: for some reason we could not get a valid bookmark, perhaps because use has not yet granted access
            return false
        }
        if stale.boolValue {
            //your app should create a new bookmark using the returned URL and use it in place of any stored copies of the existing bookmark
            do {
                try entitledBookmarkData = appDel.entitledURL!.bookmarkData(options: NSURL.BookmarkCreationOptions.withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                UserDefaults.standard.set(entitledBookmarkData, forKey: "entitledBookmarkData")
                
            }
            catch
            {
                os_log("problem refreshing the bookmark, even though it was valid",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Error"))
                return false
            }
        }
        appDel.entitledURL!.startAccessingSecurityScopedResource()
        return true
    }
    

    func teXLiveDatabaseExists() -> Bool {
        let rootURL = appDel.entitledURL! as URL
        let dbLocation = NSURL(fileURLWithPath: "tlpkg/texlive.tlpdb", relativeTo: rootURL)
        let reachable = FileManager().isReadableFile(atPath: dbLocation.path!)
       
        return reachable
    }
    
    func docFoldersExist() -> Bool{
        let rootURL = appDel.entitledURL! as URL
        let docLocation = NSURL(fileURLWithPath: "texmf-dist/doc/", isDirectory: true, relativeTo: rootURL)
        let reachable = FileManager().isReadableFile(atPath: docLocation.path!)
        //print(docLocation)
        return reachable
    }
    
}
