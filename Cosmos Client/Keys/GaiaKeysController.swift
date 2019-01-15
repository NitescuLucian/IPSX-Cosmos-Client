//
//  GaiaKeysController.swift
//  CosmosSample
//
//  Created by Calin Chitu on 11/01/2019.
//  Copyright © 2019 Calin Chitu. All rights reserved.
//

import UIKit
import CosmosRestApi

class GaiaKeysController: UIViewController, GaiaKeysManagementCapable, ToastAlertViewPresentable {
    
    var toast: ToastAlertView?
    
    @IBOutlet weak var loadingView: CustomLoadingView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var noDataView: UIView!
    @IBOutlet weak var toastHolderUnderView: UIView!
    @IBOutlet weak var toastHolderTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var topNavBarView: UIView!
    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var backButton: UIButton!
    
    @IBAction func addAction(_ sender: Any) {
    }

    @IBAction func backAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    var node: GaiaNode = GaiaNode()
    var dataSource: [GaiaKey] = []
    var selectedKey: GaiaKey?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        toast = createToastAlert(creatorView: view, holderUnderView: toastHolderUnderView, holderTopDistanceConstraint: toastHolderTopConstraint, coveringView: topNavBarView)
        noDataView.isHidden = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        loadingView.startAnimating()
        retrieveAllKeys(node: node) { gaiaKeys, errorMessage in
            self.loadingView.stopAnimating()
            guard let keys = gaiaKeys else {
                self.toast?.showToastAlert(errorMessage ?? "Unknown error")
                return
            }
            self.dataSource = keys
            self.noDataView.isHidden = keys.count > 0
            self.tableView?.reloadData()
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowKeyDetailsSegue" {
            let dest = segue.destination as? GaiaKeyController
            dest?.node = self.node
            dest?.key = selectedKey
        }
        if segue.identifier == "CreateKeySegue" {
            let dest = segue.destination as? GaiaKeyCreateController
            dest?.node = self.node
        }
    }
}


extension GaiaKeysController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "GaiaKeyCellID", for: indexPath) as! GaiaKeyCell
        let key = dataSource[indexPath.section]
        cell.configure(key: key)
        return cell
    }
    
}

extension GaiaKeysController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let cell = tableView.dequeueReusableCell(withIdentifier: "GaiaKeyHeaderCellID") as? GaiaKeyHeaderCell
        let key = dataSource[section]
        cell?.updateCell(sectionIndex: section, key: key)

        cell?.onForgetPassTap = { section in
            self.showPasswordAlert(title: nil, message: "The password for \(key.name) has been removed from the keychain", placeholder: "Minimum 8 charactes") { pass in
                if key.getPassFromKeychain() != pass {
                    self.toast?.showToastAlert("Incorrect password, try again..", autoHideAfter: 5, type: .error, dismissable: true)
                }  else if key.forgetPassFromKeychain() == true {
                    self.toast?.showToastAlert("The password for \(key.name) has been removed from the keychain", autoHideAfter: 5, type: .info, dismissable: true)
                } else {
                    self.toast?.showToastAlert("Opps, didn't manage to remove it or didn't find it.", autoHideAfter: 5, type: .error, dismissable: true)
                }
                self.tableView.reloadData()
            }
        }

        cell?.onMoreOptionsTap = { section in
            self.selectedKey = key
            self.performSegue(withIdentifier: "ShowKeyDetailsSegue", sender: self)
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let key = dataSource[indexPath.section]
        
        guard key.isUnlocked == false else {
            performSegue(withIdentifier: "WalletSegueID", sender: self)
            return
        }
        
        DispatchQueue.main.async {
            
            let alertMessage = "Enter the password for \(key.name) to acces the wallet. It will be stored encripted in the device's keychain if the unlock is succesfull."
            self.showPasswordAlert(title: nil, message: alertMessage, placeholder: "Minimum 8 characters") { pass in
                key.unlockKey(node: self.node, password: pass) { success, message in
                    if success == true {
                        key.savePassToKeychain(pass: pass)
                        self.toast?.showToastAlert("The key has been unlocked. You can now acces your wallet.", autoHideAfter: 5, type: .info, dismissable: true)
                        self.tableView.reloadData()
                    } else if let msg = message {
                        self.toast?.showToastAlert(msg, autoHideAfter: 5, type: .error, dismissable: true)
                    } else {
                        self.toast?.showToastAlert("Opps, I failed.", autoHideAfter: 5, type: .error, dismissable: true)
                    }
                }
            }
        }

    }
}
