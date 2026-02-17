//
//  TextBlockView.swift
//  LiquidTextPDFEditor
//
//  Created by Noman belim on 13/02/26.
//

import Foundation
import UIKit

import UIKit

final class TextBlockView: UIView, UIGestureRecognizerDelegate, UITextViewDelegate {

    let textView = UITextView()
    var blockPosition: CGPoint = .zero
    
    private var dragOffset: CGPoint = .zero
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupGesture()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .clear
        
        layer.cornerRadius = 8
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: 2)

        textView.frame = bounds
        textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        textView.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        textView.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        textView.isScrollEnabled = false
        textView.delegate = self
        
        addSubview(textView)
    }

    private func setupGesture() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        addGestureRecognizer(pan)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let superView = superview else { return }
        
        switch gesture.state {
            
        case .began:
            dragOffset = gesture.location(in: self)
            superView.bringSubviewToFront(self)
            
            UIView.animate(withDuration: 0.15) {
                self.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                self.layer.shadowOpacity = 0.35
            }

        case .changed:
            let location = gesture.location(in: superView)
            
            var newOrigin = CGPoint(
                x: location.x - dragOffset.x,
                y: location.y - dragOffset.y
            )
            
            // Keep inside parent bounds
            newOrigin.x = max(0, min(superView.bounds.width - bounds.width, newOrigin.x))
            newOrigin.y = max(0, min(superView.bounds.height - bounds.height, newOrigin.y))
            
            frame.origin = newOrigin
            blockPosition = newOrigin

        case .ended, .cancelled:
            UIView.animate(withDuration: 0.15) {
                self.transform = .identity
                self.layer.shadowOpacity = 0.2
            }

        default:
            break
        }
    }

    // 🔥 IMPORTANT: Allow drag + text editing together
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
