//
//  NumberCollectionViewCell.swift
//  CollectionDiffGameDB
//
//  Created by Alfian Losari on 19/06/19.
//  Copyright © 2019 Alfian Losari. All rights reserved.
//

import UIKit

class BadgeItemCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var textLabel: UILabel!
    @IBOutlet weak var view: UIView!

    override func awakeFromNib() {
        super.awakeFromNib()
        view.layer.cornerRadius = 5
    }
    
    func configure(text: String, isSelected: Bool) {
        textLabel?.text = text
        textLabel.textColor = isSelected ? .label : .secondaryLabel
        view.backgroundColor = isSelected ? .systemFill : .quaternarySystemFill
    }

}

