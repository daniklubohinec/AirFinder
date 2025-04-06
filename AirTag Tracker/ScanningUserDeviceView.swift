//
//  ScanningUserDeviceView.swift
//  AirTag Tracker
//
//  Created by DANIEL KVIRKVELIA on 4.01.25.
//

import SwiftUI
import Defaults
import Dependiject
import Combine

struct ScanningUserDeviceView: View {
    
    @Store var application = Factory.shared.resolve(AppUserProtocol.self)
    @Store var bleManager = Factory.shared.resolve(BluetoothUserProtocol.self)
    
    @State var isSearching: Bool = true
    @State var timerCancellable: AnyCancellable?
    
    @Default(.favorites) var favorites
    
    
    @State var favoritesItems: [UserDeviceInformation] = []
    @State var discoveredItems: [UserDeviceInformation] = []
    
    @State var section1ID = UUID()
    @State var section2ID = UUID()
    
    let showDeviceView: (UserDeviceInformation) -> ()
    
    func generateDataSource(_ devices: [UserDeviceInformation]) {
        favoritesItems = devices.filter { device in
            favorites.contains(where: { $0.id ==  device.id })
        }
        discoveredItems = devices.filter { device in
            !favorites.contains(where: { $0.id ==  device.id })
        }
    }
    
    func primaryAction(device: UserDeviceInformation) {
        if isSearching {
            stopTimer()
        }
        showDeviceView(device)
    }
    
    func secondaryAction(device: UserDeviceInformation, type: DeviceItemType) {
        HapticGenerator.shared.generateImpact()
        if !favorites.contains(where: { $0.id == device.id }) {
            if let index = discoveredItems.firstIndex(where: { $0.id == device.id }) {
                withAnimation {
                    var copy = device
                    copy.added = Date.now
                    bleManager.refreshDeviceInfo(copy)
                    favorites.append(copy)
                    discoveredItems.remove(at: index)
                    favoritesItems.append(device)
                }
            }
        } else {
            if let index = favoritesItems.firstIndex(where: { $0.id == device.id }) {
                withAnimation {
                    favorites.removeAll(where: { $0.id == device.id })
                    favoritesItems.remove(at: index)
                    discoveredItems.append(device)
                    discoveredItems = bleManager.discoveredDevices.filter { item in !favorites.contains(where: { $0.id == item.id }) }
                }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    HapticGenerator.shared.generateImpact()
                    application.path.removeLast()
                } label: {
                    Image(.fgkjdfgfgxv)
                        .resizable()
                        .frame(width: 40, height: 40)
                }
                Text(isSearching ? "Scanning..." : "Scan Results")
                    .font(.semiBold(size: 18))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, alignment: .center)
                Button {
                    HapticGenerator.shared.generateImpact()
                    isSearching = true
                    startSearch()
                } label: {
                    if isSearching {
                        isScanningProgressView()
                    } else {
                        Image(.sdkfsfjsdklfs)
                            .resizable()
                            .frame(width: 40, height: 40)
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(.hexE9E9E9)
            ScrollView {
                LazyVStack(spacing: 12) {
                    if !bleManager.favoriteDevices.isEmpty {
                        Section {
                            ForEach(bleManager.favoriteDevices) { device in
                                DeviceRow(device: device,
                                          type: .favorite,
                                          showWhen: true,
                                          action: { primaryAction(device: device) },
                                          secondaryAction: { secondaryAction(device: device, type: .favorite) })
                            }
                        } header: {
                            Text("Saved Devices (\(favoritesItems.count))")
                                .font(.semiBold(size: 18))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                        }
                        .id(section1ID)
                    }
                    
                    Section {
                        ForEach(bleManager.otherDevices) { device in
                            DeviceRow(device: device,
                                      type: .found,
                                      showWhen: true,
                                      action: { primaryAction(device: device) },
                                      secondaryAction: { secondaryAction(device: device, type: .found) })
                            
                        }
                    } header: {
                        Text(favoritesItems.isEmpty ? "All Devices (\(discoveredItems.count))" : "Other Devices")
                            .font(.semiBold(size: 18))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                    }
                    .id(section2ID)
                }
            }
            
            Spacer()
        }
        .background(.hexE9E9E9)
        .task { startSearch() }
        .onChange(of: bleManager.discoveredDevices) { devices in
            if isSearching {
                generateDataSource(devices)
            }
        }
        .onReceive(bleManager.triggerLocalDataUpdate) { _ in
            generateDataSource(bleManager.discoveredDevices)
        }
        .navigationBarHidden(true)
    }
    
    func startSearch() {
        if isSearching {
            bleManager.beginScanning(for: nil)
            startTimer()
        }
    }
    
    func startTimer() {
        timerCancellable = Timer.publish(every: 6, tolerance: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                stopTimer()
            }
    }
    
    func stopTimer() {
        if timerCancellable != nil {
            bleManager.haltScanning()
            isSearching = false
            timerCancellable?.cancel()
            timerCancellable = nil
        }
    }
    
}

struct isScanningProgressView: View {
    var body: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .hex8C8C8C))
    }
}
