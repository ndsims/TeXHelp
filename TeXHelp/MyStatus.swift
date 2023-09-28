//    MyStatus.swift
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
import os.log

/**
Class to handle status messages passed from the indexing engine to the User Interface
 - `myState` defines the status
 - `myProgressBar` is 0-100 indicator
 - `myStatusText` is a detailed informative string
 - `mySummaryText` is a short string
 */
class MyStatus: NSObject {

    enum State{
        case uninitialised
        case starting
        case indexing
        case indexingSpotlight
        case paused
        case completed
    }

    // notification  is ONLY fired if the myState updates, so we need to chaange this as a notification 'trigger', or use the send() function
    var myState = State.uninitialised {
        didSet {
            self.post()
            os_log("Status: %{public}@",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Info"),description())
        }
    }
    var myProgressBar = Double(0)
    var myStatusText = String("")
    var mySummaryText = String("") {
        didSet {
            os_log("%{public}@",log: OSLog(subsystem: "com.TeXHelp.TeXHelp", category: "Info"),mySummaryText)
        }
    }
    
    /**
     Posts a notification
     
     This is done automatically if `myState` changes
     */
    func post() {
        NotificationCenter.default.post(Notification(name: .statusNotification, object: self, userInfo: nil))
        
    }
    
    /**
     Returns a string describing `myState`
     */
    func description() -> String {
        switch self.myState {
        case .uninitialised:
            return "unititionalised"
        case .starting:
            return "starting"
        case .indexing:
            return "indexing"
        case .indexingSpotlight:
            return "indexingSpotlight"
        case .paused:
            return "paused"
        case .completed:
            return "completed"
        }
    }
    
}


extension Notification.Name {
    static var statusNotification: Notification.Name {
        return .init("statusNotification")
    }
}
