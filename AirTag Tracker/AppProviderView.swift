//
//  AppProviderView.swift
//  AirTag Tracker
//
//  Created by DANIEL KVIRKVELIA on 4.01.25.
//

import SwiftUI
import Defaults
import Dependiject
import NavigationBackport

enum DistributionViewType {
    
    case onboarding
    case main
    case launch
}

struct AppProviderView: View {
    
    @Store var purchase = Factory.shared.resolve(RemotePurchaseProtocol.self)
    @Store var application = Factory.shared.resolve(AppUserProtocol.self)
    @State var type: DistributionViewType = .launch
    
    @Default(.welcomeFlowEnded) var welcomeFlowEnded
    
    var body: some View {
        Group {
            switch type {
            case .onboarding:
                WelcomeView()
            case .main:
                AppNavScreensView()
            case .launch:
                LoadingView()
            }
        }
        .task {
            await purchase.checkPurchases()
            await purchase.getPaywalls()
            if welcomeFlowEnded {
                type = .main
            } else {
                type = .onboarding
            }
        }
        .onChange(of: welcomeFlowEnded) { finished in
            type = finished ? .main : .onboarding
        }
    }
}

struct LoadingView: View {
    
    var body: some View {
        VStack {
            Spacer()
            Image(.uierteuritdssd)
                .padding(0)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { FirstLayerView() }
    }
}
