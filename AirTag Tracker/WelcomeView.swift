//
//  WelcomeView.swift
//  AirTag Tracker
//
//  Created by DANIEL KVIRKVELIA on 4.01.25.
//

import SwiftUI
import Defaults
import Dependiject

struct WelcomeView: View {
    
    @Store var application = Factory.shared.resolve(AppUserProtocol.self)
    @Store var purchase = Factory.shared.resolve(RemotePurchaseProtocol.self)
    @State var selectedPage: UserGuideSteps = .welcome
    
    @State var review = true
    
    var body: some View {
        if selectedPage == .paywall,
           let paywall = purchase.firstPaywall {
            UserGuidePaywallView(paywall: paywall)
//            let paywall = purchase.secondPaywall {
//            UIPaywallView(paywall: paywall) {}
        } else {
            WelcomeStep(step: selectedPage, nextAction: nextStep)
        }
    }
    
    func nextStep() {
        switch selectedPage {
        case .welcome:
            selectedPage = .location
        case .location:
            selectedPage = .organize
            if purchase.firstPaywall?.configuration.review == false {
                application.requestReview()
            }
        case .organize:
            if purchase.paywallsLoaded {
                selectedPage = .paywall
            } else {
                Defaults[.welcomeFlowEnded] = true
                break
            }
        case .paywall:
            Defaults[.welcomeFlowEnded] = true
            break
        }
    }
}

struct WelcomeStep: View {
    
    @Store var application = Factory.shared.resolve(AppUserProtocol.self)
    @Store var purchase = Factory.shared.resolve(RemotePurchaseProtocol.self)
    
    @State var review = true
    
    let step: UserGuideSteps
    let nextAction: () -> ()
    
    var body: some View {
        VStack(spacing: .zero) {
            VStack {
                Spacer()
                VStack(spacing: 10) {
                    Text(step.title)
                        .font(.semiBold(size: 32))
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.black)
                        .minimumScaleFactor(0.01)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(2)
                        .padding(.top, 20)
                        .padding(.trailing, 48)
                    Text(step.description)
                        .font(.regular(size: 15))
                        .foregroundStyle(purchase.firstPaywall?.configuration.review ?? true ? .black : .hex000000O30)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .minimumScaleFactor(0.01)
                        .lineLimit(2)
                        .padding(.bottom, 14)
                    ProgressView(value: Float((step.rawValue + 1) * 20), total: 100)
                        .tint(.hex495DF6)
                        .progressViewStyle(.linear)
                        .padding(.bottom, 14)
                        .padding(.horizontal, 4)
                    AppMainButton(title: "Continue", withPulsation: true) {
                        nextAction()
                        HapticGenerator.shared.generateImpact()
                    }
                        .frame(height: 66)
                        .frame(maxWidth: .infinity)
                }
                .foregroundStyle(Color.black)
                .padding(.horizontal, 16)
                .background(.white, in: .rect(cornerRadius: 20))
                .frame(height: 335)
            }
            .padding(.horizontal, .zero)
            .ignoresSafeArea(edges: .top)
        }
        .background {
            step.backgroundImage
                .resizable()
                .ignoresSafeArea(edges: .top)
                .scaledToFill()
                .padding(.bottom, 155)
                .padding(.horizontal, -39)
        }
        .background(.white)
    }
}
