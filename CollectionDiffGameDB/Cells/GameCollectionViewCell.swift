//
//  GameCollectionViewCell.swift
//  CollectionDiffGameDB
//
//  Created by Alfian Losari on 19/06/19.
//  Copyright © 2019 Alfian Losari. All rights reserved.
//

import UIKit
import IGDB_SWIFT_API
import Kingfisher

class GameCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!

    func configure(_ game: Proto_Game) {
        let coverId = game.cover.imageID
        if !coverId.isEmpty {
            let imageURL = imageBuilder(imageID: coverId, size: .COVER_BIG, imageType: .PNG)
            let url = URL(string: imageURL)!
            imageView.kf.setImage(with: url)
        } else {
            imageView.image = nil
        }
    }

}
