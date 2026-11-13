import SwiftUI

struct WiFiIcon: View {
    let isConnected: Bool

    var body: some View {
        Image(systemName: isConnected ? "wifi" : "wifi.slash")
            .font(.system(size: 26, weight: .semibold))
            .opacity(isConnected ? 1 : 0.4)
    }
}

/// Drawn like the Switch's: an outlined body with a nub, filled to the level.
struct BatteryIcon: View {
    let level: BatteryLevel

    var body: some View {
        HStack(spacing: 2) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5).stroke(lineWidth: 3)
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 2)
                        .frame(width: max(geometry.size.width * level.fraction, 2))
                }
                .padding(5)
                if level.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.background)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(width: 50, height: 26)
            RoundedRectangle(cornerRadius: 1.5).frame(width: 4, height: 10)
        }
    }
}

struct ControllerIcon: View {
    let isConnected: Bool

    var body: some View {
        Image(systemName: "gamecontroller.fill")
            .font(.system(size: 30))
            .opacity(isConnected ? 1 : 0.35)
            .overlay {
                if !isConnected {
                    Rectangle()
                        .frame(width: 3, height: 46)
                        .rotationEffect(.degrees(-45))
                        .opacity(0.6)
                }
            }
    }
}
