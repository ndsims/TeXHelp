//
//    TeXLivePackageDatabase.swift
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
import AppKit
import os.log

struct TLPDB_Entry {
    var packageName: String
    var packageShortDescription: String
    var packageLongDescription: String
    var language: String?
    var details: String?
}

/**
 Abstract
 
 The TeX Live database is held in a plain text file and list the package name of all loaded files. We scan through the database to find the information for each file.
 
 file format is determined by inspecting the perl modules in the tlpkg/TeXLive folder.
 
 We extact:
 - the package name (actually its a 'name' - some docs are in categories that are not 'Package'
 - the short description
 - the long description

 and create a dictionary entry containing this information, with a dictionary key corresponding to the file name of each pdf document in the docfiles section.
 Dictionary entries of of the type TLPDB_Entry
 */

class TeXLivePackageDatabase {
    // the Tex Live Package Database
    var data: [String:TLPDB_Entry]
    
    init(fromRootURL: URL) {
        let rootURL = fromRootURL
        
        let tldbURL = NSURL(fileURLWithPath: "tlpkg/texlive.tlpdb", relativeTo: rootURL) // get the database
        var tldbString:String
        do {
            tldbString = try String(contentsOf: tldbURL as URL) //try to load the database contents.
        }
        catch {
            os_log("%{public}@",OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "TeXLive"),"Problem loading \(String(describing: tldbURL.absoluteString)) database file. Quitting.")
            os_log("%{public}@",OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "TeXLive"), error.localizedDescription)
            fatalError()
        }
        
        let myStrings = tldbString.components(separatedBy: .newlines) //list each line as a separate array entry
        //initialise variables for  iteration:
        var thisIsAPackage = false
        var isHelpDoc = false
        var thisKey: String?
        data = [:]
        
        //loop through each line
        var thisName: String?
        var thisCategory: String?
        var thisShortDesc: String?
        var thisLongDesc: String?
        
        for line in myStrings {
            let words = line.components(separatedBy: " ") //split words
            // we are only interested in lines with more than 1 word on them.
            if words.count > 1 {
                switch words[0].lowercased() {
                    // get the first word, fWord of the line
                    
                    // if fWord == name, create a new struct entry that is blank, and reset the booleans
                case "name":
                    // create a new entry:
                    //thisEntry = TLPDB_Entry(packageName: words[1], packageShortDescription: "", packageLongDescription: "")
                    //thisIsAPackage = false
                    isHelpDoc = false
                    thisName = words[1]
                    thisCategory = nil
                    thisShortDesc = nil
                    thisLongDesc = nil
                    
                    
                // if "category Package", then set IsAPackage = true so we are ready to capture pdfdocs
                case "category":
                    thisCategory = words[1].lowercased()
//                    if words[1].lowercased() == "package" {
//                        thisIsAPackage = true
//                    }
                    
                // if "shortdesc xxx", save xxx as thisShortDesc (assume single line)
                case "shortdesc":
//                    thisEntry.packageShortDescription = (Array(words[1...])).joined(separator: " ")
                    thisShortDesc = (Array(words[1...])).joined(separator: " ")
                // if "longdesc yyy", append yyy to longDesc (assume multi line)
                case "longdesc":
                    if thisLongDesc == nil {thisLongDesc = ""}
                    thisLongDesc! += (Array(words[1...])).joined(separator: " ")
                    thisLongDesc! += " " // white space when we combine lines
//                    thisEntry.packageLongDescription += (Array(words[1...])).joined(separator: " ")
//                    thisEntry.packageLongDescription += " " // white space when we combine lines

                // if "docfiles xx", and only if we've identified this is a thisIsAPackage, enter scanning mode
                case "docfiles", "srcfiles", "runfiles":
//                    if thisIsAPackage == true {
                    // allow all file types to be scanned. Some of the entries might be pdf that aren't in the doc subfolder, but this won't really matter as the TLDB is not the primary source used for indexing.
                    isHelpDoc = true
//                    }
                    
                default:
                    if isHelpDoc == true { //only scan if it's a pdocfile entry
                        if words[1].suffix(4) == ".pdf"{
                            thisKey = URL(fileURLWithPath: words[1], relativeTo: rootURL).absoluteString
                            var thisLanguage:String? = nil
                            var thisDetails:String? = nil
                            
                            // assume each doc entry has no language and no details
                            // otherwise they might be copied from a previous doc from thhe same package
                            // TODO: not sure this is right - will it also change other entries?
                            //thisEntry.language=""
                            //thisEntry.details=""
                            // TODO: only define the dict entry here
                            // key="value with a space" key2="a value"
                            // .*?details="([^"]+)"|.*?language="([^"]+)"
                            if words.count>2 {
                                let additionalInfo: String = (words[2..<words.count]).joined(separator: " ")
                                let regEx = ".*?details=\"([^\"]+)\"|.*?language=\"([^\"]+)"
                                var myRegEx: NSRegularExpression
                                do {
                                    myRegEx = try NSRegularExpression(pattern: regEx, options: NSRegularExpression.Options.anchorsMatchLines)
                                }
                                catch {
                                    fatalError("invalid regex")
                                }
                                
                                let myResults = myRegEx.matches(in: additionalInfo, options: NSRegularExpression.MatchingOptions.init(), range: NSRange(location: 0, length: NSString(string: additionalInfo).length))
                                for myResult in myResults{
                                    var thisRange = myResult.range(at: 1) // range of 1st match
                                    if thisRange.location == NSNotFound {
                                        thisRange = myResult.range(at: 2) // range of 2nd match
//                                        thisEntry.language = NSString(string:additionalInfo).substring(with:thisRange)
                                        thisLanguage = NSString(string:additionalInfo).substring(with:thisRange)
                                    }
                                    else {
//                                        thisEntry.details = NSString(string:additionalInfo).substring(with:thisRange)
                                        thisDetails = NSString(string:additionalInfo).substring(with:thisRange)
                                    }
                                } // end looking at extra doc details
                            }// end if there were extra doc details
                            var thisEntry = TLPDB_Entry(
                                packageName: thisName!,
                                packageShortDescription: thisShortDesc ?? "",
                                packageLongDescription: thisLongDesc ?? "",
                                language: thisLanguage,
                                details: thisDetails
                            )
                            data[thisKey!] = thisEntry
                            
                        } // end if it was a pdf helpdoc
                        
                    } // end if it was a helpdoc)
                }
            }
        }
        
    }
}


//
//
//name 12many
//category Package
//revision 15878
//catalogue one2many
//shortdesc Generalising mathematical index sets
//longdesc In the discrete branches of mathematics and the computer
//longdesc sciences, it will only take some seconds before you're faced
//longdesc with a set like {1,...,m}. Some people write $1\ldotp\ldotp m$,
//longdesc others $\{j:1\leq j\leq m\}$, and the journal you're submitting
//longdesc to might want something else entirely. The 12many package
//longdesc provides an interface that makes changing from one to another a
//longdesc one-line change.
//containersize 2104
//containerchecksum 400c4de374d02934965b5488f37c1b052ade07c2acfae957c9846390b2b78315c6aed2b533a2271bbacabd77c40536b63973bd42e2686f4c6d25d1f4c5b4709e
//doccontainersize 375400
//doccontainerchecksum 2d959b52c8a636f1a72324b5c94e1bf150d00ced12493b8e58b005aa896c6f968dfa48d18abef253f09ebd123cf6b872253cb4962f26322d5f8648fe3a71840c
//docfiles size=98
// texmf-dist/doc/latex/12many/12many.pdf details="Package documentation"
// texmf-dist/doc/latex/12many/README details="Readme"
//srccontainersize 6592
//srccontainerchecksum cb681167a26e813bb7d0cdc4769f5f2d4f5be629ec3bf564a36a53473a491f60702daee655e144fbac08b1361ef35342846e6e192b117f9ab76cfc37f74166a9
//srcfiles size=6
// texmf-dist/source/latex/12many/12many.dtx
// texmf-dist/source/latex/12many/12many.ins
//runfiles size=1
// texmf-dist/tex/latex/12many/12many.sty
//catalogue-ctan /macros/latex/contrib/12many
//catalogue-date 2016-06-24 19:18:15 +0200
//catalogue-license lppl
//catalogue-topics maths
//catalogue-version 0.3
