//
//  ApplicationSetupView.swift
//  AirTag Tracker
//
//  Created by DANIEL KVIRKVELIA on 4.01.25.
//

import SwiftUI
import Defaults
import Dependiject

struct ApplicationSetupView: View {
    
    @Environment(\.openURL) var openURL
    @Default(.measurement) var selectedUnit
    @Store var application = Factory.shared.resolve(AppUserProtocol.self)
    
    @State private var isPresented = false
    @State private var shareURL: URLToShare?
    
    var body: some View {
        VStack(spacing: 12) {
            headerView
            
            ScrollView {
                VStack(spacing: 12) {
                    distanceSection
                    actionsSection(
                        items: [
                            ("Contact Us", .vbcxvvbzcvzx, openContactUs),
                            ("Share App", .tryncvbvbxcv, shareWithFriends),
                            ("Rate Us", .tyitukigjgh, requestRate)
                        ]
                    )
                    actionsSection(
                        items: [
                            ("Terms of Use", .jghhafds, openTermsOfService),
                            ("Privacy Policy", .treerytry, openPrivacyPolicy),
                            ("Restore Purchases", .fdgdfgdfg, restorePurchases)
                        ]
                    )
                }
                .padding(.horizontal, 16)
            }
            .modifier(ScrollWhenNeedModifier())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 1)
        .background(Color.hexE9E9E9.ignoresSafeArea(edges: .vertical))
        .navigationBarHidden(true)
        .onChange(of: selectedUnit) { _ in
            HapticGenerator.shared.generateImpact()
        }
        .sheet(item: $shareURL) { url in
            ShearingBottomSheet(items: [url.url], url: $shareURL)
        }
    }
}

// MARK: - Subviews
extension ApplicationSetupView {
    private var headerView: some View {
        HStack {
            backButton
            Spacer()
            Text("Settings")
                .font(.semiBold(size: 18))
                .foregroundStyle(.black)
            Spacer()
            backButton.opacity(0)
        }
        .frame(height: 44)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    private var backButton: some View {
        Button {
            HapticGenerator.shared.generateImpact()
            application.path.removeLast()
        } label: {
            Image(.fgkjdfgfgxv)
                .resizable()
                .scaledToFit()
                .frame(height: 40)
        }
    }
    
    private var distanceSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(.eriuterutsdf)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 22)
                Text("Distance")
                    .font(.regular(size: 16))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            MeasurementSelection(selectedState: selectedUnit, switchAction: switchAction)
        }
        .padding(16)
        .background(Color.white, in: .rect(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 4)
    }
    
    private func actionsSection(items: [(String, ImageResource, () -> Void)]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                settingsItem(title: item.0, image: item.1, action: item.2)
                if index != items.count - 1 {
                    Color(.hex000000O5)
                        .frame(height: 1)
                }
            }
        }
        .background(Color.white, in: .rect(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 4)
    }
}

// MARK: - Components
extension ApplicationSetupView {
    private func settingsItem(title: String, image: ImageResource, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 22)
                Text(title)
                    .font(.regular(size: 16))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(.werwerf)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 20)
            }
            .frame(height: 62)
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Actions
extension ApplicationSetupView {
    private func shareWithFriends() {
        triggerHaptic()
        guard let url = URL(string: "https://apps.apple.com/app/id6739254297") else { return }
        shareURL = URLToShare(url: url)
    }
    
    private func switchAction(_ newState: MeasurementType) {
        selectedUnit = newState
    }
    
    private func requestRate() {
        triggerHaptic()
        guard let url = URL(string: "https://apps.apple.com/app/id6739254297") else { return }
        openURL(url)
    }
    
    private func openContactUs() {
        triggerHaptic()
        guard let url = URL(string: "mailto:daniel01kvirkvelia@icloud.com") else { return }
        openURL(url)
    }
    
    private func openPrivacyPolicy() {
        triggerHaptic()
        guard let url = URL(string: "http://project11522847.tilda.ws/privacy-policy") else { return }
        openURL(url)
    }
    
    private func openTermsOfService() {
        triggerHaptic()
        guard let url = URL(string: "http://project11522847.tilda.ws/terms-of-use") else { return }
        openURL(url)
    }
    
    private func restorePurchases() {
        triggerHaptic()
        // Restore purchases logic
    }
    
    private func triggerHaptic() {
        HapticGenerator.shared.generateImpact()
    }
}

// MARK: - Scroll Modifier
struct ScrollWhenNeedModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content.scrollBounceBehavior(.basedOnSize)
        } else {
            content
        }
    }
}

extension BluetoothSearchingView {
    
    var isFavorite: Bool {
        favorites.contains { $0.id == device.id }
    }
    
    var allowLocationTitle: String {
        locService.authStatus == .notRequested ? "Allow" : "Settings"
    }
}

// MARK: - functions
extension BluetoothSearchingView {
    
    func calculateDistance() -> Double? {
        if let deviceLocation = device.coordinates {
            return locService.calculateDistance(to: deviceLocation)
        }
        return nil
    }
    
    func favoriteAction() {
        HapticGenerator.shared.generateImpact()
        if isFavorite {
            favorites.removeAll(where: { $0.id == device.id })
            showRemoveFromFavorite = true
        } else {
            if let location = locService.currentPos {
                device.coordinates = LocationCoordinateService(location: location)
            }
            if !favorites.contains(where: { $0.id == device.id }) {
                device.added = Date.now
                favorites.append(device)
                bleManager.refreshDeviceInfo(device)
                showAddedToFavorite = true
            }
        }
    }
    
    func checkLocationServices(showError: Bool = true) {
        switch locService.authStatus {
        case .allowed:
            selectedState = .map
            locService.startLocationMonitoring()
        default:
            allowLocation()
        }
    }
    
    func allowLocation() {
        if locService.authStatus == .restricted {
            showLocationWarning = true
        } else {
            Task {
                let newStatus = await locService.requestAccess()
                if newStatus == .allowed {
                    locService.startLocationMonitoring()
                }
            }
        }
    }
    
    func deviceFound(at coordinates: LocationCoordinateService?) {
        device.coordinates = coordinates
        device.updated = Date.now
        bleManager.refreshDeviceInfo(device)
    }
}
