//
//  ExtensionInterface.swift
//  AirTag Tracker
//
//  Created by DANIEL KVIRKVELIA on 4.01.25.
//

import SwiftUI
import Defaults
import Combine
import Dependiject

struct ShearingBottomSheet: UIViewControllerRepresentable {
    
    var items: [Any]
    
    @Binding var url: URLToShare?
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.completionWithItemsHandler = { _, _, _, _ in
            url = nil
        }
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct AppMainButton: View {
    
    let title: String
    var subtitle: String?
    var withPulsation: Bool = false
    var icon: Image?
    let action: () -> ()
    
    @State var pulsatingAnimation: Bool = false
    @State var timer: AnyCancellable?
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Spacer()
                    if let icon {
                        icon
                            .resizable()
                            .scaledToFit()
                            .frame(height: 20)
                    }
                    Text(title)
                        .foregroundStyle(.white)
                        .font(.semiBold(size: 16))
                        .minimumScaleFactor(0.85)
                    Spacer()
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.medium(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .frame(height: 66)
        .background(.hex495DF6, in: .rect(cornerRadius: 16))
        .scaleEffect(pulsatingAnimation ? 0.95 : 1)
        .animation(.linear(duration: 0.8), value: pulsatingAnimation)
        .onAppear {
            if withPulsation {
                pulsatingAnimation.toggle()
                timer = Timer.publish(every: 0.8, on: .main, in: .common)
                    .autoconnect()
                    .sink { _ in
                        pulsatingAnimation.toggle()
                    }
            }
        }
    }
}

struct FirstLayerView: View {
    var body: some View {
        ZStack {
            Color.hexE9E9E9
        }
        .ignoresSafeArea()
    }
}

enum DeviceItemType {
    case favorite
    case found
}

struct DeviceRow: View {
    
    var device: UserDeviceInformation
    var type: DeviceItemType
    var showWhen: Bool = false
    var distance: String?
    let action: () -> ()
    let secondaryAction: () -> ()
    
    @State var isDragging = false
    @State var offsetX: CGFloat = 0
    @State var startOffsetX: CGFloat = 0
    @GestureState var dragGestureActive: Bool = false
    var targetOffset: CGFloat = -120
    
    @ViewBuilder
    var underlyingView: some View {
        ZStack(alignment: .trailing) {
            if Defaults[.favorites].contains(where: { $0.id == device.id }) {
                Color.hex495DF6
                HStack(spacing: 5) {
                    Image(.sldkjfsjdf)
                    Text("Remove")
                        .font(.semiBold(size: 15))
                        .foregroundStyle(.white)
                }
                .frame(width: -targetOffset, alignment: .center)
            } else {
                Color.hex495DF6
                HStack(spacing: 5) {
                    Image(.ertuiertu)
                    Text("Save")
                        .font(.semiBold(size: 15))
                        .foregroundStyle(.white)
                }
                .frame(width: -targetOffset, alignment: .center)
                
            }
        }
    }
    
    var body: some View {
        ZStack(alignment: .trailing) {
            underlyingView
                .clipShape(.rect(cornerRadius: 18))
                .padding(.horizontal, 16)
                .onTapGesture {
                    withAnimation(.linear(duration: 0.15)) {
                        offsetX = .zero
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            secondaryAction()
                        }
                    }
                }
            HStack {
                Image(.triureuitfs)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 50)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Text(device.name)
                            .font(.semiBold(size: 15))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .truncationMode(.tail)
                            .foregroundStyle(.black)
                    }
                    if showWhen {
                        Text(device.updated.formattedRelativeString())
                            .font(.regular(size: 14))
                            .foregroundStyle(device.updated.formattedRelativeString() == "Online" ? .green : .hex000000O40)
                    }
                }
                Spacer()
                distanceView
                Image(.wehrewdsv)
            }
            .padding(16)
            .background(.white, in: .rect(cornerRadius: 18))
            .padding(.horizontal, 16)
            .onTapGesture(perform: action)
            .offset(x: offsetX)
            .simultaneousGesture(
                DragGesture()
                    .updating($dragGestureActive) { _, state, _ in
                        state = true
                    }
                    .onChanged { gesture in
                        isDragging = true
                        let totalTranslation = gesture.translation.width + startOffsetX
                        
                        if totalTranslation <= 0 && totalTranslation >= targetOffset {
                            offsetX = totalTranslation
                        } else if totalTranslation < targetOffset {
                            offsetX = targetOffset + (totalTranslation - targetOffset) / 3
                        } else {
                            withAnimation(.linear(duration: 0.15)) {
                                offsetX = .zero
                            }
                        }
                    }
                    .onEnded { gesture in
                        endDrag()
                    }
            )
            .onChange(of: dragGestureActive) { active in
                if !active {
                    endDrag()
                }
            }
        }
        .drawingGroup()
    }
    
    var distanceView: some View {
        HStack {
            Image(.dsjkfsdfjk)
            Text(distanceTitle)
                .font(.semiBold(size: 12))
                .foregroundStyle(.hex495DF6)
                .padding(.vertical, 6)
                .padding(.horizontal, 3)
        }
    }
    
    var distanceTitle: String {
        if let distance {
            return distance
        }
        return Double(device.distance).formattedDistance()
    }
    
    
    func endDrag() {
        isDragging = false
        withAnimation(.linear(duration: 0.15)) {
            if offsetX <= targetOffset {
                offsetX = targetOffset
            } else {
                offsetX = .zero
            }
            startOffsetX = offsetX
        }
    }
}

struct DeviceAnnotationView: View {
    
    let name: String
    let when: String
    var distance: Double?
    
    var body: some View {
        VStack(spacing: 2) {
            VStack(spacing: 4) {
                HStack(spacing: 2) {
                    Image(.triureuitfs)
                }
                .padding(.horizontal, 10)
                
                Text(name)
                    .font(.semiBold(size: 13))
                    .foregroundStyle(.black)
                    .scaledToFit()
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity)
                
                Text(when)
                    .font(.regular(size: 13))
                    .padding(.horizontal, 8)
                    .foregroundStyle(when == "Online" ? .green : .black.opacity(0.5))
                
                if let distance = distance?.formattedDistanceDecimal() {
                    HStack(spacing: 3) {
                        Image(.dsjkfsdfjk)
                        Text(distance)
                            .font(.semiBold(size: 13))
                            .foregroundStyle(.hex495DF6)
                    }
                    .padding(.bottom, 6)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .foregroundStyle(Color.white)
                    .overlay(
                        Image(.urweiuew)
                            .padding(.top, 26)
                    )
            }
            .shadow(color: Color.black.opacity(0), radius: 4, x: 0, y: 4)
            .zIndex(4)
            
            Image(.sjdkfsdjf)
                .resizable()
                .scaledToFit()
                .frame(height: 36)
                .padding(.top, -6)
                .zIndex(3)
        }
        .offset(y: -20)
    }
}

struct InfoView: View {
    
    @Store var application = Factory.shared.resolve(AppUserProtocol.self)
    @Environment(\.openURL) var openURL
    let restore: () -> ()
    
    var body: some View {
        HStack {
            Button {
                HapticGenerator.shared.generateImpact()
                restore()
            } label: {
                Text("Restore")
                    .underline()
            }
            Spacer()
            Button {
                HapticGenerator.shared.generateImpact()
                guard let url = URL(string: "http://project11522847.tilda.ws/terms-of-use") else { return }
                openURL(url)
            } label: {
                Text("Terms")
                    .underline()
            }
            Spacer()
            Button {
                HapticGenerator.shared.generateImpact()
                guard let url = URL(string: "http://project11522847.tilda.ws/privacy-policy") else { return }
                openURL(url)
            } label: {
                Text("Privacy")
                    .underline()
            }
        }
        .font(.regular(size: 13))
        .foregroundStyle(.black.opacity(0.3))
        .frame(height: 18)
        .padding(.top, 0)
        .padding(.horizontal, 70)
        .background(Color.white)
    }
}

struct CustomCurvedShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Start at the top-left corner
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        
        // Draw a straight line to the top-right corner
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        
        // Draw a straight line down to the bottom-right corner
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 20))
        
        // Draw the curve from the bottom-right to bottom-left
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - 20),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        
        // Draw a straight line up to the top-left corner
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        
        return path
    }
}
