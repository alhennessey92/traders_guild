import SwiftUI

enum MarkerPollStyleTokens {
    static let selectedAccent = AppColors.statusInfo95
    static let selectedBackground = AppColors.statusInfo20
    static let selectedBorder = AppColors.statusInfo52

    static let unselectedCount = AppColors.greyText
    static let unselectedBackground = AppColors.whiteText.opacity(0.08)
    static let unselectedBorder = AppColors.whiteText.opacity(0.08)

    static let progressBackground = AppColors.surfaceWhite10
    static let progressSelected = AppColors.statusInfo52
    static let progressUnselected = AppColors.surfaceWhite32
    static let progressSubmittingTint = AppColors.surfaceWhite88
}
