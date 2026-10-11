// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import SwiftUI

enum GeometryCommand: Sendable {
    case freeTransform
    case distort
    case applyTransform
    case cancelTransform
    case flipHorizontal
    case flipVertical
    case flipCanvasHorizontal
    case flipCanvasVertical
    case rotateClockwise
    case rotateCounterclockwise
    case rotate180
    case imageSize
    case canvasSize
    case trim
    case toggleRulers
    case toggleGuides
    case toggleGrid
    case toggleSnap
    case gridSettings
    case clearGuides
    case addHorizontalGuide
    case addVerticalGuide
    case hand
    case zoom
}

struct CanvasSizeSheet: View {
    let originalWidth: Int
    let originalHeight: Int
    var onApply: (Int, Int, Int) -> Void
    var onCancel: () -> Void

    @State private var width: Int
    @State private var height: Int
    @State private var lockAspect = false
    @State private var anchor = 4
    @State private var showsError = false

    init(width: Int, height: Int, onApply: @escaping (Int, Int, Int) -> Void, onCancel: @escaping () -> Void) {
        originalWidth = width
        originalHeight = height
        self.onApply = onApply
        self.onCancel = onCancel
        _width = State(initialValue: width)
        _height = State(initialValue: height)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            Text(L10n.Geometry.canvasSize)
                .font(.title2)
            TextField(L10n.Canvas.width, value: $width, format: .number)
                .onChange(of: width) { _, newValue in
                    guard lockAspect, originalWidth > 0 else { return }
                    height = max(1, Int((Double(newValue) * Double(originalHeight) / Double(originalWidth)).rounded()))
                }
            TextField(L10n.Canvas.height, value: $height, format: .number)
            Toggle(L10n.Geometry.lockAspect, isOn: $lockAspect)
            Text(L10n.Geometry.anchor)
            anchorGrid
            if showsError {
                Text(L10n.Canvas.invalidSize)
                    .foregroundStyle(Color(nsColor: .systemRed))
            }
            confirmRow(apply: L10n.Geometry.apply) {
                guard (DocumentModel.minimumSide...DocumentModel.maximumSide).contains(width),
                      (DocumentModel.minimumSide...DocumentModel.maximumSide).contains(height) else {
                    showsError = true
                    return
                }
                onApply(width, height, anchor)
            }
        }
        .padding(Theme.spacing * 1.5)
        .frame(minWidth: 360)
    }

    private var anchorGrid: some View {
        let titles = [
            L10n.Anchor.topLeft, L10n.Anchor.top, L10n.Anchor.topRight,
            L10n.Anchor.left, L10n.Anchor.center, L10n.Anchor.right,
            L10n.Anchor.bottomLeft, L10n.Anchor.bottom, L10n.Anchor.bottomRight,
        ]
        return VStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { column in
                        let index = row * 3 + column
                        Button(titles[index]) { anchor = index }
                            .buttonStyle(.bordered)
                            .tint(anchor == index ? Color.accentColor : nil)
                    }
                }
            }
        }
    }

    private func confirmRow(apply: String, action: @escaping () -> Void) -> some View {
        HStack {
            Spacer()
            Button(L10n.Action.cancel, action: onCancel)
                .keyboardShortcut(.cancelAction)
            Button(apply, action: action)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        }
    }
}

struct ImageSizeSheet: View {
    let originalWidth: Int
    let originalHeight: Int
    let resolution: Double
    var onApply: (Int, Int, Double, LayerSampling) -> Void
    var onCancel: () -> Void

    @State private var width: Int
    @State private var height: Int
    @State private var resolutionPPI: Double
    @State private var sampling: LayerSampling = .high
    @State private var lockAspect = true
    @State private var showsError = false

    init(width: Int, height: Int, resolution: Double, onApply: @escaping (Int, Int, Double, LayerSampling) -> Void, onCancel: @escaping () -> Void) {
        originalWidth = width
        originalHeight = height
        self.resolution = resolution
        self.onApply = onApply
        self.onCancel = onCancel
        _width = State(initialValue: width)
        _height = State(initialValue: height)
        _resolutionPPI = State(initialValue: resolution)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            Text(L10n.Geometry.imageSize)
                .font(.title2)
            TextField(L10n.Canvas.width, value: $width, format: .number)
                .onChange(of: width) { _, newValue in
                    guard lockAspect, originalWidth > 0 else { return }
                    height = max(1, Int((Double(newValue) * Double(originalHeight) / Double(originalWidth)).rounded()))
                }
            TextField(L10n.Canvas.height, value: $height, format: .number)
            TextField(L10n.Canvas.resolution, value: $resolutionPPI, format: .number)
            Toggle(L10n.Geometry.lockAspect, isOn: $lockAspect)
            Picker(L10n.Geometry.resample, selection: $sampling) {
                ForEach(LayerSampling.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            if showsError {
                Text(L10n.Canvas.invalidSize)
                    .foregroundStyle(Color(nsColor: .systemRed))
            }
            HStack {
                Spacer()
                Button(L10n.Action.cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(L10n.Geometry.apply) {
                    guard (DocumentModel.minimumSide...DocumentModel.maximumSide).contains(width),
                          (DocumentModel.minimumSide...DocumentModel.maximumSide).contains(height),
                          resolutionPPI >= 1, resolutionPPI <= 2400 else {
                        showsError = true
                        return
                    }
                    onApply(width, height, resolutionPPI, sampling)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(Theme.spacing * 1.5)
        .frame(minWidth: 360)
    }
}

struct TrimSheet: View {
    @State private var options = TrimOptions()
    var onApply: (TrimOptions) -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            Text(L10n.Trim.title)
                .font(.title2)
            Picker(L10n.Trim.basedOn, selection: $options.basedOn) {
                ForEach(TrimBasedOn.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            Toggle(L10n.Trim.top, isOn: $options.top)
            Toggle(L10n.Trim.bottom, isOn: $options.bottom)
            Toggle(L10n.Trim.left, isOn: $options.left)
            Toggle(L10n.Trim.right, isOn: $options.right)
            HStack {
                Text(L10n.Trim.tolerance)
                Slider(value: tolerance, in: 0...255, step: 1)
                Text("\(options.tolerance)")
                    .monospacedDigit()
            }
            HStack {
                Spacer()
                Button(L10n.Action.cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(L10n.Geometry.apply) { onApply(options) }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!options.trimsAny)
            }
        }
        .padding(Theme.spacing * 1.5)
        .frame(minWidth: 360)
    }

    private var tolerance: Binding<Double> {
        Binding(get: { Double(options.tolerance) }, set: { options.tolerance = UInt8(min(max($0, 0), 255)) })
    }
}

struct GridSettingsSheet: View {
    @Bindable var canvas: CanvasViewModel
    var onClose: () -> Void
    @State private var spacing: Double
    @State private var subdivisions: Double

    init(canvas: CanvasViewModel, onClose: @escaping () -> Void) {
        self.canvas = canvas
        self.onClose = onClose
        _spacing = State(initialValue: Double(canvas.grid.spacing))
        _subdivisions = State(initialValue: Double(canvas.grid.subdivisions))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            Text(L10n.GridSettings.title)
                .font(.title2)
            HStack {
                Text(L10n.GridSettings.spacing)
                Slider(value: $spacing, in: 2...512, step: 1)
                Text("\(Int(spacing))")
                    .monospacedDigit()
            }
            HStack {
                Text(L10n.GridSettings.subdivisions)
                Slider(value: $subdivisions, in: 1...32, step: 1)
                Text("\(Int(subdivisions))")
                    .monospacedDigit()
            }
            HStack {
                Spacer()
                Button(L10n.Action.ok) {
                    canvas.setGrid(spacing: Int(spacing), subdivisions: Int(subdivisions))
                    onClose()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(Theme.spacing * 1.5)
        .frame(minWidth: 360)
    }
}
