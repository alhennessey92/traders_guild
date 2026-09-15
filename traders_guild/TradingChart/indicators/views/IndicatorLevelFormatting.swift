import Foundation

enum IndicatorLevelFormatting {
    /// A level label such as "70" for an optional config's Double.
    ///
    /// `String(format: "%.0f", config?.level ?? 70)` reads as typed, but it is
    /// not: in the `CVarArg` position Swift may resolve the `??` by lifting the
    /// optional chain to `CVarArg?` and defaulting the literal to `Int`, so when
    /// the chain is nil Foundation is handed an `Int` for `%.0f`. iOS 26 logs
    /// that as a format mismatch and renders "0" — seen on the device as two
    /// `String(format:locale:arguments:)` warnings per RSI panel pass while a
    /// marker's indicators were being swapped in. A plain `Double?` variable
    /// resolves the other way, which is why a desk test of `d ?? 70` passes.
    /// Binding a `Double` first removes the ambiguity in every case.
    static func wholeNumber(_ level: Double?, fallback: Double) -> String {
        let value: Double = level ?? fallback
        return String(format: "%.0f", value)
    }
}
