//
//  ImageBlockView.swift
//  LiquidTextPDFEditor
//
//  Created by Noman belim on 17/02/26.
//

import Foundation
import UIKit

class ImageBlockView: UIView {

    private let imageView = UIImageView()

    init(image: UIImage) {
        super.init(frame: CGRect(x: 40, y: 40, width: 160, height: 120))

        backgroundColor = .white
        layer.cornerRadius = 8
        layer.shadowOpacity = 0.2
        layer.shadowRadius = 4

        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        imageView.frame = bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        addSubview(imageView)

        let pan = UIPanGestureRecognizer(target: self,
                                         action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: superview)
        center = CGPoint(x: center.x + translation.x,
                         y: center.y + translation.y)
        gesture.setTranslation(.zero, in: superview)
    }
}
