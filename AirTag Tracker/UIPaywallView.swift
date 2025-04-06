//
//  UIPaywallView.swift
//  AirTag Tracker
//
//  Created by DANIEL KVIRKVELIA on 4.01.25.
//

import SwiftUI
import Dependiject
import Adapty

struct UIPaywallView: View {
    
    @Store var application = Factory.shared.resolve(AppUserProtocol.self)
    @Store var purchase = Factory.shared.resolve(RemotePurchaseProtocol.self)
    
    @State var loaded: Bool = true
    @State var isPresented: Bool = false
    @State var failed: Bool = false
    @State var currentPeriod: PurchasePeriod = .week
    
    @State var review: Bool = true
    
    let paywall: UIPaywallModel
    let close: () -> ()
    
    init(paywall: UIPaywallModel, close: @escaping () -> Void) {
        self.paywall = paywall
        self._loaded = State(initialValue: paywall.config.needToLoad)
        self._review = State(initialValue: paywall.config.review)
        self.close = close
    }
    
    var body: some View {
        VStack(spacing: .zero) {
            Spacer()
            VStack {
                VStack(spacing: 12) {
                    Text("Get Full Access")
                        .font(.semiBold(size: 32))
                        .multilineTextAlignment(.leading)
                        .padding(.top, 20)
                        .minimumScaleFactor(0.01)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 4) {
                        view(for: convert(localizedPrice: paywall.weekSubscription.localizedPrice ?? "",
                                          to: .week),
                             period: .week)
                        view(for: convert(localizedPrice: paywall.monthSubscription.localizedPrice ?? "",
                                          to: .month),
                             period: .month)
                        view(for: convert(localizedPrice: paywall.yearSubscription.localizedPrice ?? "",
                                          to: .year),
                             period: .year)
                    }
                    .padding(.bottom, 10)
                    
                    AppMainButton(title: purchaseTitle, subtitle: review ? "Auto renewable. Cancel anytime" : nil, withPulsation: true, action: makePurchase)
                        .background(Color.white)
                    
                    InfoView {
                        Task {
                            await purchase.restorePurchases()
                            if purchase.isPrem {
                                close()
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
        .background() {
            Image(.hsdjfsdhjfshjdf4)
                .resizable()
                .ignoresSafeArea(edges: .top)
                .scaledToFill()
                .padding(.bottom, 155)
                .padding(.horizontal, -39)
        }
        
        .background(.white)
        .overlay(alignment: .topTrailing) {
            if loaded {
                Image(.dsfgsdfdsf)
                    .padding(.trailing, 16)
                    .padding(.top, 16)
                    .foregroundStyle(Color(hex: paywall.config.color))
                    .onTapGesture {
                        close()
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
               paywall.config.checked == nil,
               !purchase.isPrem {
                failed = true
            }
        }
        .onChange(of: currentPeriod) { _ in
            HapticGenerator.shared.generateImpact()
        }
    }
    
    func sleepWhileLoading() async {
        if !loaded {
            do {
                try await Task.sleep(nanoseconds: 4 * 1_000_000_000)
                loaded = true
            } catch {
                //just in case
                loaded = true
            }
        }
    }
    
    var purchaseTitle: String {
        if review == false {
            return "Continue"
        } else {
            return price(for: currentProduct, period: currentPeriod)
        }
    }
    
    func price(for product: AdaptyPaywallProduct, period: PurchasePeriod) -> String {
        let start = "Start 3-Day Free Trial then "
        if let price = product.localizedPrice {
            return start + price + period.subtitle
        } else {
            let userCurrency = product.currencySymbol ?? ""
            return start + userCurrency + "\(product.price)" + period.subtitle
        }
    }
    
    func makePurchase() {
        HapticGenerator.shared.generateImpact()
        Task {
            await purchase.makePurchase(product: currentProduct)
            if purchase.isPrem {
                close()
            } else {
                failed = false
            }
        }
    }
    
    var currentProduct: AdaptyPaywallProduct {
        switch currentPeriod {
        case .week:
            paywall.weekSubscription
        case .month:
            paywall.monthSubscription
        case .year:
            paywall.yearSubscription
        }
    }
    
    @ViewBuilder
    func view(for product: String, period: PurchasePeriod) -> some View {
        HStack {
            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    Text(period.title)
                        .font(.bold(size: 16))
                        .foregroundStyle(.black)
                    if period.isPopular {
                        Text("Popular".uppercased())
                            .font(.semiBold(size: 11))
                            .foregroundStyle(.hex495DF6)
                            .padding(.vertical, 2)
                            .padding(.horizontal, 4)
                            .background(Color.hex495DF6.opacity(0.3), in: .rect(cornerRadius: 4))
                    }
                    if period.isSave {
                        Text("save 91%".uppercased())
                            .font(.semiBold(size: 11))
                            .foregroundStyle(.white)
                            .padding(.vertical, 2)
                            .padding(.horizontal, 4)
                            .background(LinearGradient(gradient: Gradient(colors: [.hexFFAA3B, .hexEE4747]), startPoint: .topLeading, endPoint: .bottomTrailing), in: .rect(cornerRadius: 4))
                    }
                    Spacer()
                }
                HStack(alignment: .bottom, spacing: .zero) {
                    Text("3 - Day Trial")
                        .font(.semiBold(size: 16))
                        .foregroundStyle(.hex495DF6)
                    Text(", then ")
                    Text(product)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Spacer()
            Group {
                if period == currentPeriod {
                    Image(.gfgsgfsdfsd)
                } else {
                    Image(.ajufadfadf)
                }
            }
        }
        .font(.regular(size: 12))
        .foregroundStyle(.black)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(period == currentPeriod ? .hex495DF6 : .clear, lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(period == currentPeriod ? .hex495DF6O15 : .hex000000O5)
                )
        }
        .onTapGesture {
            currentPeriod = period
        }
    }
    
    func convert(localizedPrice: String, to period: PurchasePeriod) -> String {
        // Parse the numeric part of the price
        let numberString = localizedPrice.components(separatedBy: CharacterSet(charactersIn: "0123456789.,").inverted).joined()
        
        // Parse the currency symbol
        let currencySymbol = localizedPrice.components(separatedBy: CharacterSet(charactersIn: "0123456789., /")).joined().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Determine the decimal separator (comma or dot)
        let decimalSeparator = numberString.contains(",") ? "," : "."
        
        // Initialize a number formatter for parsing
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.currencySymbol = currencySymbol
        numberFormatter.locale = Locale.current
        numberFormatter.decimalSeparator = decimalSeparator
        
        // Convert the price string to a numeric value
        guard let monthlyPrice = numberFormatter.number(from: numberString) else {
            return localizedPrice
        }
        
        // Calculate the daily price assuming 30 days in a month
        let dailyPrice = monthlyPrice.doubleValue / 30.0
        
        // Format the daily price to a string
        numberFormatter.numberStyle = .currency
        numberFormatter.decimalSeparator = Locale.current.decimalSeparator
        let formattedDailyPrice = numberFormatter.string(from: NSNumber(value: dailyPrice))
        
        // Return the original price and the daily price in the desired format
        if let formattedDailyPrice {
            return "\(localizedPrice) (\(formattedDailyPrice)/day)"
        } else {
            return localizedPrice
        }
    }
    
}

enum PurchasePeriod: CaseIterable, Identifiable {
    
    case week
    case month
    case year
    
    var id: Self { self }
    
    var title: String {
        
        switch self {
        case .week:
            "1 Week"
        case .month:
            "1 Month"
        case .year:
            "1 Year"
        }
    }
    
    var subtitle: String {
        switch self {
        case .week:
            "/week"
        case .month:
            "/month"
        case .year:
            "/year"
        }
    }
    
    var isPopular: Bool {
        self == .month
    }
    
    var isSave: Bool {
        self == .year
    }
}
