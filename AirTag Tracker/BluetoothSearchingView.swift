//
//  BluetoothSearchingView.swift
//  AirTag Tracker
//
//  Created by DANIEL KVIRKVELIA on 4.01.25.
//

import SwiftUI
import NavigationBackport
import Dependiject
import Defaults
import MapKit
import Lottie

enum DeviceSubView {
    
    case radar
    case map
    
    var image: Image {
        switch self {
        case .radar:
            Image(.gfdjkdfkgds)
        case .map:
            Image(.weriuewurwe)
        }
    }
    
    var title: String {
        switch self {
        case .radar:
            "Radar"
        case .map:
            "Map"
        }
    }
}

struct BluetoothSearchingView: View {
    
    @Store var application = Factory.shared.resolve(AppUserProtocol.self)
    @Store var bleManager = Factory.shared.resolve(BluetoothUserProtocol.self)
    @Store var locService = Factory.shared.resolve(LocationUserDataProtocol.self)
    
    @Default(.favorites) var favorites
    
    @State var selectedState: DeviceSubView = .radar
    @State var device: UserDeviceInformation
    @State var showBluetoothWarning: Bool = false
    @State var showLocationWarning: Bool = false
    @State var showAddedToFavorite = false
    @State var showRemoveFromFavorite = false
    
    @Environment(\.openURL) var openURL
    
    @ViewBuilder
    func selectorItem(for type: DeviceSubView) -> some View {
        VStack {
            HStack(spacing: 6) {
                Spacer()
                type.image
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: 24, height: 24)
                Text(type.title)
                    .font(.semiBold(size: 16))
                    .frame(maxHeight: .infinity, alignment: .center)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            
            ZStack(alignment: .bottom) {
                Rectangle()
                    .frame(height: 2)
                    .foregroundStyle(.black.opacity(0.1))
                if selectedState == type {
                    Rectangle()
                        .frame(height: 3)
                }
            }
        }
        .foregroundStyle(.hex495DF6)
        .opacity(selectedState == type ? 1 : 0.3)
        .onTapGesture {
            if type == .map {
                checkLocationServices()
            } else {
                selectedState = type
            }
        }
        .frame(height: 60)
    }
    
    var body: some View {
        VStack {
            VStack(spacing: 8) {
                HStack {
                    Button {
                        application.path.removeLast()
                    } label: {
                        Image(.fgkjdfgfgxv)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 40)
                    }
                    Text(device.name)
                        .font(.semiBold(size: 18))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .foregroundStyle(.black)
                    Button {
                        favoriteAction()
                    } label: {
                        Image(isFavorite ? .sdkjfsdkjfsdf : .sdfsdfds)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 40)
                    }
                }
                .frame(height: 44)
                .padding(.horizontal, 16)
                HStack(spacing: .zero) {
                    selectorItem(for: .radar)
                    selectorItem(for: .map)
                }
                .frame(height: 60)
            }
            .background(.white.opacity(0.1))
            
            switch selectedState {
            case .radar:
                Spacer()
                signalTrackingView
                    .padding(.top, 20)
                    .offset(y: -100)
            case .map:
                UserMapViewProvider(device: device,
                                    distanceToDevice: calculateDistance())
                .equatable()
                .padding(.top, -10)
                .ignoresSafeArea(edges: .bottom)
            }
            Spacer()
        }
        .background {
            FirstLayerView()
        }
        .alert("No access to location", isPresented: $showLocationWarning, actions: {
            Button(role: .cancel) {
                guard let url = URL(string: UIApplication.openSettingsURLString) else {
                    showLocationWarning = false
                    return
                }
                openURL(url)
            } label: {
                Text("Settings")
            }
            Button {
                showLocationWarning = false
            } label: {
                Text("Cancel")
            }
        }, message: {
            Text("Go to settings and allow the app to use device location")
        })
        .ignoresSafeArea(edges: .bottom)
        .task {
            bleManager.beginScanning(for: device.id)
            allowLocation()
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: .zero) {
                if selectedState == .radar {
                    Text("The closer you are,the stronger the signal")
                        .font(.semiBold(size: 22))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.black)
                        .padding([.bottom, .horizontal], 12)
                }
                Button {
                    HapticGenerator.shared.generateImpact()
                    deviceFound(at: LocationCoordinateService(location: locService.currentPos))
                    application.path.removeLast()
                } label: {
                    HStack(spacing: 8) {
                        Spacer()
                        Text("Found it!")
                            .font(.semiBold(size: 16))
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(.hex495DF6, in: .rect(cornerRadius: 18))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
            
        }
        .overlay {
            if showAddedToFavorite {
                ZStack {
                    Text("Added to favorites")
                        .font(.medium(size: 14))
                        .foregroundStyle(.white)
                        .padding(20)
                        .background(Color.black.opacity(0.3), in: .rect(cornerRadius: 8))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                showAddedToFavorite = false
                            }
                        }
                    
                }
            } else if showRemoveFromFavorite {
                ZStack {
                    Text("Removed from favorites")
                        .font(.medium(size: 14))
                        .foregroundStyle(.white)
                        .padding(20)
                        .background(Color.black.opacity(0.3), in: .rect(cornerRadius: 8))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                showRemoveFromFavorite = false
                            }
                        }
                }
            }
        }
        .onReceive(bleManager.deviceLocated) { coordinates in
            deviceFound(at: coordinates)
        }
        .navigationBarBackButtonHidden()
        .onDisappear(perform: bleManager.haltTracking)
        .navigationBarHidden(true)
        .ignoresSafeArea(.keyboard)
        .onChange(of: selectedState) { _ in
            HapticGenerator.shared.generateImpact()
        }
    }
    
    @ViewBuilder
    var signalTrackingView: some View {
        VStack {
            Spacer()
            ZStack {
                CustomLottieAnimationView(lottieFile: "aritagTracker")
                    .frame(width: UIScreen.main.bounds.width - 70,
                           height: UIScreen.main.bounds.width - 70)
                VStack(spacing: 0) {
                    Text(bleManager.proximity)
                        .font(.extraBold(size: 40))
                        .frame(alignment: .center)
                        .foregroundStyle(.white)
                        .animation(.default, value: bleManager.signalStrengthPercentage)
                    Text("\(bleManager.estimatedDistance) away")
                        .font(.semiBold(size: 18))
                        .frame(alignment: .center)
                        .foregroundStyle(.white)
                        .animation(.default, value: "\(bleManager.estimatedDistance) away")
                }
            }
            .frame(width: UIScreen.main.bounds.width - 40)
            Spacer()
        }
    }
    
}

