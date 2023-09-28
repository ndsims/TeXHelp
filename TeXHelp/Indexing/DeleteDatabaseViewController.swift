//
//    DeleteDatabaseViewController.swift
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

/**
 Simple view used for showing progress of database deletion
 */
class DeleteDataBaseViewController: NSViewController {
    var appDel: AppDelegate = NSApplication.shared.delegate as! AppDelegate
    @IBOutlet var statusText: NSTextField!
    @IBOutlet var progressIndicator: NSProgressIndicator!
    override func viewWillAppear() {
        self.view.window?.titleVisibility = .hidden
        progressIndicator.startAnimation(self)
    }
    func setStatus(_ txt: String) {
        DispatchQueue.main.async {
            self.statusText.stringValue = txt
        }
    }
}
