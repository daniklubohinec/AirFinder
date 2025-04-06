//
//  AppNavScreensView.swift
//  AirTag Tracker
//
//  Created by DANIEL KVIRKVELIA on 4.01.25.
//

import SwiftUI
import NavigationBackport
import Dependiject

struct AppNavScreensView: View {
    
    @Store var bluetoothManager = Factory.shared.resolve(BluetoothUserProtocol.self)
    @Store var locService = Factory.shared.resolve(LocationUserDataProtocol.self)
    @Store var application = Factory.shared.resolve(AppUserProtocol.self)
    @Store var purchase = Factory.shared.resolve(RemotePurchaseProtocol.self)
    
    @Environment(\.scenePhase) var phase
    
    @State var showBluetoothWarning = false
    @State var paywall: UIPaywallModel?
    @State var noInternetConnection = false
    
    var body: some View {
        NBNavigationStack(path: $application.path) {
            VStack {
                toolbar
                Image(.gfdjgdfgdfg)
                    .resizable()
                    .scaledToFit()
                    .padding(.top, 10)
                    .padding(.horizontal, 16)
                    .onTapGesture { startSearch() }
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 4)
                HStack {
                    Image(.ewyurwerw)
                        .resizable()
                        .frame(maxWidth: .infinity, maxHeight: 214)
                        .onTapGesture {
                            HapticGenerator.shared.generateImpact()
                            application.path.append(UserScreenDestinations.saved)
                        }
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 4)
                    Image(.euwriwerwe)
                        .resizable()
                        .frame(maxWidth: .infinity, maxHeight: 214)
                        .onTapGesture { startSearch() }
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 4)
                }
                .padding(.horizontal, 16)
                Image(.yrewweewr)
                    .resizable()
                    .frame(maxWidth: .infinity, maxHeight: 70)
                    .padding(.horizontal, 16)
                    .onTapGesture {
                        HapticGenerator.shared.generateImpact()
                        application.path.append(UserScreenDestinations.settings)
                    }
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 4)
                Spacer()
            }
            .background(FirstLayerView().ignoresSafeArea())
            .nbNavigationDestination(for: UserDeviceInformation.self) { info in
                BluetoothSearchingView(device: info)
            }
            .nbNavigationDestination(for: UserScreenDestinations.self) { destination in
                switch destination {
                case .search:
                    ScanningUserDeviceView(showDeviceView: open)
                        .onDisappear { bluetoothManager.haltScanning() }
                case .saved:
                    UserFavouriteView(
                        hasLocation: locService.currentPos != nil,
                        openDevice: open
                    )
                case .settings:
                    ApplicationSetupView()
                }
            }
            .navigationBarHidden(true)
        }
        .ignoresSafeArea(edges: .vertical)
        .overlay {
            if showBluetoothWarning { warningOverlay }
        }
        .fullScreenCover(item: $paywall) { pw in
            UIPaywallView(paywall: pw) { paywall = nil }
        }
        .alert("Error", isPresented: $noInternetConnection) {
            Button("OK", role: .cancel) { noInternetConnection = false }
        } message: {
            Text("You do not have an active subscription and are not connected to the internet.\nConnect to the internet and try again.")
        }
        .onChange(of: phase) { newPhase in
            if newPhase == .active && !purchase.isPrem {
                self.paywall = purchase.secondPaywall
            }
        }
    }
    
    var warningOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack {
                Spacer()
                VStack {
                    Image(.sdkljfsdjkf)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 56)
                        .padding(.vertical, 6)
                    Text("Enable Bluetooth Access")
                        .font(.bold(size: 24))
                        .foregroundStyle(.black)
                        .padding(.bottom, 4)
                    Text("Please enable Bluetooth in your iPhone settings to search for nearby devices.")
                        .font(.regular(size: 15))
                        .foregroundStyle(.black)
                        .padding(.bottom, 10)
                    Button {
                        openSettings()
                    } label: {
                        Text("Go to Settings")
                            .frame(maxWidth: .infinity)
                            .font(.semiBold(size: 16))
                            .foregroundStyle(.white)
                            .frame(height: 66)
                            .background(Color.hex495DF6.cornerRadius(16))
                    }
                    Button {
                        showBluetoothWarning = false
                    } label: {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                            .font(.semiBold(size: 16))
                            .foregroundStyle(.hex495DF6)
                            .frame(height: 66)
                            .background(Color.black.opacity(0.05))
                            .cornerRadius(16)
                    }
                }
                .padding(16)
                .background(Color.white.cornerRadius(28))
                .padding(.horizontal, 10)
            }
        }
    }
}

extension AppNavScreensView {
    var toolbar: some View {
        HStack(alignment: .center) {
            Text("Air Finder")
                .frame(maxWidth: .infinity, alignment: .center)
                .font(.bold(size: 28))
                .foregroundStyle(.black)
                .padding(.top, .zero)
        }
        .frame(height: 44)
        .padding(.horizontal, 16)
    }
    
    func startSearch() {
        HapticGenerator.shared.generateImpact()
        guard bluetoothManager.isBluetoothActive else {
            showBluetoothWarning = true
            return
        }
        application.path.append(UserScreenDestinations.search)
    }
    
    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        let app = UIApplication.shared
        app.open(url) { isSuccess in }
        showBluetoothWarning = false
    }
    
    func open(device: UserDeviceInformation) {
        HapticGenerator.shared.generateImpact()
        if purchase.isPrem {
            application.path.append(device)
        } else if let paywall = purchase.secondPaywall {
            self.paywall = paywall
        } else {
            noInternetConnection = true
        }
    }
}
