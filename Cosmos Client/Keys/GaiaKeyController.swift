//
//  GaiaKeyController.swift
//  Cosmos Client
//
//  Created by Calin Chitu on 14/01/2019.
//  Copyright © 2019 Calin Chitu. All rights reserved.
//

import UIKit
import CosmosRestApi

class GaiaKeyController: UIViewController, ToastAlertViewPresentable {
    
    var node: GaiaNode? = GaiaNode()
    
    @IBOutlet weak var titleLabelTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var topBarView: UIView!
    @IBOutlet weak var topSeparatorView: UIView!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var deleteNode: RoundedButton!
    
    @IBOutlet weak var topConstraintOutlet: NSLayoutConstraint!
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var typeLabel: UILabel!
    @IBOutlet weak var pubKeyLabel: UILabel!
    @IBOutlet weak var seedLabel: UILabel!
    @IBOutlet weak var seedButton: UIButton!
    @IBOutlet weak var loadingView: CustomLoadingView!
    
    var toast: ToastAlertView?
    var key: GaiaKey?
    
    private var fieldsStateDic: [String : Bool] = ["field1" : false, "field2" : false, "field3" : true, "field4" : true]
    
    var onDeleteComplete: ((_ index: Int)->())?
    var selectedkeyIndex: Int?
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        toast = createToastAlert(creatorView: view, holderUnderView: topSeparatorView, holderTopDistanceConstraint: topConstraintOutlet, coveringView: topBarView)
        prePopulate()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        super.viewWillAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
    }
    
    @IBAction func copyAddress(_ sender: Any) {
        UIPasteboard.general.string = addressLabel.text
        toast?.showToastAlert("Address copied to clipboard", autoHideAfter: 5, type: .info, dismissable: true)
    }
    
    @IBAction func copySeed(_ sender: Any) {
        UIPasteboard.general.string = seedLabel.text
        toast?.showToastAlert("Seed copied to clipboard", autoHideAfter: 5, type: .info, dismissable: true)
    }
    
    @IBAction func deleteKey(_ sender: Any) {
        guard let validNode = node else { return }
        
        let keyName = key?.name ?? "this account"
        let alertMessage = "Enter the password for \(keyName) to delete the wallet. The passowrd and seed will be permanentely removed from the keychain."
        self.showPasswordAlert(title: nil, message: alertMessage, placeholder: "Minimum 8 characters") { [weak self] pass in
            self?.loadingView.startAnimating()
            self?.key?.unlockKey(node: validNode, password: pass) { [weak self] success, message in
                self?.loadingView.stopAnimating()
                if success == true {
                    self?.key?.deleteKey(node: validNode, password: self?.key?.getPassFromKeychain() ?? "") { [weak self] success, errMsg in
                        if success {
                            if let index = self?.selectedkeyIndex {
                                self?.onDeleteComplete?(index)
                            }
                            self?.loadingView.stopAnimating()
                            self?.dismiss(animated: true)
                        } else if let errMessage = errMsg {
                            self?.toast?.showToastAlert(errMessage, autoHideAfter: 5, type: .error, dismissable: true)
                        } else {
                            self?.toast?.showToastAlert("Opps, I failed to delete the key.", autoHideAfter: 5, type: .error, dismissable: true)
                        }
                    }
                } else if let msg = message {
                    self?.toast?.showToastAlert(msg, autoHideAfter: 5, type: .error, dismissable: true)
                } else {
                    self?.toast?.showToastAlert("Opps, I failed.", autoHideAfter: 5, type: .error, dismissable: true)
                }
            }
        }
    }
    
    @IBAction func closeButtonAction(_ sender: Any) {
        
        self.dismiss(animated: true)
    }
    
    private func prePopulate() {
        nameLabel.text    = key?.name ?? "No name"
        addressLabel.text = key?.address ?? "cosmos..."
        typeLabel.text    = key?.type ?? "..."
        pubKeyLabel.text  = key?.pubKey ?? "cosmos..."
        seedLabel.text    = "No seed stored in keychain"
        if let seed = key?.getSeedFromKeychain() {
            seedLabel.text = seed
            //TODO: check if this is safe with a security audit
            //seedButton.isHidden = false
        }
    }
    
    private func updateUI() {
        
    }
}
