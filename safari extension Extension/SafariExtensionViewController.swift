//
//  SafariExtensionViewController.swift
//  safari extension Extension
//
//  Created by Максим Алексеев on 06.07.2023.
//

import SafariServices

class SafariExtensionViewController: SFSafariExtensionViewController {
    
    static let shared: SafariExtensionViewController = {
        let shared = SafariExtensionViewController()
        shared.preferredContentSize = NSSize(width:320, height:240)
        return shared
    }()

}
