//
//    StatusViewController.swift
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
import CoreSpotlight
import os.log

class StatusViewController: NSViewController {


    @IBOutlet var progressIndicator: NSProgressIndicator!
    @IBOutlet var titleText: NSTextField!
    @IBOutlet var statusText: NSTextField!
    @IBOutlet var summaryText: NSTextField!
    @IBOutlet var configureButton: NSButton!
    @IBOutlet var pauseButton: NSButton!
    

    //appDel used to access the persistent container
    var appDel: AppDelegate = NSApplication.shared.delegate! as! AppDelegate

    //MARK: - the interface and buttons

    override func viewDidLoad() {
        super.viewDidLoad()
        pauseButton.isEnabled = true
        let status = appDel.lastStatus
        updateProgress(status: status)
        appDel.statusViewController = self
        NotificationCenter.default.addObserver(self, selector: #selector(statusChanged(_:)), name: .statusNotification, object: nil)
    }
    
    @objc func statusChanged(_ input: Notification){
        // update views with new values as needed
        let status = input.object as! MyStatus
        DispatchQueue.main.async {
            self.updateProgress(status: status)
        }
    }
    
    func updateProgress(status: MyStatus) {
        summaryText.stringValue = status.mySummaryText
        statusText.stringValue = status.myStatusText
        switch status.myState {
        case .starting:
            progressIndicator.isHidden = false
            progressIndicator.isIndeterminate = true
            progressIndicator.startAnimation(self)
            titleText.stringValue = "Indexing started"
            configureButton.isHidden = false
            pauseButton.isHidden = false
            pauseButton.title = "Pause Indexing"
        case .indexing:
            progressIndicator.isHidden = false
            progressIndicator.stopAnimation(self)
            progressIndicator.isIndeterminate = false
            progressIndicator.doubleValue = status.myProgressBar
            titleText.stringValue = "Indexing in progress"
            configureButton.isHidden = false
            pauseButton.isHidden = false
            pauseButton.title = "Pause Indexing"
        case .indexingSpotlight:
            progressIndicator.isHidden = false
            progressIndicator.stopAnimation(self)
            progressIndicator.isIndeterminate = false
            progressIndicator.doubleValue = status.myProgressBar
            titleText.stringValue = "Indexing spotlight database"
            pauseButton.isHidden = true
            pauseButton.title = "Pause Indexing"
            configureButton.isHidden = true
        case .completed:
            progressIndicator.isHidden = true
            progressIndicator.isIndeterminate = false
            progressIndicator.doubleValue = status.myProgressBar
            titleText.stringValue = "Indexing completed"
            configureButton.isHidden = false
            pauseButton.isHidden = true
            pauseButton.title = "Pause Indexing"
            statusText.stringValue = ""
        case .uninitialised:
            //should only happen on load
            progressIndicator.isHidden = true
            progressIndicator.isIndeterminate = false
            progressIndicator.doubleValue = 0.0
            titleText.stringValue = "Initialising"
            configureButton.isHidden = false
            pauseButton.isHidden = true
            pauseButton.title = "Pause Indexing"
            statusText.stringValue = ""
            
        case .paused:
            progressIndicator.stopAnimation(self)
            progressIndicator.isIndeterminate = false
            progressIndicator.doubleValue = status.myProgressBar
            titleText.stringValue = "Indexing paused"
            configureButton.isHidden = false
            pauseButton.isHidden = false
            pauseButton.title = "Resume Indexing"
        }
    }



    @IBAction func pauseResumeIndex(_ sender: Any) {
        switch pauseButton.title {
        case "Pause Indexing":
            appDel.stopIndexing()
        case "Resume Indexing":
            appDel.resumeIndexing()
        default:
            break
        }
    }

}



extension StatusViewController: NSAlertDelegate {
    func alertShowHelp(_ alert: NSAlert) -> Bool {
        let msg = """

        This app searches the TeXLive root folder to find:
         - the TeXLive database
         - the pdf documents within the 'doc' subfolders.

        To find the TeXLive root folder for your TeXLive distribution, use the following command in the Terminal:

        kpsewhich -var-value TEXMFDIST

            and then remove the trailing directory.

        You must allow access, otherwise this app will quit.

        """

        let myAlert = NSAlert()
        myAlert.alertStyle = NSAlert.Style.informational
        myAlert.informativeText = msg
        myAlert.messageText = "Help"
        myAlert.runModal()
        return true
    }
}
