//
//  SafariExtensionViewController.swift
//  Refermate Extension
//
//  Created by James irwin on 8/7/23.
//

import SafariServices

class SafariExtensionViewController: SFSafariExtensionViewController {
    
    @IBOutlet var backButton : NSButton!
    @IBOutlet var closeButton : NSButton!
    static let shared: SafariExtensionViewController = {
        let shared = SafariExtensionViewController()
        shared.preferredContentSize = NSSize(width:355, height:650)
        return shared
    }()
    
    override func viewDidLoad() {
       // MessageHandler.shared.popupScript.loadApplication()
    }
}
