//
//    MyPDF.swift
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


/**
 Class to hold the file pdf information as part of the generation of the TeXHelpData object
 
 Probably this could be merged with the TeXHelpData class
 */
class MyPDF {
    var thisPDFdoc:PDFDocument? // only created if necessary for keyword indexing
    var thisURL: URL
    //var thisPDFpage:PDFPage?
    
    init? (withURL: NSURL) {
        thisURL = withURL as URL
        // assume file is reachable as the url came from a directory listing
    }
    
    static func getPageContents(fromDoc: PDFDocument, fromPage: Int) -> NSString? {
        let myPDFpage = fromDoc.page(at: fromPage)
        guard myPDFpage != nil else {
            return nil
        }
        return (myPDFpage!.string) as NSString?
    }
    
    func createTHData(indexFileInfoOnly: Bool) -> TeXHelpData? {
        let teXHelpData = TeXHelpData(withFileURL: thisURL, withPageCount: 0)
        if indexFileInfoOnly == false {
            self.thisPDFdoc = PDFDocument(url: self.thisURL)
            if self.thisPDFdoc == nil {return nil}
            let pageCount = (thisPDFdoc?.pageCount)!
            teXHelpData.pageCount = pageCount
            teXHelpData.contentsSearched = true
            for pageNumber in 0..<pageCount {
                createKeywordsForPage(pageNumber: pageNumber, teXHelpData: teXHelpData)
            }
            teXHelpData.setBestHits()
        }
        return teXHelpData
    }
    
    func createKeywordsForPage(pageNumber: Int, teXHelpData: TeXHelpData) {
        //autoreleasepool {
        
        if pageNumber == 0 {
            let thisPDFpage = self.thisPDFdoc?.page(at: pageNumber)
            guard thisPDFpage != nil else {
                fatalError("page doesn't exist")
            }
            // earlier version had a quicklook preview that used this database entry. Its now removed
            // special stuff for first page. Try two options: a pdf doc and a thumnail
//            teXHelpData.page0PDFData = thisPDFpage?.dataRepresentation
        }
        //https://stackoverflow.com/questions/27040924/nsrange-from-swift-range

        let contents = MyPDF.getPageContents(fromDoc: self.thisPDFdoc!, fromPage: pageNumber)! as String
        let searchHits = searchContents(contents: contents)
        for searchHit in searchHits{
            teXHelpData.incrementKeyword(
                keyword: searchHit.keys.first!,
                atIndex: pageNumber,
                location: searchHit.values.first!.location,
                length: searchHit.values.first!.length - 1)
        }
        
    }
    
    
    /**
     the file contents regex search algorithm
     */
    func searchContents(contents: String) -> [[String:NSRange]] {
        
        let regEx: String = ""
            + "\\\\begin" // search for \begin
            + "\\{" // search for left brace
                + "(" //  begin CAPTURE GROUP 1
                    + "[a-zA-Z]+" // set with any chacter a-Z, repeated on or more times
                + ")" // end CAPTURE GROUP 1
            + "\\}" // closing brace;
            + "|" //append or operator
            + "\\\\" //search for \
                + "("  //begin CAPTURE GROUP 2
                    + "[a-zA-Z]+" // basic letters, one or more times
                + ")" //end CAPTURE GROUP 2
            + "(?=[" // start look ahead assertion for a set
                + "\\s" // any white space
                + "\\{" // open brace
                + "%"   // comment start
                + "\\\\" // a single \
                + "," // comma
                + "." // full stop
            + "])" // end set of look ahead assertions
        
        var myRegEx: NSRegularExpression
        do {
            myRegEx = try NSRegularExpression(pattern: regEx, options: NSRegularExpression.Options.anchorsMatchLines)
        }
        catch {
            fatalError("invalid regex")
        }
        
        let myResults = myRegEx.matches(in: contents, options: NSRegularExpression.MatchingOptions.init(), range: NSRange(location: 0, length: NSString(string: contents).length))
        
        var returnValues: [[String: NSRange]] = []
        
        let skippedCommands: Set<String> = [
            "begin",
            "def",
            "let",
        ]
        
        for myResult in myResults{
            var thisRange = myResult.range(at: 1) // range of 1st match
            if thisRange.location == NSNotFound {
                thisRange = myResult.range(at: 2) // range of 2nd match
            }
            let comstr = NSString(string: contents).substring(with:thisRange)
            if skippedCommands.contains(comstr) {continue}
            returnValues.append([comstr:thisRange])
        }
        return returnValues
    }
    
    
}
