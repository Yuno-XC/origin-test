//
//  LiquidGlassPlaygroundView.swift
//  test-remoteide
//

import SwiftUI
import Foundation

struct LiquidGlassPlaygroundView: View {
    @Bindable var state: LiquidGlassLabState
    @Namespace private var unionNamespace
    @State private var selectedPreset: LabPreset = .frosted
    @State private var snapshotName: String = ""
    @State private var selectedCustomSnapshotID: UUID?

    var body: some View {
        NavigationStack {
            GeometryReader { outerGeo in
                let minOuter = min(outerGeo.size.width, outerGeo.size.height)
                ScrollView {
                    VStack(alignment: .leading, spacing: minOuter * 0.03) {
                        previewSection(minSide: minOuter)
                        controlsSection(minSide: minOuter)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, minOuter * 0.04)
                    .padding(.vertical, minOuter * 0.03)
                }
                .scrollIndicators(.hidden)
            }
            .background {
                LabBackgroundView(
                    kind: state.labBackground,
                    animationSpeed: state.backgroundAnimationSpeed,
                    paused: state.backgroundPaused
                )
            }
            .navigationTitle("Liquid Glass Lab")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(state.appearanceChoice.colorScheme)
        }
    }

    @ViewBuilder
    private func previewSection(minSide: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: minSide * 0.02) {
            Text("Live preview")
                .font(.headline)
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let m = min(w, h)
                let glass = state.resolvedGlass()
                let spacing = state.containerSpacing(forMinSide: m)
                let previewItems = sampleItems.prefix(max(state.sampleCount, 2))
                let shouldUseVerticalLayout: Bool = switch state.previewLayoutChoice {
                case .adaptive: w < h * 0.92
                case .horizontal: false
                case .vertical: true
                }

                ZStack(alignment: .topLeading) {
                    GlassEffectContainer(spacing: spacing) {
                        Group {
                            if shouldUseVerticalLayout {
                                VStack(spacing: m * 0.03) {
                                    ForEach(Array(previewItems), id: \.id) { item in
                                        glassSample(
                                            label: item.label,
                                            systemImage: item.systemImage,
                                            glass: glass,
                                            minSide: m,
                                            unionTag: item.id
                                        )
                                    }
                                }
                            } else {
                                HStack(spacing: m * 0.03) {
                                    ForEach(Array(previewItems), id: \.id) { item in
                                        glassSample(
                                            label: item.label,
                                            systemImage: item.systemImage,
                                            glass: glass,
                                            minSide: m,
                                            unionTag: item.id
                                        )
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    if state.unionDemoEnabled {
                        Text("Union demo adds `glassEffectUnion` on Secondary")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(m * 0.03)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            .allowsHitTesting(false)
                    }

                    if state.showDebugOverlay {
                        debugOverlayCard(minSide: m)
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: w, height: h)
            }
            .aspectRatio(1.15, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: minSide * 0.05, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: minSide * 0.05, style: .continuous)
                    .strokeBorder(.white.opacity(0.25), lineWidth: 1)
            }
        }
    }

    private func debugOverlayCard(minSide: CGFloat) -> some View {
        let spacing = minSide * 0.025
        let cardRadius = minSide * 0.035

        return VStack(alignment: .leading, spacing: minSide * 0.012) {
            HStack(alignment: .firstTextBaseline, spacing: minSide * 0.02) {
                Text("Debug overlay")
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 0)
                Text("Live")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Divider().opacity(0.25)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: minSide * 0.012) {
                    debugLine(minSide: minSide, "Base", state.baseKind.title)
                    debugLine(minSide: minSide, "Shape", state.shapeKind.title)
                    debugLine(minSide: minSide, "Transition", state.transitionKind.title)
                    debugLine(minSide: minSide, "Samples", "\(state.sampleCount)")
                    debugLine(minSide: minSide, "Layout", state.previewLayoutChoice.title)
                    debugLine(minSide: minSide, "BG", state.labBackground.title)
                    debugLine(minSide: minSide, "BG speed", String(format: "%.2f", state.backgroundAnimationSpeed))
                    debugLine(minSide: minSide, "BG paused", state.backgroundPaused ? "Yes" : "No")
                    debugLine(minSide: minSide, "Interactive", state.interactiveOn ? "On" : "Off")

                    if state.useCustomContainerSpacing {
                        debugLine(minSide: minSide, "Container spacing", String(format: "%.3f", state.containerSpacingFraction))
                    } else {
                        debugLine(minSide: minSide, "Container spacing", "Default")
                    }

                    if state.useTint {
                        debugLine(minSide: minSide, "Tint", "On")
                    } else {
                        debugLine(minSide: minSide, "Tint", "Off")
                    }

                    debugLine(minSide: minSide, "Labels", state.showLabels ? "On" : "Off")
                    debugLine(minSide: minSide, "Effect IDs", state.showEffectIDs ? "On" : "Off")
                    debugLine(minSide: minSide, "Union demo", state.unionDemoEnabled ? "On" : "Off")
                }
            }
            .frame(maxHeight: minSide * 0.38)
        }
        .padding(spacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.25), lineWidth: minSide * 0.002)
        }
    }

    private func debugLine(minSide: CGFloat, _ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: minSide * 0.02) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    @ViewBuilder
    private func glassSample(
        label: String,
        systemImage: String,
        glass: Glass,
        minSide: CGFloat,
        unionTag: String
    ) -> some View {
        let content = VStack(spacing: minSide * 0.02) {
            Image(systemName: systemImage)
                .font(.system(size: minSide * 0.12, weight: .semibold))
            if state.showLabels {
                Text(label)
                    .font(.caption.weight(.semibold))
            }
            if state.showEffectIDs {
                Text("id: \(unionTag)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, minSide * 0.06)
        .padding(.vertical, minSide * 0.05)
        .frame(maxWidth: .infinity)

        switch state.shapeKind {
        case .default:
            content
                .glassEffect(glass, in: DefaultGlassEffectShape())
                .glassEffectID(unionTag, in: unionNamespace)
                .modifier(UnionModifier(enabled: state.unionDemoEnabled && unionTag == "b", id: "pair", ns: unionNamespace))
                .glassEffectTransition(state.transitionKind.transition)
        case .capsule:
            content
                .glassEffect(glass, in: Capsule())
                .glassEffectID(unionTag, in: unionNamespace)
                .modifier(UnionModifier(enabled: state.unionDemoEnabled && unionTag == "b", id: "pair", ns: unionNamespace))
                .glassEffectTransition(state.transitionKind.transition)
        case .circle:
            content
                .glassEffect(glass, in: Circle())
                .glassEffectID(unionTag, in: unionNamespace)
                .modifier(UnionModifier(enabled: state.unionDemoEnabled && unionTag == "b", id: "pair", ns: unionNamespace))
                .glassEffectTransition(state.transitionKind.transition)
        case .roundedRectangle:
            let r = minSide * state.cornerRadiusFraction
            content
                .glassEffect(glass, in: RoundedRectangle(cornerRadius: r, style: .continuous))
                .glassEffectID(unionTag, in: unionNamespace)
                .modifier(UnionModifier(enabled: state.unionDemoEnabled && unionTag == "b", id: "pair", ns: unionNamespace))
                .glassEffectTransition(state.transitionKind.transition)
        }
    }

    @ViewBuilder
    private func controlsSection(minSide: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: minSide * 0.03) {
            Text("Glass parameters")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Quick actions")
                .font(.headline)
                .foregroundStyle(.secondary)

            Picker("Preset", selection: $selectedPreset) {
                ForEach(LabPreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: minSide * 0.02) {
                Button("Apply preset") {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        state.applyPreset(selectedPreset)
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Randomize") {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        state.randomize()
                    }
                }
                .buttonStyle(.bordered)

                Button("Reset") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        state.reset()
                    }
                }
                .buttonStyle(.bordered)
            }

            Divider().opacity(0.35)

            Text("Snapshots")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: minSide * 0.02) {
                TextField("Name", text: $snapshotName)
                    .textFieldStyle(.roundedBorder)

                Button("Save snapshot") {
                    let trimmed = snapshotName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let name = trimmed.isEmpty ? "Snapshot \(state.customSnapshots.count + 1)" : trimmed
                    withAnimation(.easeInOut(duration: 0.25)) {
                        let snap = state.makeSnapshot()
                        let named = NamedLabSnapshot(name: name, snapshot: snap)
                        state.customSnapshots.append(named)
                        selectedCustomSnapshotID = named.id
                        snapshotName = ""
                    }
                }
                .buttonStyle(.borderedProminent)

                if state.customSnapshots.isEmpty {
                    Text("No snapshots saved yet.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.top, minSide * 0.01)
                } else {
                    Picker("Custom preset", selection: $selectedCustomSnapshotID) {
                        ForEach(state.customSnapshots) { preset in
                            Text(preset.name).tag(preset.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)

                    VStack(spacing: minSide * 0.02) {
                        Button("Apply") {
                            guard let id = selectedCustomSnapshotID,
                                  let preset = state.customSnapshots.first(where: { $0.id == id }) else { return }
                            withAnimation(.easeInOut(duration: 0.35)) {
                                state.applySnapshot(preset.snapshot)
                            }
                        }
                        .buttonStyle(.bordered)

                        Button("Duplicate") {
                            guard let id = selectedCustomSnapshotID,
                                  let preset = state.customSnapshots.first(where: { $0.id == id }) else { return }

                            withAnimation(.easeInOut(duration: 0.25)) {
                                // Ensure the duplicated snapshot name stays unique.
                                let existingNames = Set(state.customSnapshots.map(\.name))
                                let baseName = preset.name
                                var candidate = "\(baseName) Copy"
                                var suffix = 2
                                while existingNames.contains(candidate) {
                                    candidate = "\(baseName) Copy \(suffix)"
                                    suffix += 1
                                }

                                let named = NamedLabSnapshot(name: candidate, snapshot: preset.snapshot)
                                state.customSnapshots.append(named)
                                selectedCustomSnapshotID = named.id
                            }
                        }
                        .buttonStyle(.bordered)

                        Button("Delete") {
                            guard let id = selectedCustomSnapshotID else { return }
                            withAnimation(.easeInOut(duration: 0.25)) {
                                state.customSnapshots.removeAll { $0.id == id }
                                selectedCustomSnapshotID = nil
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(.vertical, minSide * 0.01)

            Text("Preview")
                .font(.headline)
                .foregroundStyle(.secondary)

            Picker("Layout", selection: $state.previewLayoutChoice) {
                ForEach(PreviewLayoutChoice.allCases) { choice in
                    Text(choice.title).tag(choice)
                }
            }
            .pickerStyle(.segmented)

            LabeledContent("Sample count", value: "\(state.sampleCount)")
            Stepper("Sample count", value: $state.sampleCount, in: 2...4)

            Toggle("Show labels", isOn: $state.showLabels)
            Toggle("Show effect IDs", isOn: $state.showEffectIDs)

            Divider().opacity(0.35)

            Picker("Base glass", selection: $state.baseKind) {
                ForEach(GlassBaseKind.allCases) { k in
                    Text(k.title).tag(k)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Tint", isOn: $state.useTint)
            if state.useTint {
                ColorPicker("Tint color", selection: $state.tintColor, supportsOpacity: true)
            }

            Toggle("Interactive (`.interactive`)", isOn: $state.interactiveOn)

            Picker("Shape", selection: $state.shapeKind) {
                ForEach(GlassShapeKind.allCases) { s in
                    Text(s.title).tag(s)
                }
            }

            if state.shapeKind == .roundedRectangle {
                VStack(alignment: .leading) {
                    Text("Corner radius (relative to preview size)")
                        .font(.subheadline)
                    Slider(value: $state.cornerRadiusFraction, in: 0.05...0.45, step: 0.01)
                }
            }

            Divider().opacity(0.35)

            Text("GlassEffectContainer")
                .font(.headline)
                .foregroundStyle(.secondary)

            Toggle("Custom spacing", isOn: $state.useCustomContainerSpacing)
            if state.useCustomContainerSpacing {
                VStack(alignment: .leading) {
                    Text("Spacing (relative to preview size)")
                        .font(.subheadline)
                    Slider(value: $state.containerSpacingFraction, in: 0...0.2, step: 0.005)
                }
            }

            Divider().opacity(0.35)

            Text("GlassEffectTransition")
                .font(.headline)
                .foregroundStyle(.secondary)

            Picker("Transition", selection: $state.transitionKind) {
                ForEach(GlassTransitionKind.allCases) { t in
                    Text(t.title).tag(t)
                }
            }
            .pickerStyle(.menu)

            Divider().opacity(0.35)

            Text("Union & IDs")
                .font(.headline)
                .foregroundStyle(.secondary)

            Toggle("Apply `glassEffectUnion` on Secondary", isOn: $state.unionDemoEnabled)

            Divider().opacity(0.35)

            Text("Scene")
                .font(.headline)
                .foregroundStyle(.secondary)

            Picker("Background", selection: $state.labBackground) {
                ForEach(LabBackgroundKind.allCases) { b in
                    Text(b.title).tag(b)
                }
            }
            .pickerStyle(.menu)

            Divider().opacity(0.35)

            Text("Background motion")
                .font(.headline)
                .foregroundStyle(.secondary)

            Toggle("Pause background", isOn: $state.backgroundPaused)

            VStack(alignment: .leading, spacing: minSide * 0.01) {
                Text("Motion speed")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Slider(value: $state.backgroundAnimationSpeed, in: 0...2.2, step: 0.05)
            }

            Button("Reset motion") {
                withAnimation(.easeInOut(duration: 0.25)) {
                    state.resetBackgroundMotion()
                }
            }
            .buttonStyle(.bordered)

            Picker("Appearance", selection: $state.appearanceChoice) {
                Text("System").tag(AppearanceChoice.system)
                Text("Light").tag(AppearanceChoice.light)
                Text("Dark").tag(AppearanceChoice.dark)
            }
            .pickerStyle(.segmented)

            Divider().opacity(0.35)

            Text("Debug")
                .font(.headline)
                .foregroundStyle(.secondary)

            Toggle("Show debug overlay", isOn: $state.showDebugOverlay)
        }
        .padding(minSide * 0.04)
        .background {
            RoundedRectangle(cornerRadius: minSide * 0.04, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }
}

private struct PreviewItem: Identifiable {
    let id: String
    let label: String
    let systemImage: String
}

private let sampleItems: [PreviewItem] = [
    .init(id: "a", label: "Primary", systemImage: "sparkles"),
    .init(id: "b", label: "Secondary", systemImage: "wand.and.stars"),
    .init(id: "c", label: "Accent", systemImage: "moon.stars"),
    .init(id: "d", label: "Focus", systemImage: "sun.max")
]

private struct UnionModifier: ViewModifier {
    let enabled: Bool
    let id: String
    let ns: Namespace.ID

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content.glassEffectUnion(id: id, namespace: ns)
        } else {
            content
        }
    }
}
