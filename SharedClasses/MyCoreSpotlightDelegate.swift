//
//  SpotlightIntegration.swift
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
import CoreSpotlight
import os.log
//import TeXHelpEntry



/**

This contains the class that integrates core data with core spotlight

key points:
- to see the search in spotlight (outside the app, we need a
        'com.apple.application-identifier = $(TeamIdentifierPrefix)$(CFBundleIdentifier)
       in the entitlements file for the main application
 but this functionality is now unused!
       
- to enable the automatic indexing, we need the following code:
       
       let container = NSPersistentContainer(name: "Blank")   // replace "Blank" with the name of the container
       let descs = container.persistentStoreDescriptions
       for desc in descs {
           desc.setOption(MyCoreDataCoreSpotlightDelegate(forStoreWith:desc, model: container.managedObjectModel), forKey:NSCoreDataCoreSpotlightExporter)
       }
       container.loadPersistentStores....

- to actually send a record to the spotlight index, we need to:
       - open the .xcdatamodelId
       - for the main entity we want to index
       - set the Spotlight Display Name to a valid NSExpression
       - e.g. lowercase(title), if title is one of the attributes in the entity. This becomes "kMDItemDisplayName"
       - then, the evaluated expression is used by spotlight.
       - clean the build folder after any changes to the .xcdatamodelId to ensure rebuild.
      "kMDItemContentType" is "public.item"
*/
class MyCoreDataCoreSpotlightDelegate: NSCoreDataCoreSpotlightDelegate {
    var numReIndexed = 0
     override func attributeSet(for object: NSManagedObject) -> CSSearchableItemAttributeSet? {
          guard let attributeSet = super.attributeSet(for: object) else {
            print("inconsistent attibute set?")
            return nil
         }
         if "HelpDoc" == object.entity.name {
            // most attributes are set directly because 'index in spotlight' is checked in their database/entity settings.
            let item = object as! HelpDoc
            // add displayName for formatting in spotlight search
            attributeSet.displayName = "TeX Help: " + item.title!
            attributeSet.title = String(item.title!.dropLast(4)) //strip '.pdf' off the end
            // not clear if this ever gets used
            attributeSet.contentType = "com.TeXHelp.TeXHelp"
            // this is useful for spotlight search, e.g. kind:TeXHelp
            attributeSet.kind = "TeXHelp"
            // the keywords info needs to be added.
            let CAK = CSCustomAttributeKey(keyName: "commands", searchable: true, searchableByDefault: true, unique: false, multiValued: true)
            let mykeys = item.keywords?.allObjects as! [Keyword]
            var keys: [String] = []
            for key in mykeys {
                keys.append("\\"+key.keyword!)
            }
            attributeSet.setValue((keys as NSSecureCoding), forCustomKey: CAK!)
            os_log("Spotlight re-indexed:    %{public}@",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Spotlight"),(URL(string:item.fileURLString!)?.path)!)

            self.numReIndexed += 1
          }
          return attributeSet
     }
    
    override func domainIdentifier() -> String {
        return "com.TeXHelp.TeXHelp"
    }
    
    override func indexName() -> String? {
        return "com.TeXHelp.TeXHelp"
    }
    
}
