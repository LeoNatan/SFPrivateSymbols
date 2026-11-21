//
//  AnimationInspectorView.swift
//  SFPrivateSymbols
//
//  Mirrors SF Symbols' animation inspector: effect + repeat rows, per-effect options, Reset and copy.
//

import SwiftUI
import Observation

/// Effects in the order of SF Symbols' animation menu.
enum SymbolAnimation: String, CaseIterable, Identifiable {
	case appear, drawOn, bounce, scale, wiggle, rotate, breathe, pulse, variableColor, replace, drawOff, disappear

	var id: Self { self }

	var title: String {
		switch self {
		case .appear: "Appear"
		case .drawOn: "Draw On"
		case .bounce: "Bounce"
		case .scale: "Scale"
		case .wiggle: "Wiggle"
		case .rotate: "Rotate"
		case .breathe: "Breathe"
		case .pulse: "Pulse"
		case .variableColor: "Variable Color"
		case .replace: "Replace"
		case .drawOff: "Draw Off"
		case .disappear: "Disappear"
		}
	}

	/// Effects that change state (shown/hidden, scaled) rather than playing and returning.
	var isStateEffect: Bool {
		switch self {
		case .appear, .disappear, .scale, .drawOn, .drawOff: true
		default: false
		}
	}

	/// Effects whose resting state is "engaged" (the symbol is visible once they have played).
	var restsActive: Bool {
		self == .appear || self == .drawOn
	}

	static let leading: [SymbolAnimation] = [.appear, .drawOn]
	static let middle: [SymbolAnimation] = [.bounce, .scale, .wiggle, .rotate, .breathe, .pulse, .variableColor, .replace]
	static let trailing: [SymbolAnimation] = [.drawOff, .disappear]
}

enum AnimationRepeat: String, CaseIterable, Identifiable {
	case once, repeatWithDelay, continuously

	var id: Self { self }

	var title: String {
		switch self {
		case .once: "Once"
		case .repeatWithDelay: "Repeat with Delay"
		case .continuously: "Continuously"
		}
	}
}

enum AnimationGrouping: String, CaseIterable, Identifiable {
	case wholeSymbol, byLayer, individually

	var id: Self { self }

	var title: String {
		switch self {
		case .wholeSymbol: "Whole Symbol"
		case .byLayer: "By Layer"
		case .individually: "Individually"
		}
	}
}

enum VerticalDirection: String, CaseIterable, Identifiable {
	case down, up
	var id: Self { self }
	var title: String { rawValue.capitalized }
}

enum WiggleDirection: String, CaseIterable, Identifiable {
	case up, down, left, right, forward, backward, clockwise, counterclockwise

	var id: Self { self }

	var title: String {
		self == .counterclockwise ? "Counterclockwise" : rawValue.capitalized
	}
}

enum RotationDirection: String, CaseIterable, Identifiable {
	case clockwise, counterclockwise
	var id: Self { self }
	var title: String { self == .clockwise ? "Clockwise" : "Counterclockwise" }
}

enum ReplaceStyle: String, CaseIterable, Identifiable {
	case downUp, upUp, offUp

	var id: Self { self }

	var title: String {
		switch self {
		case .downUp: "Down Up"
		case .upUp: "Up Up"
		case .offUp: "Off Up"
		}
	}
}

enum VariableFill: String, CaseIterable, Identifiable {
	case cumulative, iterative
	var id: Self { self }
	var title: String { rawValue.capitalized }
}

enum InactiveLayers: String, CaseIterable, Identifiable {
	case dim, hide
	var id: Self { self }
	var title: String { rawValue.capitalized }
}

struct AnimationSettings: Equatable {
	var effect: SymbolAnimation = .bounce
	var repeatMode: AnimationRepeat = .once
	var grouping: AnimationGrouping = .byLayer
	var direction: VerticalDirection = .up
	var wiggleDirection: WiggleDirection = .left
	var rotation: RotationDirection = .clockwise
	var replaceStyle: ReplaceStyle = .downUp
	var fill: VariableFill = .iterative
	var inactiveLayers: InactiveLayers = .dim
	var reversing = false

	/// Keeps the effect and playback, restores every option.
	mutating func resetOptions() {
		self = AnimationSettings(effect: effect, repeatMode: repeatMode)
	}

	var isDefault: Bool {
		self == AnimationSettings(effect: effect, repeatMode: repeatMode)
	}

	var options: SymbolEffectOptions {
		switch repeatMode {
		case .once: .nonRepeating
		case .repeatWithDelay: .repeat(.periodic(delay: 1))
		case .continuously: .repeat(.continuous)
		}
	}

	var groupingSuffix: String {
		switch grouping {
		case .wholeSymbol: ".wholeSymbol"
		case .byLayer: ".byLayer"
		case .individually: ".individually"
		}
	}

	/// SwiftUI spelling of the configured effect, for “Copy Code”.
	var swiftUIEffect: String {
		switch effect {
		case .appear: ".appear.\(direction.rawValue)\(groupingSuffix)"
		case .disappear: ".disappear.\(direction.rawValue)\(groupingSuffix)"
		case .drawOn: ".drawOn\(groupingSuffix)"
		case .drawOff: ".drawOff\(groupingSuffix)"
		case .bounce: ".bounce.\(direction.rawValue)\(groupingSuffix)"
		case .scale: ".scale.\(direction.rawValue)\(groupingSuffix)"
		case .wiggle: ".wiggle.\(wiggleDirection.rawValue)\(groupingSuffix)"
		case .rotate: ".rotate.\(rotation == .clockwise ? "clockwise" : "counterClockwise")\(groupingSuffix)"
		case .breathe: ".breathe\(groupingSuffix)"
		case .pulse: ".pulse\(groupingSuffix)"
		case .variableColor: ".variableColor.\(fill.rawValue).\(inactiveLayers == .dim ? "dimInactiveLayers" : "hideInactiveLayers").\(reversing ? "reversing" : "nonReversing")"
		case .replace: ".replace.\(replaceStyle.rawValue)\(groupingSuffix)"
		}
	}

	var swiftUIOptions: String {
		switch repeatMode {
		case .once: ".nonRepeating"
		case .repeatWithDelay: ".repeat(.periodic(delay: 1))"
		case .continuously: ".repeat(.continuous)"
		}
	}

	func swiftUICode(symbol: String) -> String {
		let image = "Image(_internalSystemName: \"\(symbol)\")"
		if effect == .replace {
			return "\(image)\n\t.contentTransition(.symbolEffect(\(swiftUIEffect), options: \(swiftUIOptions)))"
		}
		if effect.isStateEffect || repeatMode != .once {
			return "\(image)\n\t.symbolEffect(\(swiftUIEffect), options: \(swiftUIOptions), isActive: isActive)"
		}
		return "\(image)\n\t.symbolEffect(\(swiftUIEffect), options: \(swiftUIOptions), value: trigger)"
	}

	func appKitCode() -> String {
		"imageView.addSymbolEffect(\(swiftUIEffect), options: \(swiftUIOptions))"
	}
}

/// Drives the preview strip: one-shot triggers, repeating activity, and state-effect sequences.
@Observable
final class AnimationPlayer {
	var trigger = 0
	/// Repeating discrete effects run while this is true.
	var running = false
	/// State effects: engaged (shown for appear/draw on, hidden/scaled for the others).
	var active = false
	var replaced = false
	private(set) var isPlaying = false
	private var task: Task<Void, Never>?

	func reset(for settings: AnimationSettings) {
		task?.cancel()
		task = nil
		isPlaying = false
		running = false
		replaced = false
		withTransaction(Transaction(animation: nil)) {
			active = settings.effect.restsActive
		}
	}

	func togglePlayback(_ settings: AnimationSettings) {
		if isPlaying {
			reset(for: settings)
			return
		}

		let effect = settings.effect
		let repeats = settings.repeatMode != .once
		let delay: Duration = settings.repeatMode == .repeatWithDelay ? .seconds(1) : .milliseconds(150)

		if !effect.isStateEffect && effect != .replace {
			if repeats {
				running = true
				isPlaying = true
			} else {
				trigger += 1
			}
			return
		}

		isPlaying = true
		task = Task { @MainActor [weak self] in
			repeat {
				guard let self else { return }
				await self.playOnce(effect)
				if !repeats || Task.isCancelled { break }
				try? await Task.sleep(for: delay)
			} while !Task.isCancelled
			self?.isPlaying = false
		}
	}

	private func playOnce(_ effect: SymbolAnimation) async {
		switch effect {
		case .replace:
			replaced.toggle()
			try? await Task.sleep(for: .milliseconds(900))
		case .appear, .drawOn:
			withTransaction(Transaction(animation: nil)) { active = false }
			try? await Task.sleep(for: .milliseconds(80))
			active = true
			try? await Task.sleep(for: .milliseconds(1200))
		default:
			active = true
			try? await Task.sleep(for: .milliseconds(1200))
			withTransaction(Transaction(animation: nil)) { active = false }
		}
	}
}

/// Applies the configured effect to a symbol view.
struct SymbolAnimationModifier: ViewModifier {
	let settings: AnimationSettings
	let player: AnimationPlayer

	func body(content: Content) -> some View {
		let byLayer = settings.grouping != .wholeSymbol
		let up = settings.direction == .up
		let options = settings.options

		switch settings.effect {
		case .appear:
			let effect = up ? AppearSymbolEffect.appear.up : .appear.down
			content.symbolEffect(byLayer ? effect.byLayer : effect.wholeSymbol, options: .nonRepeating, isActive: player.active)
		case .disappear:
			let effect = up ? DisappearSymbolEffect.disappear.up : .disappear.down
			content.symbolEffect(byLayer ? effect.byLayer : effect.wholeSymbol, options: .nonRepeating, isActive: player.active)
		case .drawOn:
			content.symbolEffect(drawOn, options: .nonRepeating, isActive: player.active)
		case .drawOff:
			content.symbolEffect(drawOff, options: .nonRepeating, isActive: player.active)
		case .scale:
			let effect = up ? ScaleSymbolEffect.scale.up : .scale.down
			content.symbolEffect(byLayer ? effect.byLayer : effect.wholeSymbol, options: .nonRepeating, isActive: player.active)
		case .bounce:
			let effect = up ? BounceSymbolEffect.bounce.up : .bounce.down
			discrete(byLayer ? effect.byLayer : effect.wholeSymbol, content, options)
		case .wiggle:
			discrete(byLayer ? wiggle.byLayer : wiggle.wholeSymbol, content, options)
		case .rotate:
			let effect = settings.rotation == .clockwise ? RotateSymbolEffect.rotate.clockwise : .rotate.counterClockwise
			discrete(byLayer ? effect.byLayer : effect.wholeSymbol, content, options)
		case .breathe:
			discrete(byLayer ? BreatheSymbolEffect.breathe.byLayer : .breathe.wholeSymbol, content, options)
		case .pulse:
			discrete(byLayer ? PulseSymbolEffect.pulse.byLayer : .pulse.wholeSymbol, content, options)
		case .variableColor:
			let filled = settings.fill == .cumulative ? VariableColorSymbolEffect.variableColor.cumulative : .variableColor.iterative
			let layered = settings.inactiveLayers == .dim ? filled.dimInactiveLayers : filled.hideInactiveLayers
			discrete(settings.reversing ? layered.reversing : layered.nonReversing, content, options)
		case .replace:
			content.contentTransition(.symbolEffect(replace, options: .nonRepeating))
		}
	}

	private var drawOn: DrawOnSymbolEffect {
		switch settings.grouping {
		case .wholeSymbol: .drawOn.wholeSymbol
		case .byLayer: .drawOn.byLayer
		case .individually: .drawOn.individually
		}
	}

	private var drawOff: DrawOffSymbolEffect {
		switch settings.grouping {
		case .wholeSymbol: .drawOff.wholeSymbol
		case .byLayer: .drawOff.byLayer
		case .individually: .drawOff.individually
		}
	}

	private var wiggle: WiggleSymbolEffect {
		switch settings.wiggleDirection {
		case .up: .wiggle.up
		case .down: .wiggle.down
		case .left: .wiggle.left
		case .right: .wiggle.right
		case .forward: .wiggle.forward
		case .backward: .wiggle.backward
		case .clockwise: .wiggle.clockwise
		case .counterclockwise: .wiggle.counterClockwise
		}
	}

	private var replace: ReplaceSymbolEffect {
		let base: ReplaceSymbolEffect = switch settings.replaceStyle {
		case .downUp: .replace.downUp
		case .upUp: .replace.upUp
		case .offUp: .replace.offUp
		}
		return settings.grouping == .wholeSymbol ? base.wholeSymbol : base.byLayer
	}

	@ViewBuilder
	private func discrete<Effect>(_ effect: Effect, _ content: Content, _ options: SymbolEffectOptions) -> some View
	where Effect: DiscreteSymbolEffect & IndefiniteSymbolEffect & SymbolEffect {
		if settings.repeatMode == .once {
			content.symbolEffect(effect, options: options, value: player.trigger)
		} else {
			content.symbolEffect(effect, options: options, isActive: player.running)
		}
	}
}

struct AnimationForm: View {
	let symbol: PrivateSymbol?
	@Binding var settings: AnimationSettings
	let player: AnimationPlayer

	var body: some View {
		Form {
			Section {
				LabeledContent {
					HStack {
						Picker("Animation", selection: $settings.effect) {
							ForEach(SymbolAnimation.leading) { Text($0.title).tag($0) }
							Divider()
							ForEach(SymbolAnimation.middle) { Text($0.title).tag($0) }
							Divider()
							ForEach(SymbolAnimation.trailing) { Text($0.title).tag($0) }
						}
						.labelsHidden()
						.fixedSize()

						Button {
							player.togglePlayback(settings)
						} label: {
							Image(systemName: player.isPlaying ? "stop.fill" : "play.fill")
								.frame(width: 34, height: 14)
						}
						.help(player.isPlaying ? "Stop" : "Preview")
					}
				} label: {
					Label {
						Text("Animation")
					} icon: {
						InspectorTab.animationIcon
					}
				}

				Picker(selection: $settings.repeatMode) {
					ForEach(AnimationRepeat.allCases) { Text($0.title).tag($0) }
				} label: {
					Label("Repeat", systemImage: "repeat")
				}
			}

			Section {
				options
			} footer: {
				HStack(spacing: 10) {
					Spacer()
					Button("Reset") {
						settings.resetOptions()
						player.reset(for: settings)
					}
					.disabled(settings.isDefault)

					Menu {
						Button("Copy SwiftUI Code") {
							SymbolExport.copyString(settings.swiftUICode(symbol: symbol?.name ?? ""))
						}
						Button("Copy AppKit Code") {
							SymbolExport.copyString(settings.appKitCode())
						}
						Button("Copy UIKit Code") {
							SymbolExport.copyString(settings.appKitCode())
						}
					} label: {
						Image(systemName: "doc.on.doc")
					} primaryAction: {
						SymbolExport.copyString(settings.swiftUICode(symbol: symbol?.name ?? ""))
					}
					.fixedSize()
					.disabled(symbol == nil)
					.help("Copy Code")
				}
			}
		}
		.formStyle(.grouped)
	}

	@ViewBuilder
	private var options: some View {
		switch settings.effect {
		case .appear, .disappear, .bounce, .scale:
			grouping([.wholeSymbol, .byLayer])
			radio("Direction", selection: $settings.direction, VerticalDirection.allCases, title: \.title)
		case .drawOn, .drawOff:
			grouping([.wholeSymbol, .byLayer, .individually])
		case .wiggle:
			grouping([.wholeSymbol, .byLayer])
			Picker("Direction", selection: $settings.wiggleDirection) {
				ForEach(WiggleDirection.allCases) { Text($0.title).tag($0) }
			}
		case .rotate:
			grouping([.wholeSymbol, .byLayer])
			radio("Direction", selection: $settings.rotation, RotationDirection.allCases, title: \.title)
		case .breathe, .pulse:
			grouping([.wholeSymbol, .byLayer])
		case .variableColor:
			radio("Fill", selection: $settings.fill, VariableFill.allCases, title: \.title)
			radio("Inactive Layers", selection: $settings.inactiveLayers, InactiveLayers.allCases, title: \.title)
			Toggle("Reverse", isOn: $settings.reversing)
		case .replace:
			radio("Style", selection: $settings.replaceStyle, ReplaceStyle.allCases, title: \.title)
			grouping([.wholeSymbol, .byLayer])
		}
	}

	private func grouping(_ cases: [AnimationGrouping]) -> some View {
		radio("Animate", selection: $settings.grouping, cases, title: \.title)
	}

	private func radio<Value: Hashable & Identifiable>(_ title: String, selection: Binding<Value>, _ cases: [Value], title caseTitle: KeyPath<Value, String>) -> some View {
		LabeledContent(title) {
			Picker(title, selection: selection) {
				ForEach(cases) { Text($0[keyPath: caseTitle]).tag($0) }
			}
			.pickerStyle(.radioGroup)
			.horizontalRadioGroupLayout()
			.labelsHidden()
			.fixedSize()
		}
	}
}
