//
//  UserFavouriteView.swift
//  AirTag Tracker
//
//  Created by DANIEL KVIRKVELIA on 4.01.25.
//

import SwiftUI
import Dependiject
import Defaults

struct UserFavouriteView: View {
    
    @Store var locService = Factory.shared.resolve(LocationUserDataProtocol.self)
    @Store var application = Factory.shared.resolve(AppUserProtocol.self)
    
    @State var hasLocation: Bool
    
    let openDevice: (UserDeviceInformation) -> ()
    
    @State var sortedData: [UserDeviceInformation]
    
    init(hasLocation: Bool, openDevice: @escaping (UserDeviceInformation) -> ()) {
        self._hasLocation = State(initialValue: hasLocation)
        self._sortedData =  State(initialValue: Defaults[.favorites].sorted { $0.updated > $1.updated })
        
        self.openDevice = openDevice
    }
    
    var body: some View {
        ZStack {
            Color.hexE9E9E9
                .ignoresSafeArea()
            VStack(spacing: 8) {
                headerView
                
                if !hasLocation {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if sortedData.isEmpty {
                    VStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Text("No Saved Devices")
                                .font(.bold(size: 24))
                                .foregroundStyle(.black)
                                .multilineTextAlignment(.center)
                            Text("Start searching to find devices \naround you.")
                                .font(.regular(size: 15))
                                .foregroundStyle(.black)
                                .multilineTextAlignment(.center)
                            AppMainButton(title: "Search Devices", withPulsation: false, icon: Image("sdhfjsdffds")) {
                                HapticGenerator.shared.generateImpact()
                                application.path.append(UserScreenDestinations.search)
                            }
                            .padding(.top, 16)
                            .padding(.horizontal, 60)
                        }
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack {
                            Spacer()
                                .frame(height: 20)
                            ForEach(sortedData) { device in
                                DeviceRow(device: device,
                                          type: .favorite,
                                          showWhen: true,
                                          distance: distance(to: device),
                                          action: { tapAction(device: device) },
                                          secondaryAction: { remove(device: device) })
                            }
                            Spacer()
                                .frame(height: 20)
                        }
                    }
                }
            }
        }
        .task {
            guard !hasLocation else { return }
            if locService.authStatus == .allowed {
                let _ = await locService.fetchPosition()
                hasLocation = true
            } else {
                // Location not granted, just show the list without distance
                hasLocation = true
            }
        }
        .navigationBarHidden(true)
    }
    
    func remove(device: UserDeviceInformation) {
        HapticGenerator.shared.generateImpact()
        withAnimation {
            sortedData.removeAll(where: { device.id == $0.id })
            Defaults[.favorites].removeAll(where: { $0.id == device.id })
        }
    }
    
    func tapAction(device: UserDeviceInformation) {
        HapticGenerator.shared.generateImpact()
        openDevice(device)
    }
    
    func distance(to device: UserDeviceInformation) -> String {
        if let distance = locService.calculateDistance(to: device.coordinates) {
            return distance.formattedDistance()
        }
        return Double(device.distance).formattedDistance()
    }
}

extension UserFavouriteView {
    private var headerView: some View {
        HStack {
            backButton
            Spacer()
            Text("Saved Devices")
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
}
