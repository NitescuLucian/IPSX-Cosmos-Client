//
//  GaiaNodeCell.swift
//  Cosmos Client
//
//  Created by Calin Chitu on 12/01/2019.
//  Copyright © 2019 Calin Chitu. All rights reserved.
//

import UIKit
import CosmosRestApi

class GaiaNodeCell: UITableViewCell {

    @IBOutlet weak var stateView: CellStateRoundedView!
    @IBOutlet weak var leftImageView: UIImageView!
    @IBOutlet weak var leftLabel: UILabel!
    @IBOutlet weak var leftSubLabel: UILabel!
    @IBOutlet weak var rightLabel: UILabel!
    @IBOutlet weak var roundedView: RoundedView!

    func configure(with node: GaiaNode) {
        
        switch node.state {
        case .active: stateView.currentState = .active
        case .pending: stateView.currentState = .pending
        case .unavailable: stateView.currentState = .unavailable
        case .unknown: stateView.currentState = .unknown
        }
        self.roundedView.alpha = (stateView.currentState == .active || stateView.currentState == .pending) ? 1 : 0.5
        leftLabel.text = node.host
        leftSubLabel.text = "\(node.rcpPort), \(node.tendermintPort)"
        rightLabel.text = node.network
    }
}
