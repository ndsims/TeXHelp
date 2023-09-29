//
//    MyIndexer.swift
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
import CoreData
import os.log
import CoreSpotlight

/**
 This class is used for the main indexing task
 1. initialise (the `getIndexList` function) to determine which files need adding / removing from the database
 2. enqueue operations to add each file (in the main function)
 3. display status as we go (using the MyStatus class).
 
 Both the indexer and the enqueued operations run as separate threads using the Operation class.
 */
class MyIndexer: Operation {
    // all these objects are required for the indexer to run
    let myManagedObjectContext: NSManagedObjectContext    // my access to the Core Data
    var defaultTeXRootURL: URL
    var defaultHelpRootURL: URL
    var teXLivePackageDatabase: TeXLivePackageDatabase? // my interpretation of the TeXLive package database
//    var pdfPreview: Bool
    /**
     status object
     */
    var status: MyStatus = MyStatus()
    
    init(withManagedObjectContext: NSManagedObjectContext, withdefaultTeXRootURL: URL){
        //https://developer.apple.com/documentation/coredata/using_core_data_in_the_background
        //myManagedObjectContext = withPersistentContainer.viewContext // newBackgroundContext() - in the calling function
        myManagedObjectContext = withManagedObjectContext
        defaultTeXRootURL = withdefaultTeXRootURL
        defaultHelpRootURL = URL(fileURLWithPath: "texmf-dist/doc/", isDirectory: true, relativeTo: defaultTeXRootURL)
//        pdfPreview = UserDefaults.standard.bool(forKey: "pdfPreview")
        myManagedObjectContext.undoManager = nil
        super.init()
    }
    
    
    /**
     Determines which files to index, and remove extraneous files from the database

     Returns:
- `infFilesToIndex`files to index using just the texlive database info
- `conFilesToIndex` files to index using contents as well as texlive database info
- `nDeleted` number of files deleted from the database during the cleanup operation
- `nDocsInDabase` number of files in the database that don't need indexing
     */
    func getIndexList() -> (
        infFilesToIndex:Set<String>,
        conFilesToIndex:Set<String>,
        nDeleted:Int,
        nDocsInDatabase:Int) {
        status.myStatusText = ""
        status.myProgressBar = 0
        status.mySummaryText = "Searching for pdf files..."
        status.myState = .starting
        os_log("Searching for pdf files...",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Indexer"))
        //myManagedObjectContext.retainsRegisteredObjects = false
        myManagedObjectContext.undoManager = nil
        //MARK: get all the files that need to be in the index, as strings relative to the HelpRootURL
        var infFilePaths: Set<String> = [] // file paths for file info only
        var conFilePaths: Set<String> = [] // file paths for file contents
        var allHelpDocs:Set<HelpDoc> = [] // all objects in database
        var conHelpDocs:Set<HelpDoc> = [] // contents searched and in database
        var infHelpDocs:Set<HelpDoc> = [] // file info only and in database
        var nDeleted:Int = 0 //count deleted files
        var nDocsInDatabase:Int = 0 //count existing database entries
        myManagedObjectContext.performAndWait {
            let contentsFileDirectories = UserDefaults.standard.array(forKey: "indexKeywordsPathStrings") as? [String] ?? []
            let infoFileDirectories = (UserDefaults.standard.array(forKey: "indexFileInfoPathStrings") as? [String]) ?? []
            
            // populate filePaths:
            for relPath in contentsFileDirectories {
                let myURL = URL(fileURLWithPath: relPath, isDirectory: true, relativeTo: defaultHelpRootURL)
                let dirEnumerator = FileManager().enumerator(atPath: myURL.path)
                while let file = dirEnumerator?.nextObject() as? String {
                    if file.lowercased().hasSuffix(".pdf") {
                        conFilePaths.insert(URL(fileURLWithPath: file, relativeTo: myURL).path)
                    }
                }
            }
            // populate filePaths:
            for relPath in infoFileDirectories {
                let myURL = URL(fileURLWithPath: relPath, isDirectory: true, relativeTo: defaultHelpRootURL)
                let dirEnumerator = FileManager().enumerator(atPath: myURL.path)
                while let file = dirEnumerator?.nextObject() as? String {
                    if file.lowercased().hasSuffix(".pdf") {
                        infFilePaths.insert(URL(fileURLWithPath: file, relativeTo: myURL).path)
                    }
                }
            }

            //MARK: get all the objects currently in the database, and delete any outside the search path:
            status.mySummaryText = "Searching for existing database entries..."
            status.post()
            let request = NSFetchRequest<HelpDoc>(entityName: "HelpDoc")
            request.propertiesToFetch = ["fileURLString"]
            do {
                allHelpDocs = Set(try myManagedObjectContext.fetch(request))
                //allHelpDocsSet = Set(allHelpDocs)
            } catch {
                os_log("Core data fetch threw an error",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "IndexerError"))
                fatalError()
            }
            conHelpDocs = (try?
                           allHelpDocs.filter({(A:HelpDoc) throws -> Bool in return A.contentsSearched })
            ) ?? []
            infHelpDocs = (try?
                           allHelpDocs.filter({(A:HelpDoc) throws -> Bool in return A.contentsSearched==false })
            ) ?? []
            status.mySummaryText = "Deleting unrequired database entries..."
            status.post()
            // create a set of conHelpdocs that are not in the file contents search path, and delete them
            var delDocs:Set<HelpDoc>
            delDocs = (try? conHelpDocs.filter({(A:HelpDoc) throws -> Bool in
                let urlString = A.fileURLString ?? ""
                let path = URL(string: urlString)?.path ?? ""
                let test = conFilePaths.contains(path) == false
                return test
            })
            ) ?? []
            for delDoc in delDocs {
                os_log("%{public}@ marked for deletion",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Indexer"),delDoc.fileURLString!)
                myManagedObjectContext.delete(delDoc)
                nDeleted += 1
            }
            // create a set of infHelpdocs that are not in the file contents info path, and delete them
            delDocs = (try? infHelpDocs.filter({(A:HelpDoc) throws -> Bool in
                let urlString = A.fileURLString ?? ""
                let path = URL(string: urlString)?.path ?? ""
                let test = infFilePaths.contains(path) == false
                return test
            })
            ) ?? []
            for delDoc in delDocs {
                os_log("%{public}@ marked for deletion",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Indexer"),delDoc.fileURLString!)
                myManagedObjectContext.delete(delDoc)
                nDeleted += 1
            }
            // save the core database
            status.mySummaryText = "Saving database..."
            status.post()
            do {
                try myManagedObjectContext.save()
                status.mySummaryText = "Saved core data"
                status.post()
            } catch {
                status.mySummaryText = "Failed to save core data"
                status.post()
            }
            // re-obtain all the help docs in the database
            do {
                allHelpDocs = Set(try myManagedObjectContext.fetch(request))
            } catch {
                os_log("Core data fetch threw an error",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "IndexerError"))
                fatalError()
            }
            nDocsInDatabase = allHelpDocs.count
        }
        // extract the docs path from the helpdocs
        let infHelpDocsPaths = (try?
                                infHelpDocs.map({(A:HelpDoc) throws -> String in return
            (URL(string: A.fileURLString ?? "")?.path ?? "")
            
        })
        ) ?? []
        let conHelpDocsPaths = (try?
                                conHelpDocs.map({(A:HelpDoc) throws -> String in return
            (URL(string: A.fileURLString ?? "")?.path ?? "")
        })
        ) ?? []
        // get the list of paths that should not be indexed
            let badList:Set<String> = Set((UserDefaults.standard.array(forKey: "badlistPathStrings") as? [String] ?? []) )
            // generate list of files to index
            var infFilesToIndex = infFilePaths.subtracting(infHelpDocsPaths).subtracting(badList)
            let conFilesToIndex = conFilePaths.subtracting(conHelpDocsPaths).subtracting(badList)
            if let myHelpURL  = Bundle.main.url(forResource: "TeXHelpUserGuide", withExtension:"pdf") {
                let myHelp = myHelpURL.path
                infFilesToIndex.formUnion(Set([myHelp]))
            }
            return (infFilesToIndex,conFilesToIndex,nDeleted,nDocsInDatabase)
        }
    
    /**
     Some files might cause Preview (or AppKit) to hang rather than just not be openable. This function attampts to trap this scenario and to add the file to the badlist.
     
     - parameters:
        - badfilepath: file path to be added to the exclude list, in the UserDefaults plist
     */
    func badFile (badFilePath: String)   {
    
        DispatchQueue.main.async {
            let newAlert = NSAlert()  //main thread only
            newAlert.messageText = "This file is broken"
            newAlert.informativeText = """
            The file:
            \(badFilePath)
            could not be loaded by the MacOS PDF viewer.
            
            It has been added to the excluded list of files for indexing.
            
            TeXHelp will quit, but the file will be skipped when you restart TeXHelp.
            """
            newAlert.runModal()
            var newList = UserDefaults.standard.array(forKey: "badlistPathStrings")
            if newList == nil {
                newList = [badFilePath]
            }
            else{
                newList?.append(badFilePath)
            }
            UserDefaults.standard.set(newList, forKey: "badlistPathStrings")
                      
            NSApplication.shared.terminate(self) //main thread only
        }
    }
    
    /**
     queries spotlight to obtain number of entries
     */
    func countSpotlightEntries () -> Int {
        let queryString = "title==*"
        let query = CSSearchQuery(queryString : queryString,
                              attributes : ["title"])
        var nSpotlightEntries = 0
        var completed = false
        query.completionHandler = { (error) -> Void in
            if error != nil {
                switch error!._domain {
                case CSSearchQueryErrorDomain:
                    print(error.debugDescription)
                default:
                    break
                }
            }
            nSpotlightEntries = query.foundItemCount
            completed = true
        }
        query.start()
        //TODO: if this hangs then we can't pause the indexing!
        var n = 0
        while (completed == false && (n < 100)){
            usleep(10000)
            n += 1
        }
        if n == 100 {
            os_log("Spotlight timeout when trying to countSpotlightEntries",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "IndexerError"))
        }
        return nSpotlightEntries
    }
    
    /**
     attempts to refresh the spotlight index.
     
     This has been rewritten a few times as it's not clear how best to trigger re-indexing.
     Reindexing seems to be needed when the index 'expires'
     this version just uses the 'startSpotlightIndexing()' function without deleting the previous / existing spotlight index
     */
    func newReIndexSpotlight() {
        let mcdcse: MyCoreDataCoreSpotlightDelegate = myManagedObjectContext.persistentStoreCoordinator!.persistentStores[0].options!["NSCoreDataCoreSpotlightExporter"] as! MyCoreDataCoreSpotlightDelegate
        var nHelpDocs: Int = 0
        let request = NSFetchRequest<HelpDoc>(entityName: "HelpDoc")
        do {
            nHelpDocs = try myManagedObjectContext.count(for: request)
        } catch {
            os_log("Core data fetch threw an error",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "IndexerError"))
            fatalError()
        }
        mcdcse.startSpotlightIndexing()
        var waitingForSpotlight = true
        while (waitingForSpotlight == true) {
            let nSpots = self.countSpotlightEntries()
            status.myProgressBar = Double(nSpots)/Double(nHelpDocs) * 100.0
            status.post()
            usleep(20000) // should work because re-indexing is on a different thread?
            if nSpots == nHelpDocs {waitingForSpotlight = false}
        }
        status.myProgressBar = 100.0
        status.post()

    }
    
    /**
     main indexing operation.
     
     1. obtains list of files to index (`getIndexList` function)
     2. for each file to add, gets the TeXLive database info, and optionally searches the file contents
     3. creates a new core data object and adds it to the database
     
     steps 2 is performed on an operation queue so that indexing can be paused / resumed.
     step 2 includes a timeout check in case the searching hangs
     */
    override func main() {
        let (infFilesToIndex,conFilesToIndex,nDeleted,nExisting) = getIndexList()
        let docsToAdd = infFilesToIndex.union(conFilesToIndex)
        
        if (nDeleted > 0) { // to debug set >=0 instead of >0
            status.mySummaryText = "\(nDeleted) Files deleted from the Core Database. Spotlight index will be refreshed..."
            status.myState = .indexing
            self.newReIndexSpotlight()
        }
        //print(myManagedObjectContext.registeredObjects.count)
        let nFilesToIndex = docsToAdd.count
        
        os_log("%{public}d files to index",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Indexer"),nFilesToIndex)
        if self.isCancelled {return}
        var nProcessed = 0
        var msg:String = ""
        var THD:TeXHelpData?
        let myQ = OperationQueue() //operation queue to use for each indexing task
        myQ.qualityOfService = .utility
        //status.myState = .indexing
        let stripPathCount = defaultHelpRootURL.pathComponents.count // base path component length to strip off the messages
        if docsToAdd.count > 0 { // only parse TLDB database if necessary
            status.mySummaryText = "Parsing the package database"
            status.myProgressBar = 0.0
            status.myState = .indexing
            os_log("Parsing the package database",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Indexer"))
            teXLivePackageDatabase = TeXLivePackageDatabase(fromRootURL: defaultTeXRootURL)
            //TODO: report existing files somewhere
            status.mySummaryText = "Processing \(nFilesToIndex) Files. \n\(nExisting) files were already indexed, or excluded."
        }
        for docToAdd in docsToAdd {
            //autoreleasepool{
            let msgStat = URL(fileURLWithPath: docToAdd).pathComponents[stripPathCount...]
            
            status.myStatusText = msgStat.joined(separator: "/")
            status.post()
            let indexInfoOnly =  infFilesToIndex.contains(docToAdd)
            os_log("Processing %{public}@ %{public}@",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Indexer"),status.myStatusText, indexInfoOnly == true ? "(file only)" : "")
            status.myProgressBar = Double(Double(nProcessed) / Double(nFilesToIndex) * 100)
            status.post()
            // add each operation to seperate queue
            myQ.addOperation{
                THD = MyIndexer.createNewTHDObject(withPath: docToAdd, theLivePackageDatabase: self.teXLivePackageDatabase!, indexFileInfoOnly: indexInfoOnly)
            }
            //TODO: badFile timeout checking is rudimentary
            // If PDFKit (the built in pdf engine) hangs silently, then the whole program hangs
            // to avoid this, we only add one item to the queue at a time
            // and we only allow the item to run for 100 seconds
            // if this time is exceeded, then the file is added to the exclude list (via badfile function)
            // and the whole programme terminates
            var attempts = 0
            while myQ.operationCount > 0 {
                usleep(20000)
                attempts += 1
                if attempts > 5000 {
                    badFile(badFilePath: docToAdd)
                    return
                }
            }
            myQ.waitUntilAllOperationsAreFinished() // this ensures only one item is added at a time
            if THD != nil {
                // if the indexer successfully created a new data object, then add it to the core data:
                MyIndexer.createCoreData(withTHData: THD!, theManagedobjectContext: myManagedObjectContext)
            }
            nProcessed += 1
            //}
            //sleep(1)
            // 'pausing' occurs by setting .isCancelled on the operation. If this occurs then we stop looping
            if self.isCancelled {break}
        }
        
        // count the number of core data objects, to give a status summary
        let request = NSFetchRequest<HelpDoc>(entityName: "HelpDoc")
        request.propertiesToFetch = ["fileURLString"]
        var nFiles: Int = 0
        do {
            let allHelpDocs = Set(try myManagedObjectContext.fetch(request))
            nFiles = allHelpDocs.count
            //allHelpDocsSet = Set(allHelpDocs)
        } catch {
            os_log("Core data fetch threw an error",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "IndexerError"))
            fatalError()
        }
        
        // check if we've indexed everything and provide a status report
        if nProcessed == nFilesToIndex {
            //status.mySummaryText = "Index is up to date and contains \(nFiles) files"
            let nSpotlightEntries = self.countSpotlightEntries()
            self.status.mySummaryText = "Index is up to date and contains \(nFiles) files with \(nSpotlightEntries) spotlight entries"
            if nSpotlightEntries < nFiles {
//                self.reIndexSpotlight()
                self.status.mySummaryText = "Spotlight index being updated"
                self.status.myState = .indexing
                self.newReIndexSpotlight()
                let nSpotlightEntries = self.countSpotlightEntries()
                self.status.mySummaryText = "Index is up to date and contains \(nFiles) files with \(nSpotlightEntries) spotlight entries"
                status.post()
            }
            self.status.myState = .completed
        }
        else{
            status.myState = .paused
        }
    }
    
    
    //docToAdd    String    "/usr/local/texlive/2018/texmf-dist/doc/latex/dynblocks/images/cmbx_1.pdf"    bad instruction
    /**
     creates a new TeXHelpData object from the file at `fileURLWithPath`
     
     - parameters:
        - fileURLWithPath: file location
        - theLivePackageDatabase: database oject
        - indexFileInfoOnly: if true, no content searching is performed
     */
    static func createNewTHDObject(withPath: String, theLivePackageDatabase: TeXLivePackageDatabase, indexFileInfoOnly: Bool) -> TeXHelpData? {
        let fURL = URL(fileURLWithPath: withPath)
        let myPDF = MyPDF.init(withURL: fURL as NSURL)
        let myTHD = (myPDF?.createTHData(indexFileInfoOnly: indexFileInfoOnly))
        if myTHD == nil {
            // this happens if PDFKit can't open the document. Probably, preview cannot open it either.
            // so we add it to the list of bad pdf documents
            os_log("Failed to search document:\n%{public}@\nprobably it is not a valid pdf document", log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "IndexerError"),withPath)
            var newList = UserDefaults.standard.array(forKey: "badlistPathStrings")
            if newList == nil {
                newList = [withPath]
            }
            else{
                newList?.append(withPath)
            }
            UserDefaults.standard.set(newList, forKey: "badlistPathStrings")
                
            return nil
        }
        
        if (theLivePackageDatabase.data[myTHD!.fileURL.absoluteString]?.packageName) == nil  {
            os_log("No package listed: %{public}@",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "IndexerError"),myTHD!.fileURL.absoluteString)
        }
        
        myTHD!.setPackageDetails(withTLPDB: theLivePackageDatabase)
        return myTHD!
    }
    
    /**
     creates a new core data object from a TeXHelpData object
     
     Most of this is just a direct translation from the TexHelpData object to the database columns
     But for the keywords there is a bit more work to do
     
     - parameters:
        - withTHData: TeXHelpData object to use as a basis
        - theManagedobjectContext: core data context
     */
    static func createCoreData (withTHData: TeXHelpData, theManagedobjectContext: NSManagedObjectContext) {
        theManagedobjectContext.performAndWait {
            
            let helpDocEntity = NSEntityDescription.entity(forEntityName: "HelpDoc", in: theManagedobjectContext)!
            let keyWordEntity = NSEntityDescription.entity(forEntityName: "Keyword", in: theManagedobjectContext)!
            let newEntry = HelpDoc(entity: helpDocEntity, insertInto: theManagedobjectContext)
            newEntry.fileURLString = withTHData.fileURL.absoluteString
            newEntry.title = withTHData.title
            newEntry.packageName = withTHData.packageName
            newEntry.packageShortDescription = withTHData.packageShortDescription
            newEntry.packageLongDescription = withTHData.packageLongDescription
            newEntry.language = withTHData.language
            newEntry.details = withTHData.details
            newEntry.contentsSearched = withTHData.contentsSearched
            for (keyword,value) in withTHData.keywordsBestHits {
                let newKeywordEntry = Keyword(entity: keyWordEntity, insertInto: theManagedobjectContext)
                newKeywordEntry.bestHit = value as! Int64
                newKeywordEntry.keyword = keyword as? String
                newKeywordEntry.parentKeywordCombo = "\((newEntry.fileURLString)!):\((newKeywordEntry.keyword)!)"
                let root = withTHData.keywordsSelections[keyword as! String] as Any
                do {
                    let data = try NSKeyedArchiver.archivedData(withRootObject: root, requiringSecureCoding: false)
                    newKeywordEntry.keywordData = data
                } catch {
                    print("problem with archiving the page selections")
                }
                //newKeywordEntry.keywordID = newEntry
                newEntry.addToKeywords(newKeywordEntry)
            }
            do {
                try theManagedobjectContext.save()
                theManagedobjectContext.refresh(newEntry, mergeChanges: false)
            } catch {
                os_log("Failed to save core data",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "IndexerError"))
                print(error)
            }
        }
    }
    
    
    
}


/**
 Some string methods that are useful
 */
extension String {

    var length: Int {
        return count
    }

    subscript (i: Int) -> String {
        return self[i ..< i + 1]
    }

    func substring(fromIndex: Int) -> String {
        return self[min(fromIndex, length) ..< length]
    }

    func substring(toIndex: Int) -> String {
        return self[0 ..< max(0, toIndex)]
    }

    subscript (r: Range<Int>) -> String {
        let range = Range(uncheckedBounds: (lower: max(0, min(length, r.lowerBound)),
                                            upper: min(length, max(0, r.upperBound))))
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(start, offsetBy: range.upperBound - range.lowerBound)
        return String(self[start ..< end])
    }
}
