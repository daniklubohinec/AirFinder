//
//  AirTrackerServices.swift
//  AirTag Tracker
//
//  Created by DANIEL KVIRKVELIA on 4.01.25.
//

import Foundation
import Combine
import Dependiject
import Defaults
import NavigationBackport
import Adapty
import StoreKit
import CoreBluetooth
import MapKit
import CoreLocation
import KeychainAccess
import SwiftUI

protocol AppUserProtocol: AnyObservableObject {
    
    var path: NBNavigationPath {
        get set
    }
    func requestReview()
}

final class Application: AppUserProtocol, ObservableObject {
    
    @Published var path = NBNavigationPath()
    
    func requestReview() {
        if let windowScene = UIApplication.shared.connectedScenes
            .first as? UIWindowScene {
            SKStoreReviewController
                .requestReview(
                    in: windowScene
                )
        }
    }
}


protocol BluetoothUserProtocol: AnyObservableObject {
    
    var discoveredDevices: [UserDeviceInformation] {
        get set
    }
    var favoriteDevices: [UserDeviceInformation] {
        get
    }
    var otherDevices: [UserDeviceInformation] {
        get
    }
    var signalStrengthPercentage: Double {
        get set
    }
    var proximity: String {
        get
    }
    var estimatedDistance: String {
        get
    }
    var isConnected: Bool {
        get set
    }
    var isBluetoothActive: Bool {
        get set
    }
    var deviceLocated: PassthroughSubject<
        LocationCoordinateService,
        Never
    > {
        get
    }
    var triggerLocalDataUpdate: PassthroughSubject<
        Void,
        Never
    > {
        get
    }
    
    func beginScanning(
        for uuid: UUID?
    )
    func haltTracking()
    func haltScanning()
    func resetDiscoveredDevices()
    func refreshDeviceInfo(
        _ device: UserDeviceInformation
    )
}

final class BluetoothUserManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate, BluetoothUserProtocol {
    
    fileprivate var previousRSSI: Int = 0
    private var centralBLEManager: CBCentralManager!
    private var locationService: LocationUserDataProtocol
    @Published var discoveredDevices: [UserDeviceInformation] = []
    @Published var signalStrengthPercentage: Double = 0.0
    @Published var estimatedDistance: String = "--"
    @Published var isConnected: Bool = false
    @Published var isBluetoothActive = false
    private var targetDeviceUUID: UUID?
    private var initialSignalStrength: Int?
    private var initialProximity: Double?
    private var deviceCounter: Int = 1
    private var distanceResetTimer: AnyCancellable?
    private var scanningTimer: AnyCancellable?
    let deviceLocated = PassthroughSubject<
        LocationCoordinateService,
        Never
    >()
    let triggerLocalDataUpdate =  PassthroughSubject<
        Void,
        Never
    >()
    
    var proximity: String {
        "\(Int((signalStrengthPercentage * 100).rounded()))%"
    }
    
    
    var favoriteDevices: [UserDeviceInformation] {
        discoveredDevices
            .filter { device in
                Defaults[.favorites]
                    .contains(
                        where: {
                            $0.id ==  device.id
                        })
            }
            .sorted {
                $0.added < $1.added
            }
    }
    
    var otherDevices: [UserDeviceInformation] {
        discoveredDevices
            .filter { device in
                !Defaults[.favorites]
                    .contains(
                        where: {
                            $0.id ==  device.id
                        })
            }
    }
    
    init(
        locationService: LocationUserDataProtocol
    ) {
        self.locationService = locationService
        super.init()
        self.centralBLEManager = CBCentralManager(
            delegate: self,
            queue: nil
        )
    }
    
    func centralManagerDidUpdateState(
        _ central: CBCentralManager
    ) {
        isBluetoothActive = central.state == .poweredOn
    }
    
    func resetDiscoveredDevices() {
        discoveredDevices
            .removeAll()
    }
    
    func beginScanning(
        for uuid: UUID?
    ) {
        if uuid == nil {
            discoveredDevices
                .removeAll()
        }
        DispatchQueue.main
            .asyncAfter(
                deadline: .now() + (
                    uuid == nil ? 0.4 : 0
                )
            ) { [weak self] in
                guard let self = self else {
                    return
                }
                if let uuid = uuid {
                    self.targetDeviceUUID = uuid
                }
                if self.centralBLEManager.state == .poweredOn {
                    self.centralBLEManager
                        .scanForPeripherals(
                            withServices: nil,
                            options: nil
                        )
                }
            }
    }
    
    func haltScanning() {
        centralBLEManager
            .stopScan()
        resetTrackingData()
    }
    
    func haltTracking() {
        centralBLEManager
            .stopScan()
        targetDeviceUUID = nil
        resetTrackingData()
        cancelTimers()
    }
    
    private func resetTrackingData() {
        signalStrengthPercentage = 0
        initialSignalStrength = nil
        initialProximity = nil
        deviceCounter = 1
        estimatedDistance = "--"
    }
    
    private func cancelTimers() {
        distanceResetTimer?
            .cancel()
        distanceResetTimer = nil
        scanningTimer?
            .cancel()
        scanningTimer = nil
    }
    
    func refreshDeviceInfo(
        _ device: UserDeviceInformation
    ) {
        if let index = discoveredDevices.firstIndex(
            where: {
                $0.id == device.id
            }) {
            discoveredDevices[index] = device
        }
        updateDeviceInStorage(
            device
        )
        if let coordinates = device.coordinates {
            updateDeviceLocation(
                coordinates,
                uuid: device.id
            )
        }
        triggerLocalDataUpdate
            .send(
                ()
            )
    }
    
    private func updateDeviceInStorage(
        _ device: UserDeviceInformation
    ) {
        if let index = Defaults[.favorites].firstIndex(
            where: {
                device == $0
            }) {
            Defaults[.favorites][index] = device
        }
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let signalStrength = RSSI.intValue
        let calculatedDistance = calculateDistance(
            rssi: signalStrength
        )
        let uuid = peripheral.identifier
        
        if let targetUUID = targetDeviceUUID, uuid == targetUUID {
            handleTargetDeviceDiscovery(
                signalStrength,
                proximity: calculatedDistance,
                uuid: uuid
            )
        } else {
            handleGeneralDeviceDiscovery(
                peripheral,
                signalStrength: signalStrength,
                distance: calculatedDistance
            )
        }
    }
    
    private func handleTargetDeviceDiscovery(
        _ rssi: Int,
        proximity: Double,
        uuid: UUID
    ) {
        if rssi > 0 {
            restartScanningProcess()
            return
        }
        
        if initialSignalStrength == nil {
            initialSignalStrength = rssi
            initialProximity = proximity
            isConnected = true
        }
        
        signalStrengthPercentage = convertRSSIToPercentage(
            rssi: rssi
        )
        estimatedDistance = proximity
            .formattedDistanceDecimal()
        
        if signalStrengthPercentage >= 0.8, locationService.authStatus == .allowed, let currentLocation = locationService.currentPos {
            let coordinates = LocationCoordinateService(
                location: currentLocation
            )
            updateDeviceLocation(
                coordinates,
                uuid: uuid
            )
            deviceLocated
                .send(
                    coordinates
                )
        }
        
        restartScanningProcess()
    }
    
    private func handleGeneralDeviceDiscovery(
        _ discoveredDevice: CBPeripheral,
        signalStrength: Int,
        distance: Double
    ) {
        
        if discoveredDevice.name == nil && !isDeviceStored(
            discoveredDevice
        ) {
            if isDeviceNumberTaken(
                deviceCounter
            ) {
                deviceCounter = findNextAvailableDeviceNumber()
            }
        }
        
        let deviceName = generateDeviceName(
            for: discoveredDevice
        )
        var deviceInfo = UserDeviceInformation(
            id: discoveredDevice.identifier,
            name: deviceName,
            distance: Int(
                distance
            )
        )
        
        if discoveredDevice.name == nil {
            deviceInfo.unknownDeviceNumber = deviceCounter
            deviceCounter += 1
        }
        
        
        if let index = Defaults[.favorites].firstIndex(
            where: {
                discoveredDevice.identifier == $0.id
            }) {
            Defaults[.favorites][index].name = deviceName
        }
        
        
        if !discoveredDevices
            .contains(
                where: {
                    $0.id == discoveredDevice.identifier
                }) {
            discoveredDevices
                .append(
                    deviceInfo
                )
        } else if let index = discoveredDevices.firstIndex(
            where: {
                $0.id == discoveredDevice.identifier
            }) {
            discoveredDevices[index] = deviceInfo
        }
    }
    
    private func updateDeviceLocation(
        _ coordinates: LocationCoordinateService,
        uuid: UUID
    ) {
        if let index = discoveredDevices.firstIndex(
            where: {
                $0.id == uuid
            }) {
            discoveredDevices[index].coordinates = coordinates
            discoveredDevices[index].updated = Date.now
        }
        updateDeviceLocationInStorage(
            coordinates,
            uuid: uuid
        )
    }
    
    private func updateDeviceLocationInStorage(
        _ coordinates: LocationCoordinateService,
        uuid: UUID
    ) {
        if let index = Defaults[.favorites].firstIndex(
            where: {
                $0.id == uuid
            }) {
            Defaults[.favorites][index].coordinates = coordinates
            Defaults[.favorites][index].updated = Date.now
        }
    }
    
    private func isDeviceStored(
        _ peripheral: CBPeripheral
    ) -> Bool {
        Defaults[.favorites]
            .contains(
                where: {
                    $0.id == peripheral.identifier
                })
    }
    
    private func generateDeviceName(
        for peripheral: CBPeripheral
    ) -> String {
        if let storedDevice = Defaults[.favorites].first(
            where: {
                $0.id == peripheral.identifier
            }) {
            return storedDevice.name
        }
        return peripheral.name ?? "Device \(deviceCounter)"
    }
    
    private func isDeviceNumberTaken(
        _ number: Int
    ) -> Bool {
        Defaults[.favorites].takenNumbers
            .contains(
                number
            )
    }
    
    private func findNextAvailableDeviceNumber() -> Int {
        var number = deviceCounter
        while isDeviceNumberTaken(
            number
        ) {
            number += 1
        }
        return number
    }
    
    private func restartScanningProcess() {
        centralBLEManager
            .stopScan()
        distanceResetTimer?
            .cancel()
        distanceResetTimer = nil
        scanningTimer = Timer
            .publish(
                every: 0.9,
                on: .main,
                in: .common
            )
            .autoconnect()
            .sink { [weak self] _ in
                self?.centralBLEManager
                    .scanForPeripherals(
                        withServices: nil,
                        options: nil
                    )
                self?.distanceResetTimer = Timer
                    .publish(
                        every: 1.5,
                        on: .main,
                        in: .common
                    )
                    .autoconnect()
                    .sink { [weak self] _ in
                        self?.signalStrengthPercentage = 0
                        self?.estimatedDistance = "--"
                    }
            }
    }
}

// MARK: - Distance Estimation
extension BluetoothUserManager {
    
    private func calculateProximity(
        rssi: Int
    ) -> Double {
        let txPower = -59
        if rssi >= 0 {
            return 50
        }
        let ratio = Double(
            rssi
        ) / Double(
            txPower
        )
        if ratio < 1.0 {
            return pow(
                ratio,
                10
            )
        } else {
            return (
                0.89976
            ) * pow(
                ratio,
                7.7095
            ) + 0.111
        }
    }
    
    func calculateDistance(
        rssi: Int,
        pathLossExponent: Double = 3.0
    ) -> Double {
        let measuredPower = -59 // Hardcoded Measured Power value (RSSI at 1 meter)
        
        // Formula to calculate the distance
        let distance = pow(
            10.0,
            Double(
                measuredPower - rssi
            ) / (
                10 * pathLossExponent
            )
        )
        return distance
    }
    
    
    private func convertRSSIToPercentage(
        rssi: Int
    ) -> Double {
        let weakestRSSI = -100.0
        let halfMeterRSSI = -47.0
        
        guard rssi < 0 else {
            return 0
        }
        
        if abs(
            rssi - previousRSSI
        ) > 20 {
            previousRSSI += (
                rssi - previousRSSI
            ) / 3
        } else if abs(
            rssi - previousRSSI
        ) > 14 {
            previousRSSI += (
                rssi - previousRSSI
            ) / 2
        } else {
            previousRSSI = rssi
        }
        
        let percentage = (
            Double(
                previousRSSI
            ) - weakestRSSI
        ) / (
            halfMeterRSSI - weakestRSSI
        )
        return max(
            0.0,
            min(
                1.0,
                percentage
            )
        )
    }
}

enum UserAccessStatus {
    case notRequested
    case allowed
    case restricted
}

protocol LocationUserDataProtocol: AnyObservableObject {
    
    var authStatus: UserAccessStatus {
        get
    }
    var currentPos: CLLocation? {
        get set
    }
    var locationStream: PassthroughSubject<
        CLLocation,
        Never
    > {
        get
    }
    
    func requestAccess() async -> UserAccessStatus
    func fetchPosition() async -> CLLocation
    func startLocationMonitoring()
    func stopLocationMonitoring()
    func calculateDistance(
        to position: LocationCoordinateService?
    ) -> Double?
    func createMapRegion(
        from start: CLLocationCoordinate2D?,
        to end: CLLocationCoordinate2D?,
        with radius: CLLocationDistance?
    ) -> MKCoordinateRegion
}

final class LocationUserService: NSObject, ObservableObject, LocationUserDataProtocol {
    
    private let coreLocationManager = CLLocationManager()
    private var authStatusContinuation: CheckedContinuation<
        UserAccessStatus,
        Never
    >?
    private var positionContinuation: CheckedContinuation<
        CLLocation,
        Never
    >?
    let locationStream = PassthroughSubject<
        CLLocation,
        Never
    >()
    
    var authStatus: UserAccessStatus = .notRequested
    @Published var currentPos: CLLocation?
    
    private var monitoringActive: Bool = false
    private var singleLocationRequest: Bool = false
    
    override init() {
        super.init()
        self.coreLocationManager.delegate = self
        self.authStatus = translateAuthStatus(
            coreLocationManager.authorizationStatus
        )
    }
    
    func requestAccess() async -> UserAccessStatus {
        return await withCheckedContinuation { continuation in
            self.authStatusContinuation = continuation
            coreLocationManager
                .requestWhenInUseAuthorization()
        }
    }
    
    func fetchPosition() async -> CLLocation {
        return await withCheckedContinuation { continuation in
            self.positionContinuation = continuation
            fetchPositionOnce()
        }
    }
    
    func startLocationMonitoring() {
        guard authStatus == .allowed else {
            return
        }
        monitoringActive = true
        coreLocationManager.desiredAccuracy = kCLLocationAccuracyBest
        coreLocationManager
            .startUpdatingLocation()
        coreLocationManager
            .startUpdatingHeading()
    }
    
    func stopLocationMonitoring() {
        monitoringActive = false
        coreLocationManager
            .stopUpdatingLocation()
        coreLocationManager
            .stopUpdatingHeading()
    }
    
    func calculateDistance(
        to position: LocationCoordinateService?
    ) -> Double? {
        guard let currentPos, let position else {
            return nil
        }
        let targetLocation = CLLocation(
            latitude: position.latitude,
            longitude: position.longitude
        )
        return currentPos
            .distance(
                from: targetLocation
            )
    }
    
    func createMapRegion(
        from start: CLLocationCoordinate2D?,
        to end: CLLocationCoordinate2D?,
        with radius: CLLocationDistance?
    ) -> MKCoordinateRegion {
        if let startCoord = start {
            return generateMapRegion(
                from: startCoord,
                to: end,
                radius: radius
            )
        } else if let endCoord = end {
            return generateMapRegion(
                from: endCoord,
                radius: radius
            )
        } else {
            return defaultMapRegion()
        }
    }
    
    private func generateMapRegion(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D?,
        radius: CLLocationDistance?
    ) -> MKCoordinateRegion {
        if let endCoord = end {
            let centerLat = (
                start.latitude + endCoord.latitude
            ) / 2
            let centerLon = (
                start.longitude + endCoord.longitude
            ) / 2
            let spanLatDelta = abs(
                start.latitude - endCoord.latitude
            ) * 1.5
            let spanLonDelta = abs(
                start.longitude - endCoord.longitude
            ) * 1.5
            let span = MKCoordinateSpan(
                latitudeDelta: spanLatDelta,
                longitudeDelta: spanLonDelta
            )
            let center = CLLocationCoordinate2D(
                latitude: centerLat,
                longitude: centerLon
            )
            return MKCoordinateRegion(
                center: center,
                span: span
            )
        } else if let radiusValue = radius {
            return MKCoordinateRegion(
                center: start,
                latitudinalMeters: radiusValue * 2,
                longitudinalMeters: radiusValue * 2
            )
        } else {
            return MKCoordinateRegion(
                center: start,
                span: MKCoordinateSpan(
                    latitudeDelta: 1,
                    longitudeDelta: 1
                )
            )
        }
    }
    
    private func generateMapRegion(
        from start: CLLocationCoordinate2D,
        radius: CLLocationDistance?
    ) -> MKCoordinateRegion {
        if let radiusValue = radius {
            return MKCoordinateRegion(
                center: start,
                latitudinalMeters: radiusValue * 2,
                longitudinalMeters: radiusValue * 2
            )
        } else {
            return MKCoordinateRegion(
                center: start,
                span: MKCoordinateSpan(
                    latitudeDelta: 1,
                    longitudeDelta: 1
                )
            )
        }
    }
    
    private func fetchPositionOnce() {
        guard authStatus == .allowed, !monitoringActive else {
            return
        }
        singleLocationRequest = true
        coreLocationManager.desiredAccuracy = kCLLocationAccuracyBest
        coreLocationManager
            .startUpdatingLocation()
    }
    
    private func translateAuthStatus(
        _ status: CLAuthorizationStatus
    ) -> UserAccessStatus {
        switch status {
        case .notDetermined:
            return .notRequested
        case .authorizedWhenInUse, .authorizedAlways:
            return .allowed
        case .denied, .restricted:
            return .restricted
        @unknown default:
            return .restricted
        }
    }
    
    private func handleAuthStatusChange(
        _ newStatus: CLAuthorizationStatus
    ) {
        authStatus = translateAuthStatus(
            newStatus
        )
        if let continuation = authStatusContinuation {
            continuation
                .resume(
                    returning: authStatus
                )
            authStatusContinuation = nil
        }
    }
    
    private func defaultMapRegion() -> MKCoordinateRegion {
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: 37.0902,
                longitude: -95.7129
            ),
            span: MKCoordinateSpan(
                latitudeDelta: 40.0,
                longitudeDelta: 40.0
            )
        )
    }
}

extension LocationUserService: CLLocationManagerDelegate {
    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        if let location = locations.last {
            currentPos = location
            locationStream
                .send(
                    location
                )
            
            if singleLocationRequest {
                coreLocationManager
                    .stopUpdatingLocation()
                singleLocationRequest = false
            }
            
            if let continuation = positionContinuation {
                continuation
                    .resume(
                        returning: location
                    )
                positionContinuation = nil
            }
        }
    }
    
    func locationManager(
        _ manager: CLLocationManager,
        didChangeAuthorization status: CLAuthorizationStatus
    ) {
        handleAuthStatusChange(
            status
        )
    }
}

struct UserSubscriptionInfo: Codable {
    let validUntil: Date
}

protocol SecureStorageManager: AnyObservableObject {
    func storeSubscriptionExpiry(
        date: Date
    )
    func retrieveSubscriptionDetails() -> UserSubscriptionInfo?
    func removeStoredSubscription()
}

final class UserKeychainManager: ObservableObject, SecureStorageManager {
    
    private enum StorageKeys {
        static let subscriptionExpiryDate = "appSubscriptionExpiry"
    }
    
    private let keychain = Keychain(
        service: "com.daniel.airtracker.keychain"
    )
    
    func storeSubscriptionExpiry(
        date: Date
    ) {
        let subscriptionInfo = UserSubscriptionInfo(
            validUntil: date
        )
        if let encodedData = try? JSONEncoder().encode(
            subscriptionInfo
        ) {
            keychain[data: StorageKeys.subscriptionExpiryDate] = encodedData
        }
    }
    
    func retrieveSubscriptionDetails() -> UserSubscriptionInfo? {
        if let encodedData = keychain[data: StorageKeys.subscriptionExpiryDate] {
            return try? JSONDecoder()
                .decode(
                    UserSubscriptionInfo.self,
                    from: encodedData
                )
        }
        return nil
    }
    
    func removeStoredSubscription() {
        try? keychain
            .remove(
                StorageKeys.subscriptionExpiryDate
            )
    }
}

enum MeasurementType: String, CaseIterable, Identifiable, Defaults.Serializable {
    
    case automatic
    case imperial
    case metric
    
    var id: Self {
        self
    }
    
    var title: String {
        switch self {
        case .automatic:
            "Auto"
        case .imperial:
            "Feet"
        case .metric:
            "Meters"
        }
    }
}

struct MeasurementSelection: View {
    
    let selectedState: MeasurementType
    let switchAction: (
        MeasurementType
    ) -> ()
    
    func offset(
        proxy: GeometryProxy
    ) -> CGFloat {
        switch selectedState {
        case .automatic:
                .zero
        case .imperial:
            proxy.size.width / 3
        case .metric:
            proxy.size.width / 3 * 2
        }
    }
    
    var body: some View {
        GeometryReader { proxy in
            ZStack(
                alignment: .leading
            ) {
                RoundedRectangle(
                    cornerRadius: 8
                )
                .foregroundStyle(
                    .hex495DF6.opacity(
                        0.15
                    )
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 8
                    )
                    .stroke(
                        .hex495DF6,
                        lineWidth: 1.5
                    )
                )
                
                .frame(
                    width: proxy.size.width / 3,
                    alignment: .leading
                )
                
                
                
                .offset(
                    x: offset(
                        proxy: proxy
                    )
                )
                
                HStack(
                    spacing: .zero
                ) {
                    ForEach(
                        MeasurementType.allCases
                    ) { type in
                        Text(
                            type.title
                        )
                        .font(
                            selectedState == type ? .semiBold(
                                size: 13
                            ) : .regular(
                                size: 13
                            )
                        )
                        .foregroundStyle(
                            selectedState == type ? .hex495DF6 : .black
                        )
                        .frame(
                            width: proxy.size.width / 3,
                            alignment: .center
                        )
                        .contentShape(
                            .rect(
                                cornerRadius: 8
                            )
                        )
                        .onTapGesture {
                            switchAction(
                                type
                            )
                        }
                    }
                }
                
            }
            .padding(
                2
            )
            .background(
                .hex000000O5,
                in: .rect(
                    cornerRadius: 8
                )
            )
            .frame(
                maxWidth: .infinity
            )
            .frame(
                height: 44
            )
            .animation(
                .linear(
                    duration: 0.2
                ),
                value: selectedState
            )
        }
        .frame(
            height: 44
        )
    }
}

extension Font {
    public static func bold(
        size: CGFloat
    ) -> Font {
        Font
            .custom(
                "Sora-Bold",
                size: size
            )
    }
    public static func extraBold(
        size: CGFloat
    ) -> Font {
        Font
            .custom(
                "Sora-ExtraBold",
                size: size
            )
    }
    public static func extraLight(
        size: CGFloat
    ) -> Font {
        Font
            .custom(
                "Sora-ExtraLight",
                size: size
            )
    }
    public static func light(
        size: CGFloat
    ) -> Font {
        Font
            .custom(
                "Sora-Light",
                size: size
            )
    }
    public static func medium(
        size: CGFloat
    ) -> Font {
        Font
            .custom(
                "Sora-Medium",
                size: size
            )
    }
    public static func regular(
        size: CGFloat
    ) -> Font {
        Font
            .custom(
                "Sora-Regular",
                size: size
            )
    }
    public static func semiBold(
        size: CGFloat
    ) -> Font {
        Font
            .custom(
                "Sora-SemiBold",
                size: size
            )
    }
    public static func thin(
        size: CGFloat
    ) -> Font {
        Font
            .custom(
                "Sora-This",
                size: size
            )
    }
}

protocol ImpactGenerator {
    func generateImpact()
}

final class HapticGenerator: ImpactGenerator {
    static let shared = HapticGenerator()
    
    // MARK: Internal
    private init() {
        
    }
    
    func generateImpact() {
        impact
            .impactOccurred()
    }
    
    // MARK: Fileprivate
    
    fileprivate let impact = UIImpactFeedbackGenerator(
        style: .light
    )
}
