//
//  HelpDoc+CoreDataProperties.swift
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


extension HelpDoc {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<HelpDoc> {
        return NSFetchRequest<HelpDoc>(entityName: "HelpDoc")
    }

    @NSManaged public var fileURLString: String?
    @NSManaged public var language: String?
    @NSManaged public var details: String?
    @NSManaged public var packageLongDescription: String?
    @NSManaged public var packageName: String?
    @NSManaged public var packageShortDescription: String?
//    @NSManaged public var page0PDFData: Data?
    @NSManaged public var title: String?
    @NSManaged public var keywords: NSSet?
    @NSManaged public var contentsSearched: Bool

}

// MARK: Generated accessors for keywords
extension HelpDoc {

    @objc(addKeywordsObject:)
    @NSManaged public func addToKeywords(_ value: Keyword)

    @objc(removeKeywordsObject:)
    @NSManaged public func removeFromKeywords(_ value: Keyword)

    @objc(addKeywords:)
    @NSManaged public func addToKeywords(_ values: NSSet)

    @objc(removeKeywords:)
    @NSManaged public func removeFromKeywords(_ values: NSSet)

}
