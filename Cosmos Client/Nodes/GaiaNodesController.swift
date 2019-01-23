//
//  GaiaNodesController.swift
//  Cosmos Client
//
//  Created by Calin Chitu on 12/01/2019.
//  Copyright © 2019 Calin Chitu. All rights reserved.
//

import UIKit
import CosmosRestApi

class PersistableGaiaNodes: PersistCodable {
    
    let nodes: [GaiaNode]
    
    init(nodes: [GaiaNode]) {
        self.nodes = nodes
    }
}

class GaiaNodesController: UIViewController, ToastAlertViewPresentable {
    
    var toast: ToastAlertView?
    
    @IBOutlet weak var loadingView: CustomLoadingView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var noDataView: UIView!
    @IBOutlet weak var toastHolderUnderView: UIView!
    @IBOutlet weak var toastHolderTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var topNavBarView: UIView!
    @IBOutlet weak var addButton: UIButton!
    
    var addressBook: GaiaAddressBook = GaiaAddressBook(items: [])
    
    fileprivate var nodes: [GaiaNode] =  []
    fileprivate var selectedNode: GaiaNode?
    fileprivate var selectedIndex: Int = 0
    
    private var timer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        toast = createToastAlert(creatorView: view, holderUnderView: toastHolderUnderView, holderTopDistanceConstraint: toastHolderTopConstraint, coveringView: topNavBarView)
        
        nodes = [GaiaNode(name: "devtest",host: "80.211.6.156")]
        
        if let savedNodes = PersistableGaiaNodes.loadFromDisk() as? PersistableGaiaNodes {
            nodes = savedNodes.nodes
        }
        
        PersistableGaiaNodes(nodes: nodes).savetoDisk()
        noDataView.isHidden = nodes.count > 0
        
        let _ = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: OperationQueue.main) { (note) in
            self.refreshNodes()
        }
        
        if let storedBook = GaiaAddressBook.loadFromDisk() as? GaiaAddressBook {
            addressBook = storedBook
        } else {
            addressBook.savetoDisk()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        refreshNodes()
        
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { timer in
            self.refreshNodes()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "NodeEditSegue" {
            let dest = segue.destination as? GaiaNodeController
            dest?.editMode = true
            dest?.collectedData = self.selectedNode
            dest?.editedNodeIndex = self.selectedIndex
            dest?.onCollectDataComplete = { data in
                self.nodes[self.selectedIndex] = data
                PersistableGaiaNodes(nodes: self.nodes).savetoDisk()
            }
            dest?.onDeleteComplete = { index in
                self.nodes.remove(at: index)
                PersistableGaiaNodes(nodes: self.nodes).savetoDisk()
            }
        }
        if segue.identifier == "CollectDataSegue" {
            let dest = segue.destination as? GaiaNodeController
            dest?.onCollectDataComplete = { data in
                self.nodes.insert(data, at: 0)
                PersistableGaiaNodes(nodes: self.nodes).savetoDisk()
            }
        }
        if segue.identifier == "ShowNodeKeysSegue", let selected = selectedNode {
            let dest = segue.destination as? GaiaKeysController
            dest?.node = selected
        }
    }
    
    private func refreshNodes() {
        let dispatch = DispatchGroup()
        loadingView.startAnimating()
        for node in self.nodes {
            dispatch.enter()
            node.getStatus {
                dispatch.leave()
             }
            dispatch.enter()
            node.getNodeInfo {
                dispatch.leave()
            }
        }
        dispatch.notify(queue: DispatchQueue.main) {
            print("\n... refresh Completed ...")
            self.loadingView.stopAnimating()
            self.tableView.reloadData()
        }
    }
}

extension GaiaNodesController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return nodes.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "GaiaNodeCellID", for: indexPath) as! GaiaNodeCell
        let node = nodes[indexPath.section]
        cell.configure(with: node)
        return cell
    }
    
}

extension GaiaNodesController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let cell = tableView.dequeueReusableCell(withIdentifier: "GaiaNodeHeaderCellID") as? GaiaNodeHeaderCell
        let node = nodes[section]
        cell?.updateCell(sectionIndex: section, name: node.name)
        cell?.onTap = { section in
            self.selectedNode = self.nodes[section]
            self.selectedIndex = section
            self.performSegue(withIdentifier: "NodeEditSegue", sender: self)
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.selectedNode = nodes[indexPath.section]
        if (selectedNode?.state == .active || selectedNode?.state == .pending) {
            self.performSegue(withIdentifier: "ShowNodeKeysSegue", sender: self)
        } else {
            self.toast?.showToastAlert("The node is not active. Check the host and the ports", autoHideAfter: 5, type: .info, dismissable: true)
        }
    }
}
