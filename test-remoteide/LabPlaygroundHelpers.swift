//
//  LabPlaygroundHelpers.swift
//  test-remoteide
//

import SwiftUI

enum PreviewLayoutResolver {
    /// Matches the live preview’s vertical vs horizontal layout rule in `LiquidGlassPlaygroundView`.
    static func shouldUseVerticalLayout(
        _ choice: PreviewLayoutChoice,
        width: CGFloat,
        height: CGFloat
    ) -> Bool {
        switch choice {
        case .adaptive:
            width < height * 0.92
        case .horizontal:
            false
        case .vertical:
            true
        }
    }
}

enum LabSnapshotNaming {
    static func defaultUntitledName(savedSnapshotCount: Int) -> String {
        "Snapshot \(savedSnapshotCount + 1)"
    }

    /// Picks a name that is not in `existingNames`, using the same rules as the playground’s Duplicate action.
    static func nextDuplicateName(baseName: String, existingNames: Set<String>) -> String {
        let first = "\(baseName) Copy"
        if !existingNames.contains(first) {
            return first
        }
        var suffix = 2
        while true {
            let candidate = "\(baseName) Copy \(suffix)"
            if !existingNames.contains(candidate) {
                return candidate
            }
            suffix += 1
        }
    }
}
