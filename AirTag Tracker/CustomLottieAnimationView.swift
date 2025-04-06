//
//  CustomLottieAnimationView.swift
//  AirTag Tracker
//
//  Created by DANIEL KVIRKVELIA on 4.01.25.
//

import SwiftUI
import Lottie

struct CustomLottieAnimationView: UIViewRepresentable {
    
    var lottieFile: String
    var loopMode: LottieLoopMode = .loop
    var animationView = LottieAnimationView()
    
    func makeUIView(context: UIViewRepresentableContext<CustomLottieAnimationView>) -> UIView {
        let view = UIView()
        
        animationView.animation = LottieAnimation.named(lottieFile)
        animationView.contentMode = .scaleAspectFill
        animationView.loopMode = loopMode
        
        animationView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(animationView)
        
        NSLayoutConstraint.activate([
            animationView.widthAnchor.constraint(equalTo: view.widthAnchor),
            animationView.heightAnchor.constraint(equalTo: view.heightAnchor)
        ])
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<CustomLottieAnimationView>) {
        animationView.play()
    }
}
