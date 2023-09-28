//
//    THData.swift
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
import AppKit
import Quartz


/**
Class that captures the main attributes of a pdf help document
 
 The MyPDF class creates keywordAllHits and keywords.
  
 `keywordAllHits` is a dictionary of arrays of integers, within one integer for each page
 
 `keywordAllHits` =
   `keyword1`: [ 2 3 0 0 ] 2 counts of keyword1 on page 0 and 3 counts of keyword1 featured on pdf page 1 (i.e. the second page)
 
   `keyword2`: [ 0 0 0 1 ] 1 counts of keyword1 featured on pdf page 3 (i.e. the last page)
 
 For each pdf page, a regular expression search identifies any commands. For each search result, the incrementKeyword method is used to increment the counter for the relavant page. The method calls the method hitsForKeyword, which returns the previous counter array for the keyword, or initialises it with a zero for each page number (i.e. [0 0 0 0] if there are 4 pages).
 
 Then, the data is summarised with setBestHits. This finds the maximum index for each keyword, e.g.:
 
 `keywordBestHits` =
  keyword1: 1 // the page number that had the highest number of hits
  keyword2: 3
 
 `setBestHits` also summarizes all the keywords, e.g:
 keyword is an array of strings:
 keyword =
   keyword1
   keyword2
this is superflous as we can see the keywords in keywordBestHits

Core Data structure:
 
 each object of class TeXHelpData is a row in the table TeXHelpEntity
 
 
 */
class TeXHelpData {
    // the THData class is a TeXHelp object that captures the main attributes of a pdf document.
    var fileURL: URL
    var keywordsAllHits: [String:[Int]]
    var keywordsBestHits: NSMutableDictionary
    var packageName: String?
    var packageLongDescription: String?
    var packageShortDescription: String?
    var language: String?
    var details: String?
    var pageCount: Int
//    var page0PDFData: Data?
    var title: String
    var contentsSearched: Bool = false
    var keywordsSelections: [String: [[Int]]]
    
    init(withFileURL: URL, withPageCount: Int) {
        fileURL = withFileURL
        pageCount = withPageCount
        keywordsAllHits = [:]
        keywordsBestHits = [:]
        title = withFileURL.lastPathComponent
        keywordsSelections = [:]
    }
    

    func hitsForKeyword(keyword: String) -> [Int] {
        // returns, and stores if necessary, the array of AllHits objects for a selected keyword, or creates an empty array if necessary.
        if self.keywordsAllHits[keyword] == nil {
            keywordsAllHits[keyword] = Array(repeating: 0, count: self.pageCount)
        }
        return keywordsAllHits[keyword]!
    }
    

/**
Use a  dictionary to store keywords & hitcount.  add object for a new keyword
 
- returns:[`keyword`,`ArrayofHits`] dictionary with unique keywords
 */
    func incrementKeyword(keyword: String, atIndex: Int){
        var count_int:Int
        count_int = hitsForKeyword(keyword: keyword)[atIndex]
        count_int += 1
        keywordsAllHits[keyword]![atIndex] = count_int
    }
    
    func incrementKeyword(keyword: String, atIndex: Int, location: Int, length: Int){
        // use a  dictionary to store keywords & hitcount.  add object for a new keyword
        // we get {"keyword",ArrayofHits} dictionary with unique keywords
        var count_int:Int
        count_int = hitsForKeyword(keyword: keyword)[atIndex]
        count_int += 1
        keywordsAllHits[keyword]![atIndex] = count_int
        let thisSel = [atIndex, location, length]
        if keywordsSelections[keyword] == nil {
            keywordsSelections[keyword] = [thisSel]
        }
        else {
            keywordsSelections[keyword]!.append(thisSel)
        }
        
    }
    
    /**
      called to extract the PageHits data and create the tophits data.
     
      - enumerate keywords
      - find maximum value for each
     -  save the index of the maximum value
     */
    func setBestHits () {
          for (key,value) in keywordsAllHits {
            let pagehits: [Int] = value
            let ind = pagehits.firstIndex(of: pagehits.max()! )
            //keywords.append("\\\(key)")
            keywordsBestHits[key] = ind
        }
    }
    
    func setPackageDetails (withTLPDB: TeXLivePackageDatabase) {
        let dbDict = withTLPDB.data[fileURL.absoluteString]
        if dbDict == nil {
            packageName = ""
            packageShortDescription = ""
            packageLongDescription = ""
            language = ""
            details = ""
        }
        else {
            packageName = dbDict!.packageName
            packageLongDescription = dbDict!.packageLongDescription
            packageShortDescription = dbDict!.packageShortDescription
            language = dbDict!.language
            details = dbDict!.details
        }
        
    }

}
