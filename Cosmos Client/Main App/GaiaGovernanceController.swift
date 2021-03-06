//
//  GaiaGovernanceController.swift
//  Cosmos Client
//
//  Created by Calin Chitu on 14/01/2019.
//  Copyright © 2019 Calin Chitu. All rights reserved.
//

import UIKit
import CosmosRestApi

class GaiaGovernanceController: UIViewController, ToastAlertViewPresentable, GaiaGovernaceCapable {

    var toast: ToastAlertView?

    var node: GaiaNode?
    var key: GaiaKey?
    var account: GaiaAccount?
    var feeAmount: String { return node?.defaultTxFee  ?? "0" }
    
    @IBOutlet weak var loadingView: CustomLoadingView!
    @IBOutlet weak var toastHolderUnderView: UIView!
    @IBOutlet weak var toastHolderTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var topNavBarView: UIView!
    @IBOutlet weak var bottomTabbarView: CustomTabBar!
    @IBOutlet weak var bottomTabbarDownConstraint: NSLayoutConstraint!
    @IBOutlet weak var tableView: UITableView!
    
    var forwardCounter = 0
    var onUnwind: ((_ toIndex: Int) -> ())?
    var lockLifeCicleDelegates = false
    
    var dataSource: [GaiaProposal] = []
    var proposeData: ProposalData?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        toast = createToastAlert(creatorView: view, holderUnderView: toastHolderUnderView, holderTopDistanceConstraint: toastHolderTopConstraint, coveringView: topNavBarView)
        bottomTabbarView.onTap = { [weak self] index in
            switch index {
            case 0:
                self?.onUnwind?(0)
                self?.performSegue(withIdentifier: "UnwindToWallet", sender: nil)
            case 1: self?.dismiss(animated: false)
            case 3: self?.performSegue(withIdentifier: "nextSegue", sender: index)
            default: break
            }
        }
        
        let _ = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: OperationQueue.main) { [weak self] note in
            self?.node?.getStatus {
                if self?.node?.state == .unknown {
                    self?.performSegue(withIdentifier: "UnwindToNodes", sender: self)
                } else if let validNode = self?.node {
                    self?.loadData(validNode: validNode)
                }
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard !lockLifeCicleDelegates else { return }
        if forwardCounter > 0 {
            bottomTabbarView.selectIndex(-1)
            return
        }
        
        bottomTabbarView.selectIndex(2)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !lockLifeCicleDelegates else {
            lockLifeCicleDelegates = false
            return
        }
        if forwardCounter > 0 {
            UIView.setAnimationsEnabled(true)
            self.performSegue(withIdentifier: "nextSegue", sender: 3)
            forwardCounter = 0
            return
        }
        
        if let data = proposeData, let node = node, let key = key {
            self.loadingView.startAnimating()
            self.toast?.showToastAlert("Proposal create request submited", autoHideAfter: 3, type: .validatePending, dismissable: true)
            self.propose(
                deposit: data.amount,
                title: data.title,
                description: data.description,
                type: data.type,
                node: node,
                key: key,
                feeAmount: self.feeAmount) { [weak self] response, err in
                    self?.loadingView.stopAnimating()
                    if err == nil {
                        self?.toast?.showToastAlert("Proposal Created", autoHideAfter: 5, type: .info, dismissable: true)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            self?.loadData(validNode: node)
                        }
                    } else if let errMsg = err {
                        self?.toast?.showToastAlert(errMsg, autoHideAfter: 5, type: .error, dismissable: true)
                    }
            }
        } else if let validNode = node {
            loadData(validNode: validNode)
        }
        proposeData = nil
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "CreateProposalSegueID" {
            
            guard let dest = segue.destination as? GaiaProposalController else { return }
            dest.onCollectDataComplete = { [weak self] data in
                self?.proposeData = data
            }
        } else if let index = sender as? Int {
            
            let dest = segue.destination as? GaiaSettingsController
            dest?.forwardCounter = index - 3
            dest?.node = node
            dest?.account = account
            dest?.key = key
            dest?.onUnwind = { [weak self] index in
                self?.lockLifeCicleDelegates = true
                self?.bottomTabbarView.selectIndex(-1)
                if index == 0 { self?.onUnwind?(index) }
            }
            forwardCounter = 0
        }
    }

    func loadData(validNode: GaiaNode) {
        
        loadingView.startAnimating()
        retrieveAllPropsals(node: validNode) { [weak self] proposals, errMsg in
            self?.loadingView.stopAnimating()
            if let validProposals = proposals {
                self?.dataSource = validProposals.reversed()
                self?.tableView.reloadData()
            } else if let validErr = errMsg {
                self?.toast?.showToastAlert(validErr, autoHideAfter: 5, type: .error, dismissable: true)
            } else {
                self?.toast?.showToastAlert("Ooops! I Failed", autoHideAfter: 5, type: .error, dismissable: true)
            }
        }
    }
    
    @IBAction func unwindToGovernance(segue:UIStoryboardSegue) {
        bottomTabbarView.selectIndex(2)
    }

    func handleVoting(proposal: GaiaProposal) {
        self.showVotingAlert(title: proposal.title, message: proposal.description) { [weak self] vote in
            guard let vote = vote, let node = self?.node, let key = self?.key  else { return }
            self?.loadingView.startAnimating()
            self?.vote(
                for: proposal.proposalId,
                option: vote,
                node: node,
                key: key,
                feeAmount: self?.feeAmount ?? "0")
            {  response, err in
                self?.loadingView.stopAnimating()
                if err == nil {
                    self?.toast?.showToastAlert("Vote submited", autoHideAfter: 5, type: .info, dismissable: true)
                } else if let errMsg = err {
                    self?.toast?.showToastAlert(errMsg, autoHideAfter: 5, type: .error, dismissable: true)
                }
            }
        }
    }
    
    func handleDeposit(proposal: GaiaProposal) {
        let denom = node?.stakeDenom ?? "stake"
        showAmountAlert(title: "Type the amount of \(denom) you want to deposit to proposal with id \(proposal.proposalId)", message: nil, placeholder: "0 \(denom)") { [weak self] amount in
            guard let node = self?.node, let key = self?.key  else { return }
            self?.loadingView.startAnimating()
            self?.depositToProposal(
                proposalId: proposal.proposalId,
                amount: amount ?? "0",
                node: node,
                key: key,
                feeAmount: self?.feeAmount ?? "0") { response, err in
                    self?.loadingView.stopAnimating()
                    if err == nil {
                        self?.toast?.showToastAlert("Deposit submited", autoHideAfter: 5, type: .info, dismissable: true)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            self?.loadData(validNode: node)
                        }
                    } else if let errMsg = err {
                        self?.toast?.showToastAlert(errMsg, autoHideAfter: 5, type: .error, dismissable: true)
                    }
            }
        }
    }
}

extension GaiaGovernanceController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "GaiaGovernanceCellID", for: indexPath) as! GaiaGovernanceCell
        let proposal = dataSource[indexPath.item]
        cell.configure(proposal: proposal)
        return cell
    }
    
}

extension GaiaGovernanceController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let proposal = dataSource[indexPath.item]
        
        DispatchQueue.main.async {
            switch proposal.status {
            case "Passed"  : self.toast?.showToastAlert("This proposal has passed. You can no longer vote.", autoHideAfter: 5, type: .info, dismissable: true)
            case "Rejected": self.toast?.showToastAlert("This proposal has been rejected. You can no longer vote.", autoHideAfter: 5, type: .info, dismissable: true)
            case "DepositPeriod": self.handleDeposit(proposal: proposal)
            default: self.handleVoting(proposal: proposal)
            }
        }
    }
}
