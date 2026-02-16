//
//  TextBlockView.swift
//  LiquidTextPDFEditor
//
//  Created by Noman belim on 13/02/26.
//

import Foundation
import UIKit

class TextBlockView: UIView {
    
    private let label = UILabel()
    
    init(text: String) {
        super.init(frame: .zero)
        setupUI(text: text)
        addPanGesture()
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    private func setupUI(text: String) {
        
        backgroundColor = .white
        layer.cornerRadius = 8
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 8
        
        label.text = text
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 16)
        
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10)
        ])
        
        frame.size.height = 60
    }
    
    private func addPanGesture() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        addGestureRecognizer(pan)
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: superview)
        
        center = CGPoint(x: center.x + translation.x,
                         y: center.y + translation.y)
        
        gesture.setTranslation(.zero, in: superview)
    }
}
