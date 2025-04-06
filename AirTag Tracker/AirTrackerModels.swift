//
//  AirTrackerModels.swift
//  AirTag Tracker
//
//  Created by DANIEL KVIRKVELIA on 4.01.25.
//

import SwiftUI
import Adapty
import CoreLocation
import Defaults

enum PaywallCoordinationData {
    case second
    case first
    
    var key: String {
        switch self {
        case .first:
            return "premium_access"
        case .second:
            return "premium_access"
        }
    }
}

struct UserGuidePaywallModel {
    var configuration: RemoteUserConfigModel
    var product: AdaptyPaywallProduct
}

struct UIPaywallModel: Identifiable {
    var config: RemoteUserConfigModel
    var weekSubscription: AdaptyPaywallProduct
    var monthSubscription: AdaptyPaywallProduct
    var yearSubscription: AdaptyPaywallProduct
    let id: UUID = UUID()
}

struct RemoteUserConfigModel: Decodable {
    var checked: String?
    var fullPricingTitle: String?
    var color: String
    var indicate: Bool
    var needToLoad: Bool
    
    var review: Bool
}

enum UserGuideSteps: Int, CaseIterable, Identifiable {
    case welcome = 0
    case location
    case organize
    case paywall
    
    var id: Int {
        rawValue
    }
    
    var title: String {
        switch self {
        case .paywall: return "Unlimited Access to Bluetooth Finder"
        case .welcome: return "Find Missing Bluetooth Devices"
        case .location: return "Map Your Device's Location Instantly"
        case .organize: return "Signal Strength of Your Device"
        }
    }
    
    var description: String {
        switch self {
        case .paywall: return "Get started with tracking lost devices for free for 3 days, then for only $6.99 per week."
        case .welcome: return "Effortlessly scan your surroundings to detect Bluetooth devices nearby in just a few seconds."
        case .location: return "Quickly pinpoint your device's exact location on a map with real-time tracking."
        case .organize: return "Quickly measure your proximity to the device to locate it easily."
        }
    }
    
    var backgroundImage: Image {
        switch self {
        case .welcome: return Image(
            .hsdjfsdhjfshjdf1
        )
        case .location: return Image(
            .hsdjfsdhjfshjdf2
        )
        case .organize: return Image(
            .hsdjfsdhjfshjdf3
        )
        case .paywall: return Image(
            .hsdjfsdhjfshjdf4
        )
        }
    }
}

struct UserDeviceInformation: Identifiable, Hashable, Equatable, _Defaults.Serializable, Codable {
    var id: UUID
    var name: String
    var updated: Date = .now
    var added: Date = .now
    let distance: Int
    var coordinates: LocationCoordinateService?
    var unknownDeviceNumber: Int?
    
    static func == (
        lhs: Self,
        rhs: Self
    ) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.coordinates == rhs.coordinates
    }
}

struct LocationCoordinateService: Codable, Hashable, Equatable {
    let longitude: Double
    let latitude: Double
    
    init(
        longitude: Double,
        latitude: Double
    ) {
        self.longitude = longitude
        self.latitude = latitude
    }
    
    init(
        from decoder: any Decoder
    ) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        self.longitude = try container
            .decode(
                Double.self,
                forKey: .longitude
            )
        self.latitude = try container
            .decode(
                Double.self,
                forKey: .latitude
            )
    }
    
    init?(
        location: CLLocation?
    ) {
        guard let location else {
            return nil
        }
        longitude = location.coordinate.longitude
        latitude = location.coordinate.latitude
    }
    
    init(
        location: CLLocation
    ) {
        longitude = location.coordinate.longitude
        latitude = location.coordinate.latitude
    }
}

extension Collection where Element == UserDeviceInformation {
    var takenNumbers: Set<Int> {
        Set(
            self.compactMap {
                $0.unknownDeviceNumber
            })
    }
}

enum UserScreenDestinations: Hashable, CaseIterable {
    case search
    case saved
    case settings
    
    var title: String {
        switch self {
        case .search: return "Search Devices"
        case .saved: return "Saved Devices"
        case .settings: return "Settings"
        }
    }
}

struct Landmark: Identifiable {
    let id: UUID
    let name: String
    let when: String
    let coordinates: CLLocationCoordinate2D
}

struct PurchasesInfo: Codable {
    let isActive: Bool
    let expirationDate: Date
}

struct URLToShare: Identifiable {
    let id: UUID = UUID()
    let url: URL
}

extension Defaults.Keys {
    static let welcomeFlowEnded = Key<Bool>(
        "welcomeFlowEnded",
        default: false
    )
    static let measurement = Key<MeasurementType>(
        "unit",
        default: .automatic
    )
    static let favorites = Key<[UserDeviceInformation]>(
        "favorites",
        default: []
    )
    static let history = Key<[UserDeviceInformation]>(
        "history",
        default: []
    )
}

extension Date {
    func formattedRelativeString() -> String {
        let now = Date.now
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(
            identifier: "en_US"
        )
        
        let components = calendar.dateComponents(
            [
                .year,
                .month,
                .day,
                .hour,
                .minute,
                .second
            ],
            from: self,
            to: now
        )
        
        if calendar
            .isDateInToday(
                self
            ) {
            if let seconds = components.second, seconds < 60 {
                return seconds < 30 ? "Online" : "\(seconds) seconds ago"
            }
            if let minutes = components.minute, minutes < 60 {
                return "\(minutes) min ago"
            }
            formatter.dateFormat = "h:mm a"
            return "Today at \(formatter.string(from: self))"
        }
        
        if calendar
            .isDateInYesterday(
                self
            ) {
            formatter.dateFormat = "h:mm a"
            return "Yesterday at \(formatter.string(from: self))"
        }
        
        formatter.dateFormat = "MMMM d"
        let dayAndMonth = formatter.string(
            from: self
        )
        
        if components.year == 0 {
            formatter.dateFormat = "h:mm a"
            return "\(dayAndMonth) at \(formatter.string(from: self))"
        }
        
        formatter.dateFormat = "MMMM d yyyy"
        let dayMonthAndYear = formatter.string(
            from: self
        )
        formatter.dateFormat = "h:mm a"
        return "\(dayMonthAndYear) at \(formatter.string(from: self))"
    }
}

extension Color {
    init(
        hex: String
    ) {
        let hex = hex.trimmingCharacters(
            in: CharacterSet.alphanumerics.inverted
        )
        var int: UInt64 = 0
        Scanner(
            string: hex
        )
        .scanHexInt64(
            &int
        )
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (
                a,
                r,
                g,
                b
            ) = (
                255,
                (
                    int >> 8
                ) * 17,
                (
                    int >> 4 & 0xF
                ) * 17,
                (
                    int & 0xF
                ) * 17
            )
        case 6:
            (
                a,
                r,
                g,
                b
            ) = (
                255,
                int >> 16,
                int >> 8 & 0xFF,
                int & 0xFF
            )
        case 8:
            (
                a,
                r,
                g,
                b
            ) = (
                int >> 24,
                int >> 16 & 0xFF,
                int >> 8 & 0xFF,
                int & 0xFF
            )
        default:
            (
                a,
                r,
                g,
                b
            ) = (
                1,
                1,
                1,
                0
            )
        }
        
        self.init(
            .sRGB,
            red: Double(
                r
            ) / 255,
            green: Double(
                g
            ) / 255,
            blue:  Double(
                b
            ) / 255,
            opacity: Double(
                a
            ) / 255
        )
    }
}

extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }
    
    public func gestureRecognizerShouldBegin(
        _ gestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return viewControllers.count > 1 && interactivePopGestureRecognizer != nil
    }
}

extension Double {
    func formattedDistance() -> String {
        formattedDistance(
            for: Defaults[.measurement],
            decimal: false
        )
    }
    
    func formattedDistanceDecimal() -> String {
        formattedDistance(
            for: Defaults[.measurement],
            decimal: true
        )
    }
    
    private func formattedDistance(
        for type: MeasurementType,
        decimal: Bool
    ) -> String {
        guard self >= 0 else {
            return "Invalid distance"
        }
        if self < 1 {
            return "With you"
        }
        switch type {
        case .metric:
            return self >= 1000
            ? String(
                format: "%.1f km",
                self / 1000
            )
            : String(
                format: decimal ? "%.1f m" : "%.0f m",
                self
            )
        case .imperial:
            let distanceInFeet = self * 3.28084
            return distanceInFeet >= 5280
            ? String(
                format: "%.1f miles",
                distanceInFeet / 5280
            )
            : String(
                format: decimal ? "%.1f ft" : "%.0f ft",
                distanceInFeet
            )
        case .automatic:
            let system: MeasurementType = Locale.current.usesMetricSystem ? .metric : .imperial
            return formattedDistance(
                for: system,
                decimal: decimal
            )
        }
    }
}

extension Optional where Wrapped == Double {
    func formattedDistance() -> String? {
        guard let self else {
            return nil
        }
        return self.formattedDistance()
    }
}
