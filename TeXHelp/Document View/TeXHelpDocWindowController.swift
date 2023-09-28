//
//    TeXHelpDocWindowController.swift
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

import Quartz
import Foundation
import CoreData
import os.log
import CoreSpotlight

class TeXHelpWindowController: NSWindowController, NSTextFieldDelegate{

    @IBOutlet var progressIndicator: NSProgressIndicator!
    @IBOutlet var progressButton: NSButton!
    var vC: TeXHelpDocViewController?
    var sVC: SearchViewController?
    
    func updateProgress(status: MyStatus) {
        //os_log(OSLogType.info,"updateProgress")
        switch status.myState {
        case .starting:
            progressIndicator.isHidden = false
            progressIndicator.isIndeterminate = true
            progressIndicator.startAnimation(self)
            progressButton.isTransparent = false
            progressButton.image = NSImage(named: "NSInfo")
        case .indexing:
            progressIndicator.stopAnimation(self)
            progressIndicator.isHidden = false
            progressIndicator.isIndeterminate = false
            progressIndicator.doubleValue = status.myProgressBar
            progressButton.isTransparent = false
            progressButton.image = NSImage(named: "NSInfo")
        case .indexingSpotlight:
            progressIndicator.stopAnimation(self)
            progressIndicator.isHidden = false
            progressIndicator.isIndeterminate = false
            progressIndicator.doubleValue = status.myProgressBar
            progressButton.isTransparent = false
            progressButton.image = NSImage(named: "NSInfo")
        case .completed:
            progressIndicator.isHidden = true
            progressIndicator.isIndeterminate = false
            progressIndicator.doubleValue = status.myProgressBar
            progressButton.isTransparent = false
            progressButton.image = NSImage(named: "NSInfo")
        case .uninitialised:
            //os_log(OSLogType.info,"uninitialised / doc view")
            progressIndicator.isHidden = false
            progressIndicator.isIndeterminate = true
            progressIndicator.startAnimation(self)
            progressButton.isTransparent = false
            progressButton.image = NSImage(named: "NSInfo")
            break
        case .paused:
            progressIndicator.isHidden = true
            progressIndicator.isIndeterminate = false
            progressIndicator.doubleValue = status.myProgressBar
            progressButton.isTransparent = false
            progressButton.image = NSImage(named: "NSInfo")
            break
        }
        
    }
    @IBOutlet var searchView: NSView!
    @IBOutlet var searchFieldCell: NSSearchFieldCell!
    
    @IBAction func spotlightSearch(_ sender: NSSearchField) {

        if sVC == nil {
            let oldRange = sender.currentEditor()?.selectedRange
            let storyboard = NSStoryboard(name: NSStoryboard.Name("MainStoryboard"), bundle: nil)
            sVC = storyboard.instantiateController(
                withIdentifier: NSStoryboard.SceneIdentifier("searchResultsViewControllerID")) as? SearchViewController
            sVC?.caller = sender
            self.contentViewController!.present(sVC!, asPopoverRelativeTo: NSRect(x: 0, y: 0, width: 0, height: 0), of: sender, preferredEdge: NSRectEdge.maxY, behavior: NSPopover.Behavior.applicationDefined)
            sender.becomeFirstResponder()
            let editor = sender.currentEditor()
            editor!.selectedRange = oldRange!
        }
        if sender.stringValue == "" {
            sVC!.dismiss(self)
            sVC = nil
        }
        else {
            sVC?.startQuery(withString: sender.stringValue)
        }
        //var query : CSSearchQuery? = nil
        //startQuery(withTitle: sender.stringValue)
    }

    
    override func windowDidLoad() {
        let appDel: AppDelegate = NSApplication.shared.delegate as! AppDelegate
        updateProgress(status: appDel.lastStatus)
        NotificationCenter.default.addObserver(self, selector: #selector(statusChanged(_:)), name: .statusNotification, object: nil)
        vC = self.contentViewController as? TeXHelpDocViewController
        //self.window?.delegate = self
        
        //self.window?.zoom(self)


        
        let allWin = NSApplication.shared.windows
        for win in allWin {
            if win.title == "TeXHelp"{
                win.close()
            }
        }
    }
    
    
    @objc func statusChanged(_ input: Notification){
        // update views with new values as needed
        let status = input.object as! MyStatus
        DispatchQueue.main.async {
            self.updateProgress(status: status)
        }
    }
    
    

    
}


class WinDel: NSWindow, NSWindowDelegate {
     func windowWillUseStandardFrame(_ window: NSWindow,
                                             defaultFrame newFrame: NSRect) -> NSRect {
        return NSRect(x: newFrame.width - newFrame.width/2.2,
                      y: 0,
                      width: newFrame.width/2.2,
                      height: newFrame.height)
    }
}
