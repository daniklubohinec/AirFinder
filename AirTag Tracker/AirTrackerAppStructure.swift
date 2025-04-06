//
//  AirTrackerAppStructure.swift
//  AirTag Tracker
//
//  Created by DANIEL KVIRKVELIA on 4.01.25.
//

import SwiftUI
import Dependiject

@main
struct AirTrackerAppStructure: App {
    init() {
        appearance()
        register()
    }
    
    func register() {
        Factory.register {
            Service(.singleton, SecureStorageManager.self) { _ in
                UserKeychainManager()
            }
            Service(.singleton, RemotePurchaseProtocol.self) { r in
                RemotePurchase(secureStorage: r.resolve(SecureStorageManager.self))
            }
            Service(.singleton, AppUserProtocol.self) { _ in
                Application()
            }
            Service(.singleton, LocationUserDataProtocol.self) { _ in
                LocationUserService()
            }
            Service(.singleton, BluetoothUserProtocol.self) { resolver in
                BluetoothUserManager(locationService: resolver.resolve(LocationUserDataProtocol.self))
            }
        }
    }
    
    func appearance() {
        UITableView.appearance().showsVerticalScrollIndicator = false
        UIScrollView.appearance().showsVerticalScrollIndicator = false
    }
    
    var body: some Scene {
        WindowGroup {
            AppProviderView()
        }
    }
}
