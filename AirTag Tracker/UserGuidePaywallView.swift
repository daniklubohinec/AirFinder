//
//  FirstPaywallView.swift
//  AirTag Tracker
//
//  Created by DANIEL KVIRKVELIA on 4.01.25.
//

import SwiftUI
import Dependiject
import Defaults
import Adapty
import Pow

struct UserGuidePaywallView: View {
    
    @Store var application = Factory.shared.resolve(AppUserProtocol.self)
    @Store var purchase = Factory.shared.resolve(RemotePurchaseProtocol.self)
    
    @State var fetched: Bool = true
    @State var isPresented: Bool = false
    @State var failed: Bool = false
    
    @State var review: Bool = true
    
    let paywall: UserGuidePaywallModel
    
    init(paywall: UserGuidePaywallModel) {
        self.paywall = paywall
        _fetched = State(initialValue: paywall.configuration.needToLoad)
        _review = State(initialValue: paywall.configuration.review)
    }
    
    var body: some View {
        VStack(spacing: .zero) {
            Spacer()
            VStack {
                Spacer()
                VStack(spacing: 12) {
                    Text(UserGuideSteps.paywall.title)
                        .font(.semiBold(size: 32))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 20)
                    Text(purchaseSubtitle())
                        .font(.regular(size: 15))
                        .foregroundStyle(review ? .black : .hex000000O30)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ProgressView(value: 80, total: 100)
                        .tint(.hex495DF6)
                        .progressViewStyle(.linear)
                        .padding(.top, review ? 0 : 14)
                        .padding(.bottom, review ? 0 : 14)
                        .padding(.horizontal, 4)
                        .opacity(review ? 0 : 1)
                    
                    AppMainButton(title: purchaseTitle(), subtitle: review ? "Auto renewable. Cancel anytime" : nil,  withPulsation: true, action: makePurchase)
                        .background(Color.white)
                    
                    InfoView {
                        Task {
                            await purchase.restorePurchases()
                            if purchase.isPrem {
                                Defaults[.welcomeFlowEnded] = true
                            } else {
                                isPresented = true
                            }
                        }
                    }
                    .padding(.bottom, 10)
                    
                }
                .foregroundStyle(Color.black)
                .padding(.horizontal, 16)
                .background(.white, in: .rect(cornerRadius: 20))
            }
            .padding(.horizontal, .zero)
        }
        .background {
            Image(review ? .hsdjfsdhjfshjdf44 : .hsdjfsdhjfshjdf4)
                .resizable()
                .ignoresSafeArea(edges: .top)
                .scaledToFill()
                .padding(.bottom, 155)
                .padding(.horizontal, -39)
        }
        .background(.white)
        .overlay(alignment: .topTrailing) {
            if fetched {
                Image(.dsfgsdfdsf)
                    .padding(.trailing, 30)
                    .padding(.top, 14)
                    .foregroundStyle(Color(hex: paywall.configuration.color))
                    .onTapGesture {
                        Defaults[.welcomeFlowEnded] = true
                    }
            }
        }
        .task { await sleepWhileLoading() }
        .alert("Error", isPresented: $isPresented) {
            Button {
                isPresented = false
            } label: {
                Text("OK")
            }
        } message: {
            Text("No active subscriptions to restore")
        }
        .overlay {
            if purchase.fetching || purchase.fetchingRestore {
                ZStack {
                    Color.black.opacity(0.3)
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.large)
                }
                .ignoresSafeArea()
            }
        }
        .alert("Oops...", isPresented: $failed) {
            Button {
                failed = false
            } label: {
                Text("Cancel")
            }
            Button(role: .cancel, action: makePurchase) {
                Text("Try again")
            }
        } message: {
            Text("Something went wrong.\nPlease try again")
        }
        .onChange(of: purchase.fetching) { processing in
            if !processing,
               paywall.configuration.checked == nil,
               !purchase.isPrem {
                failed = true
            }
        }
    }
    
    func purchaseSubtitle() -> String {
        let start = "Get started with tracking lost devices for free for 3 days, then for only "
        if let price = paywall.product.localizedPrice {
            return start + priceDescription(price: price, per: true)
        } else {
            let currency = paywall.product.currencySymbol ?? ""
            return start + currency + priceDescription(price: "\(paywall.product.price)", per: true)
            
        }
    }
    
    func sleepWhileLoading() async {
        if !fetched {
            do {
                try await Task.sleep(nanoseconds: 4_000_000_000)
                fetched = true
            } catch {
                //just in case
                fetched = true
            }
        }
    }
    
    func priceDescription(price: String, per: Bool = false) -> String {
        price + (per ? " per week" : "/week")
    }
    
    func purchaseTitle() -> String {
        
        if review == false {
            return "Continue"
        } else if let price = paywall.product.localizedPrice {
            return "Try 3-Day Trial, then " + priceDescription(price: price)
        }else {
            let currency = paywall.product.currencySymbol ?? ""
            return "Try 3-Day Trial, then " + priceDescription(price: "\(currency) \(paywall.product.price)")
        }
        
        //        if let priceTitle = paywall.configuration.fullPricingTitle {
        //            return priceTitle
        //        } else if let price = paywall.product.localizedPrice {
        //            return "3-day Free Trial then " + priceDescription(price: price)
        //        } else {
        //            let currency = paywall.product.currencySymbol ?? ""
        //            return "3-day Free Trial then " + priceDescription(price: "\(currency) \(paywall.product.price)")
        //        }
    }
    
    func makePurchase() {
        HapticGenerator.shared.generateImpact()
        Task {
            await purchase.makePurchase(product: paywall.product)
            if purchase.isPrem {
                Defaults[.welcomeFlowEnded] = true
            } else {
                failed = false
            }
        }
    }
}
