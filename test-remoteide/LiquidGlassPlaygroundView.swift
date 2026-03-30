//
//  LiquidGlassPlaygroundView.swift
//  test-remoteide
//

import SwiftUI

struct LiquidGlassPlaygroundView: View {
    @Bindable var state: LiquidGlassLabState
    @Namespace private var unionNamespace

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
                LabBackgroundView(kind: state.labBackground)
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

                ZStack {
                    GlassEffectContainer(spacing: spacing) {
                        HStack(spacing: m * 0.03) {
                            glassSample(
                                label: "Primary",
                                systemImage: "sparkles",
                                glass: glass,
                                minSide: m,
                                unionTag: "a"
                            )
                            glassSample(
                                label: "Secondary",
                                systemImage: "wand.and.stars",
                                glass: glass,
                                minSide: m,
                                unionTag: "b"
                            )
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
            Text(label)
                .font(.caption.weight(.semibold))
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

            Picker("Appearance", selection: $state.appearanceChoice) {
                Text("System").tag(AppearanceChoice.system)
                Text("Light").tag(AppearanceChoice.light)
                Text("Dark").tag(AppearanceChoice.dark)
            }
            .pickerStyle(.segmented)
        }
        .padding(minSide * 0.04)
        .background {
            RoundedRectangle(cornerRadius: minSide * 0.04, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }
}

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
