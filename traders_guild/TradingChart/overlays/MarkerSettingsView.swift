import SwiftUI

/// Settings view for configuring marker display preferences
/// Add this to your app's settings screen
struct MarkerSettingsView: View {
    @ObservedObject private var settings = MarkerDisplaySettings.shared
    
    var body: some View {
        Form {
//            Section {
//                VStack(alignment: .leading, spacing: 8) {
//                    HStack {
//                        Text("Distance from Candles")
//                        Spacer()
//                        Text("\(Int(settings.baseOffset))px")
//                            .foregroundColor(.secondary)
//                    }
//                    Slider(value: $settings.baseOffset, in: 40...150, step: 5)
//                    Text("How far markers appear from candle highs/lows")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                }
//            } header: {
//                Text("Marker Position")
//            }
//            
//            Section {
//                VStack(alignment: .leading, spacing: 8) {
//                    HStack {
//                        Text("Stack Spacing")
//                        Spacer()
//                        Text("\(Int(settings.stackOffset))px")
//                            .foregroundColor(.secondary)
//                    }
//                    Slider(value: $settings.stackOffset, in: 25...60, step: 2)
//                    Text("Spacing between stacked markers on the same candle")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                }
//                
//                VStack(alignment: .leading, spacing: 8) {
//                    HStack {
//                        Text("Tier Offset")
//                        Spacer()
//                        Text("\(Int(settings.proximityTierOffset))px")
//                            .foregroundColor(.secondary)
//                    }
//                    Slider(value: $settings.proximityTierOffset, in: 15...50, step: 5)
//                    Text("Extra spacing to prevent overlap with adjacent candle markers")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                }
//            } header: {
//                Text("Overlap Prevention")
//            }
//            
//            Section {
//                Stepper("Cluster after \(settings.maxBeforeCluster) markers", value: Binding(
//                    get: { settings.maxBeforeCluster },
//                    set: { settings.maxBeforeCluster = $0 }
//                ), in: 2...6)
//                Text("Number of markers on one candle before showing as cluster")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//            } header: {
//                Text("Clustering")
//            }
//            
//            Section {
//                Button("Reset to Defaults") {
//                    withAnimation {
//                        settings.resetToDefaults()
//                    }
//                }
//                .foregroundColor(.red)
//            }
        }
        .navigationTitle("Marker Display")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        MarkerSettingsView()
    }
}

