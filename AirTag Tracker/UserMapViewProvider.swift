//
//  MapView.swift
//  AirTag Tracker
//
//  Created by DANIEL KVIRKVELIA on 4.01.25.
//

import SwiftUI
import Dependiject
import MapKit
import Defaults

struct UserMapViewProvider: View, Equatable {
    
    static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs.device == rhs.device &&
        lhs.deviceCoordinates?.latitude == rhs.deviceCoordinates?.latitude &&
        lhs.deviceCoordinates?.longitude == rhs.deviceCoordinates?.longitude
    }
    
    @Store var locationService = Factory.shared.resolve(LocationUserDataProtocol.self)
    @State private var mapRegion: MKCoordinateRegion
    
    @State private var isRegionLoaded = false
    var deviceCoordinates: CLLocationCoordinate2D?
    let distanceToDevice: CLLocationDistance?
    var device: UserDeviceInformation
    
    var deviceLandmarks: [Landmark] {
        guard let coordinates = device.coordinates else { return [] }
        return [Landmark(id: device.id,
                         name: device.name,
                         when: device.updated.formattedRelativeString(),
                         coordinates: CLLocationCoordinate2D(latitude: coordinates.latitude, longitude: coordinates.longitude))]
    }
    
    init(device: UserDeviceInformation, distanceToDevice: CLLocationDistance?) {
        self.device = device
        self.distanceToDevice = distanceToDevice
        
        if let coordinates = device.coordinates {
            self.deviceCoordinates = CLLocationCoordinate2D(latitude: coordinates.latitude, longitude: coordinates.longitude)
        }
        
        let locService = Factory.shared.resolve(LocationUserDataProtocol.self)
        self._mapRegion = State(initialValue: locService.createMapRegion(from: locService.currentPos?.coordinate, to: deviceCoordinates, with: 20))
    }
    
    var body: some View {
        VStack {
            Map(coordinateRegion: $mapRegion, showsUserLocation: true, annotationItems: deviceLandmarks) { landmark in
                MapAnnotation(coordinate: landmark.coordinates) {
                    DeviceAnnotationView(name: landmark.name,
                                         when: landmark.when,
                                         distance: distanceToDevice)
                    .offset(y: -22)
                }
            }
        }
        .onAppear(perform: updateRegion)
    }
    
    private func updateRegion() {
        Task {
            if let currentLocation = locationService.currentPos {
                updateMapRegion(to: currentLocation.coordinate)
            } else {
                let currentLocation = await locationService.fetchPosition()
                updateMapRegion(to: currentLocation.coordinate)
            }
            isRegionLoaded = true
        }
    }
    
    private func updateMapRegion(to userLocation: CLLocationCoordinate2D) {
        withAnimation {
            mapRegion = locationService.createMapRegion(from: userLocation, to: deviceCoordinates, with: 20)
        }
    }
}
