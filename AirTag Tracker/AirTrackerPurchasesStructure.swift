//
//  AirTrackerPurchasesStructure.swift
//  AirTag Tracker
//
//  Created by DANIEL KVIRKVELIA on 4.01.25.
//

import Foundation
import Dependiject
import Adapty

protocol RemotePurchaseProtocol: AnyObservableObject {
    var paywallsLoaded: Bool {
        get
    }
    var fetchingRestore: Bool {
        get
    }
    var fetching: Bool {
        get
    }
    var isPrem: Bool {
        get
    }
    
    var firstPaywall: UserGuidePaywallModel? {
        get
    }
    var secondPaywall: UIPaywallModel? {
        get
    }
    
    func configure()
    func getPaywalls() async
    func checkPurchases() async
    func makePurchase(
        product: AdaptyPaywallProduct
    ) async
    func restorePurchases() async
}

final class RemotePurchase: RemotePurchaseProtocol, ObservableObject {
    
    @Published var fetchingRestore: Bool = false
    
    @Published var fetching: Bool = false
    @Published var isPrem: Bool = false
    
    @Published var firstPaywall: UserGuidePaywallModel?
    @Published var secondPaywall: UIPaywallModel?
    
    let secureStorage: SecureStorageManager
    
    init(
        secureStorage: SecureStorageManager
    ) {
        self.secureStorage = secureStorage
        self.configure()
    }
    
    func configure() {
        Adapty
            .activate(
                "public_live_gEudUM7m.wmiO1ZPb4OLeTA0eFIJF"
            )
    }
    
    var paywallsLoaded: Bool {
        firstPaywall != nil && secondPaywall != nil
    }
    
    @MainActor
    func checkPurchases() async {
        if let currentStatus = secureStorage.retrieveSubscriptionDetails(),
           currentStatus.validUntil > Date.now {
            isPrem = true
            return
        } else {
            do {
                let profile = try await Adapty.getProfile()
                isPrem = profile
                    .accessLevels["premium"]?.isActive ?? false
                if isPrem, let expiration = profile.accessLevels["premium"]?.expiresAt {
                    secureStorage
                        .storeSubscriptionExpiry(
                            date: expiration
                        )
                } else {
                    secureStorage
                        .removeStoredSubscription()
                }
            } catch {
                isPrem = false
            }
        }
    }
    
    func getPaywalls() async {
        do {
            let paywall = try await Adapty.getPaywall(
                placementId: PaywallCoordinationData.first.key
            )
            
            let data = retrievePaywall(
                paywall: paywall
            )
            
            guard let data else {
                return
            }
            try await getPaywallProducts(
                paywall: paywall,
                data: data,
                type: .first
            )
            try await getPaywallProducts(
                paywall: paywall,
                data: data,
                type: .second
            )
            
        } catch {
            //do nothing for now, just continue using an app
        }
    }
    
    private func retrievePaywall(
        paywall: AdaptyPaywall
    ) -> (
        Data?
    ) {
        guard let json = paywall.remoteConfig?.jsonString,
              let data = json.data(
                using: .utf8
              ) else {
            return nil
        }
        return data
    }
    
    private func getPaywallProducts(
        paywall: AdaptyPaywall,
        data: Data,
        type: PaywallCoordinationData
    ) async throws {
        
        let config = try JSONDecoder().decode(
            RemoteUserConfigModel.self,
            from: data
        )
        let products: [AdaptyPaywallProduct] = try await Adapty.getPaywallProducts(
            paywall: paywall
        )
        switch type {
        case .first:
            guard let product = products.first(
                where: {
                    $0.vendorProductId.hasPrefix(
                        "699_"
                    )
                }) else {
                throw NSError(
                    domain: "",
                    code: -1
                )
            }
            firstPaywall = UserGuidePaywallModel(
                configuration: config,
                product: product
            )
        case .second:
            guard let weeklyProduct = products.first(
                where: {
                    $0.vendorProductId.hasPrefix(
                        "699_"
                    )
                }),
                  let monthlyProduct = products.first(
                    where: {
                        $0.vendorProductId.hasPrefix(
                            "1499_"
                        )
                    }),
                  let yearlyProduct = products.first(
                    where: {
                        $0.vendorProductId.hasPrefix(
                            "3199_"
                        )
                    }) else {
                throw NSError(
                    domain: "",
                    code: -1
                )
            }
            secondPaywall = UIPaywallModel(config: config, weekSubscription: weeklyProduct, monthSubscription: monthlyProduct, yearSubscription: yearlyProduct)
        }
    }
    
    func makePurchase(
        product: AdaptyPaywallProduct
    ) async {
        do {
            fetching = true
            let result = try await Adapty.makePurchase(
                product: product
            )
            isPrem = (
                result.profile.accessLevels["premium"]?.isActive == true
            )
            fetching = false
            if isPrem, let expiration = result.profile.accessLevels["premium"]?.expiresAt {
                secureStorage
                    .storeSubscriptionExpiry(
                        date: expiration
                    )
            }
        } catch {
            isPrem = false
            fetching = false
        }
    }
    
    func restorePurchases() async {
        do {
            fetchingRestore = true
            let profile = try await Adapty.restorePurchases()
            isPrem = (
                profile.accessLevels["premium"]?.isActive == true
            )
            if isPrem, let expiration = profile.accessLevels["premium"]?.expiresAt {
                secureStorage
                    .storeSubscriptionExpiry(
                        date: expiration
                    )
            }
            fetchingRestore = false
        } catch {
            isPrem = false
            fetchingRestore = false
        }
    }
}
