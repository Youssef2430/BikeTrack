import SwiftUI
import WatchKit
import RideCore

enum Palette {
    static let lime = Color(red: 0.73, green: 0.98, blue: 0.02)
    static let coral = Color(red: 1, green: 0.25, blue: 0.23)
    static let blue = Color(red: 0.34, green: 0.71, blue: 1)
    static let panel = Color(white: 0.085)
    static let muted = Color(white: 0.62)

    static func zone(_ id: Int) -> Color {
        [Color(white: 0.55), blue, Color(red: 0.25, green: 0.83, blue: 0.69), lime,
         Color(red: 1, green: 0.66, blue: 0.14), coral,
         Color(red: 0.87, green: 0.40, blue: 0.95), Color(red: 1, green: 0.57, blue: 0.75)][min(7, max(0, id))]
    }
}

/// One title baseline beside the system clock, with a back action on pushed screens.
extension View {
    func watchHeader(_ title: String, symbol: String? = nil, tint: Color = Palette.lime,
                     showsBackButton: Bool = false) -> some View {
        modifier(WatchHeader(title: title, symbol: symbol, tint: tint, showsBackButton: showsBackButton))
    }
}

private struct WatchHeader: ViewModifier {
    let title: String
    let symbol: String?
    let tint: Color
    let showsBackButton: Bool
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(showsBackButton)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Group {
                        if showsBackButton {
                            Button { dismiss() } label: { titleLabel }
                                .buttonStyle(.plain)
                                .accessibilityLabel(title)
                                .accessibilityHint("Go back")
                        } else {
                            titleLabel.accessibilityAddTraits(.isHeader)
                        }
                    }
                    .accessibilityIdentifier("screenHeader")
                    // watchOS retains toolbar content unless its identity changes.
                    .id(title)
                }
            }
    }

    private var titleLabel: some View {
        HStack(spacing: 5) {
            if let icon = showsBackButton ? "chevron.left" : symbol {
                Image(systemName: icon).resizable().scaledToFit().frame(width: 12, height: 12)
            }
            Text(title).lineLimit(1).minimumScaleFactor(0.8)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(tint)
        .frame(height: 30)
        // Leave room for a five-character clock, including on the 40 mm Watch.
        .frame(maxWidth: WKInterfaceDevice.current().screenBounds.width * 0.56, alignment: .leading)
        .contentShape(Rectangle())
        // Leading controls sit below the clock by default; align the title text.
        .offset(y: -10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}

/// A small vector alphabet keeps the instrument display crisp at every Watch size.
/// VoiceOver reads the value once; accessibility text sizes use native typography.
struct InstrumentNumber: View {
    let value: String
    var height: CGFloat = 36
    var color: Color = .white
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private static let glyphs: [Character: [String]] = [
        "0": ["01110", "11011", "11011", "11011", "11011", "11011", "01110"],
        "1": ["00110", "01110", "00110", "00110", "00110", "00110", "01111"],
        "2": ["01110", "11011", "00011", "00110", "01100", "11000", "11111"],
        "3": ["11110", "00011", "00011", "01110", "00011", "00011", "11110"],
        "4": ["00011", "00111", "01111", "11011", "11111", "00011", "00011"],
        "5": ["11111", "11000", "11000", "11110", "00011", "00011", "11110"],
        "6": ["01110", "11000", "11000", "11110", "11011", "11011", "01110"],
        "7": ["11111", "00011", "00110", "00110", "01100", "01100", "01100"],
        "8": ["01110", "11011", "11011", "01110", "11011", "11011", "01110"],
        "9": ["01110", "11011", "11011", "01111", "00011", "00011", "01110"],
        ":": ["00", "11", "11", "00", "11", "11", "00"],
        ".": ["00", "00", "00", "00", "00", "11", "11"],
        "—": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"]
    ]

    var body: some View {
        if typeSize.isAccessibilitySize {
            Text(value).font(.system(.largeTitle, design: .rounded, weight: .semibold))
                .monospacedDigit().foregroundStyle(color).minimumScaleFactor(0.5).lineLimit(1)
        } else {
            Canvas { context, size in
                let letters = value.map { Self.glyphs[$0] ?? Self.glyphs["—"]! }
                let columns = letters.reduce(0) { $0 + ($1.first?.count ?? 0) + 1 } - 1
                let pitch = min(size.height / 7, size.width / CGFloat(max(1, columns)))
                let diameter = pitch * (reduceTransparency ? 0.94 : 0.79)
                let top = (size.height - pitch * 7) / 2
                var cursor: CGFloat = 0
                for rows in letters {
                    for (y, row) in rows.enumerated() {
                        for (x, dot) in row.enumerated() where dot == "1" {
                            let rect = CGRect(x: cursor + CGFloat(x) * pitch + (pitch - diameter) / 2,
                                              y: top + CGFloat(y) * pitch + (pitch - diameter) / 2,
                                              width: diameter, height: diameter)
                            context.fill(Path(ellipseIn: rect), with: .color(color))
                        }
                    }
                    cursor += CGFloat((rows.first?.count ?? 0) + 1) * pitch
                }
            }
            .frame(height: height)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(value)
        }
    }
}

struct ActivityEmblem: View {
    let symbol: String
    var size: CGFloat = 32
    var tint: Color = Palette.lime
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.48, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.13), in: Circle())
            .accessibilityHidden(true)
    }
}

struct Eyebrow: View {
    let title: String
    var color: Color = Palette.muted
    var body: some View {
        Text(title.uppercased()).font(.system(size: 9, weight: .bold))
            .tracking(1.2).foregroundStyle(color)
    }
}

struct RideButtonStyle: ButtonStyle {
    var tint: Color = Palette.lime
    var prominent = false
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(prominent ? (isEnabled ? Color.black : Palette.muted) : tint)
            .background(prominent && isEnabled ? tint : Palette.panel, in: Capsule())
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}

/// A physical zone selector in zone order: the active zone is a lit pill with a pointer,
/// and every other zone is a pair of ticks that recede with distance. When the zone
/// changes, the pill slides right as effort rises and left as it falls.
struct ZoneRibbon: View {
    let profile: TrainingProfile
    let metric: ZoneMetric
    let selected: Int?
    var height: CGFloat = 26
    @State private var shown: Int?
    @State private var rising = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(profile: TrainingProfile, metric: ZoneMetric, selected: Int?, height: CGFloat = 26) {
        self.profile = profile
        self.metric = metric
        self.selected = selected
        self.height = height
        _shown = State(initialValue: selected)
    }

    private var zones: [TrainingZone] { profile.zones(for: metric) }

    var body: some View {
        let zone = shown.flatMap { id in zones.first { $0.id == id } }
        let label = zone?.label ?? (zones.isEmpty ? "Set up zones" : "Zone —")
        GeometryReader { geometry in
            let layout = RibbonLayout(slots: zones.isEmpty ? Array(0..<4) : zones.map(\.id), selected: zone?.id,
                                      width: geometry.size.width, height: height)
            ZStack(alignment: .topLeading) {
                ForEach(layout.ticks) { tick in
                    RoundedRectangle(cornerRadius: tick.width * 0.42, style: .continuous)
                        .fill(Color(white: tick.shade))
                        .frame(width: tick.width, height: height)
                        .offset(x: tick.x)
                        .transition(.opacity)
                }
                Capsule()
                    .fill(zone.map { Palette.zone($0.id) } ?? Color(white: 0.24))
                    .frame(width: layout.pillWidth, height: height)
                    .overlay {
                        DotMatrixText(value: label, height: height * 0.38,
                                      color: zone == nil ? Palette.muted : .black.opacity(0.8))
                            .frame(width: layout.pillWidth)
                            .id(label)
                            .transition(reduceMotion ? .opacity : .push(from: rising ? .leading : .trailing))
                    }
                    .clipShape(Capsule())
                    .overlay(alignment: .bottom) {
                        RibbonPointer()
                            .fill(Color(white: 0.8))
                            .frame(width: height * 0.43, height: height * 0.29)
                            .offset(y: height * 0.12)
                    }
                    .offset(x: layout.pillX)
            }
        }
        .frame(height: height)
        .padding(.bottom, height * 0.12)
        .onChange(of: selected) { old, new in
            rising = (new ?? -1) > (old ?? -1)
            withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.55, dampingFraction: 0.82)) {
                shown = new
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(selected.flatMap { id in zones.first { $0.id == id }?.label }
                            ?? (zones.isEmpty ? "Set up zones" : "No current zone"))
        .accessibilityIdentifier("\(metric.rawValue)Ribbon")
    }
}

/// Positions every tick and the pill in zone order. Ticks keep stable identities, so a
/// zone change animates as one sliding motion instead of a redraw.
private struct RibbonLayout {
    struct Tick: Identifiable {
        let id: String
        let x: CGFloat
        let width: CGFloat
        let shade: Double
    }

    private(set) var ticks: [Tick] = []
    private(set) var pillX: CGFloat = 0
    let pillWidth: CGFloat

    init(slots: [Int], selected: Int?, width: CGFloat, height: CGFloat) {
        pillWidth = height * 3.5
        // Nil marks the pill. Without a reading it waits in the middle of the scale.
        var entries: [String?] = slots.flatMap { $0 == selected ? [nil] : ["\($0)a", "\($0)b"] }
        if !entries.contains(nil) { entries.insert(nil, at: slots.count / 2 * 2) }
        let pill = entries.firstIndex(of: nil) ?? 0
        let count = entries.count - 1
        let pillGap = height * 0.1
        let tickGap = height * 0.08
        let pillGaps = CGFloat((pill > 0 ? 1 : 0) + (pill < count ? 1 : 0))
        let tickGaps = CGFloat(count) - pillGaps
        let tickWidth = count > 0
            ? min(height * 0.36, max(1, (width - pillWidth - pillGaps * pillGap - tickGaps * tickGap) / CGFloat(count)))
            : 0
        var x = max(0, (width - pillWidth - CGFloat(count) * tickWidth - pillGaps * pillGap - tickGaps * tickGap) / 2)
        for (index, entry) in entries.enumerated() {
            if index > 0 { x += index == pill || index - 1 == pill ? pillGap : tickGap }
            if let id = entry {
                let distance = abs(index - pill) - 1
                ticks.append(Tick(id: id, x: x, width: tickWidth, shade: max(0.045, 0.21 * pow(0.72, Double(distance)))))
                x += tickWidth
            } else {
                pillX = x
                x += pillWidth
            }
        }
    }
}

private struct RibbonPointer: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

/// A thin 5×7 dot-matrix face for short uppercase labels.
struct DotMatrixText: View {
    let value: String
    var height: CGFloat = 9
    var color: Color = .black

    private static let glyphs: [Character: [String]] = [
        "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
        "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
        "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
        "3": ["11111", "00010", "00100", "00010", "00001", "10001", "01110"],
        "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
        "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
        "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
        "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
        "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
        "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
        "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
        "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
        "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
        "N": ["10001", "10001", "11001", "10101", "10011", "10001", "10001"],
        "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
        "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
        "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
        "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
        "U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
        "W": ["10001", "10001", "10001", "10101", "10101", "10101", "01010"],
        "Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
        "—": ["0000", "0000", "0000", "1111", "0000", "0000", "0000"],
        " ": ["00", "00", "00", "00", "00", "00", "00"]
    ]

    var body: some View {
        let letters = value.uppercased().map { Self.glyphs[$0] ?? Self.glyphs[" "]! }
        let columns = letters.reduce(0) { $0 + ($1.first?.count ?? 0) + 1 } - 1
        let pitch = height / 7
        Canvas { context, size in
            let dot = pitch * 0.92
            let left = (size.width - pitch * CGFloat(columns)) / 2
            var cursor: CGFloat = 0
            for rows in letters {
                for (y, row) in rows.enumerated() {
                    for (x, bit) in row.enumerated() where bit == "1" {
                        let rect = CGRect(x: left + cursor + CGFloat(x) * pitch, y: CGFloat(y) * pitch, width: dot, height: dot)
                        context.fill(Path(roundedRect: rect, cornerRadius: dot * 0.2), with: .color(color))
                    }
                }
                cursor += CGFloat((rows.first?.count ?? 0) + 1) * pitch
            }
        }
        .frame(width: pitch * CGFloat(columns), height: height)
        .accessibilityLabel(value)
    }
}

/// A horseshoe range dial. The end caps hold the recorded low and high, each soft bubble
/// is time spent at that heart rate, and the outlined window points at the reading.
struct HeartRateDial: View {
    let timeline: MetricTimeline
    let value: Double?
    var caption = "LIVE"
    var duration: TimeInterval?

    private var low: Double? { timeline.points.map(\.value).min() }
    private var high: Double? { timeline.points.map(\.value).max() }

    var body: some View {
        let minimum = low
        let maximum = high
        let bubbles = Self.bubbles(timeline.points.map(\.value), low: minimum, high: maximum)
        let marker = position(minimum: minimum, maximum: maximum)
        GeometryReader { geometry in
            let dial = DialGeometry(size: geometry.size)
            let r = dial.radius
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in draw(in: &context, dial: dial, bubbles: bubbles, marker: marker) }
                capLabel(minimum, at: dial.point(0), radius: r)
                capLabel(maximum, at: dial.point(1), radius: r)
                Text(formatted(value))
                    .font(.system(size: r * 0.405, weight: .semibold, design: .rounded))
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                    .frame(width: r * 1.05)
                    .position(x: dial.center.x, y: dial.center.y - r * 0.242)
                HStack(spacing: r * 0.045) {
                    if value != nil { Text(caption) }
                    Image(systemName: "heart.fill")
                    Text("BPM")
                }
                .font(.system(size: r * 0.138, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.coral)
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(width: r * 1.05)
                .position(x: dial.center.x, y: dial.center.y + r * 0.087)
                if let duration {
                    Text(Self.minutes(duration))
                        .font(.system(size: r * 0.15, weight: .medium, design: .rounded))
                        .monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                        .frame(width: r * 0.9)
                        .position(x: dial.center.x, y: dial.center.y + r * 0.335)
                }
            }
        }
        .aspectRatio(DialGeometry.aspect, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(caption == "AVG" ? "Average" : caption == "PAUSED" ? "Paused" : "Current") heart rate")
        .accessibilityValue("\(formatted(value)) beats per minute. Recorded low \(formatted(minimum)), high \(formatted(maximum)).")
        .accessibilityIdentifier("heartRateDial")
    }

    private func draw(in context: inout GraphicsContext, dial: DialGeometry, bubbles: [Bubble], marker: CGFloat?) {
        let r = dial.radius
        let track = dial.arc(from: 0, to: 1).strokedPath(StrokeStyle(lineWidth: dial.thickness, lineCap: .round))
        context.fill(track, with: .color(Color(white: 0.11)))
        func fill(_ bubbles: [Bubble], in context: GraphicsContext, opacity: Double) {
            for bubble in bubbles {
                let center = dial.point(bubble.t, offset: bubble.radial * r)
                let size = bubble.diameter * r
                context.fill(Path(ellipseIn: CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)),
                             with: .color(Palette.coral.opacity(opacity)))
            }
        }
        var trackLayer = context
        trackLayer.clip(to: track)
        fill(bubbles, in: trackLayer, opacity: 0.19)

        if let marker {
            let span: CGFloat = 0.3235
            let start = min(max(marker - span / 2, DialGeometry.inset), 1 - DialGeometry.inset - span)
            let width = dial.thickness * 0.74
            let window = dial.arc(from: start, to: start + span).strokedPath(StrokeStyle(lineWidth: width, lineCap: .round))
            var windowLayer = context
            windowLayer.clip(to: window)
            fill(bubbles, in: windowLayer, opacity: 0.28)
            let line = max(1.5, r * 0.018)
            context.stroke(window, with: .color(.white), lineWidth: line)

            let inner = dial.centerline - width / 2
            let angle = dial.angle(marker).radians
            let tangent = CGPoint(x: -sin(angle), y: cos(angle))
            let base = dial.point(marker, radius: inner + line / 2)
            let half = r * 0.052
            var notch = Path()
            notch.move(to: dial.point(marker, radius: inner - r * 0.068))
            notch.addLine(to: CGPoint(x: base.x + tangent.x * half, y: base.y + tangent.y * half))
            notch.addLine(to: CGPoint(x: base.x - tangent.x * half, y: base.y - tangent.y * half))
            notch.closeSubpath()
            context.fill(notch, with: .color(.white))
            context.stroke(notch, with: .color(.white), style: StrokeStyle(lineWidth: r * 0.02, lineJoin: .round))
        }

        for end in [CGFloat(0), 1] {
            let center = dial.point(end)
            let size = r * 0.357
            context.fill(Path(ellipseIn: CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)),
                         with: .color(Color(white: 0.175)))
        }
    }

    private func capLabel(_ value: Double?, at point: CGPoint, radius r: CGFloat) -> some View {
        Text(formatted(value))
            .font(.system(size: r * 0.15, weight: .medium, design: .rounded))
            .monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            .foregroundStyle(Color(red: 0.6, green: 0.63, blue: 0.66))
            .frame(width: r * 0.32)
            .position(point)
    }

    private func position(minimum: Double?, maximum: Double?) -> CGFloat? {
        guard let value, let minimum, let maximum else { return nil }
        return Self.track(value, low: minimum, high: maximum)
    }

    /// Readings use the middle of the arc so bubbles and the pointer clear the end caps.
    private static func track(_ value: Double, low: Double, high: Double) -> CGFloat {
        let fraction = high > low ? min(1, max(0, (value - low) / (high - low))) : 0.5
        return DialGeometry.inset + (1 - 2 * DialGeometry.inset) * CGFloat(fraction)
    }

    private struct Bubble { let t: CGFloat; let radial: CGFloat; let diameter: CGFloat }

    /// Time is binned along the arc; busier bins get more and larger bubbles. The
    /// scatter is seeded by bin, so bubbles hold still while the workout records.
    private static func bubbles(_ values: [Double], low: Double?, high: Double?) -> [Bubble] {
        guard let low, let high, !values.isEmpty else { return [] }
        let bins = 16
        var counts = Array(repeating: 0, count: bins)
        for value in values {
            let t = (track(value, low: low, high: high) - DialGeometry.inset) / (1 - 2 * DialGeometry.inset)
            counts[min(bins - 1, Int(t * CGFloat(bins)))] += 1
        }
        let busiest = CGFloat(counts.max() ?? 1)
        func noise(_ seed: Int) -> CGFloat {
            let x = sin(Double(seed) * 12.9898) * 43758.5453
            return CGFloat(x - x.rounded(.down))
        }
        return counts.indices.flatMap { index -> [Bubble] in
            guard counts[index] > 0 else { return [] }
            let weight = CGFloat(counts[index]) / busiest
            return (0...Int(weight * 2.4)).map { n in
                let seed = index * 31 + n * 7
                let slot = (CGFloat(index) + 0.5 + 0.9 * (noise(seed) - 0.5)) / CGFloat(bins)
                return Bubble(t: DialGeometry.inset + (1 - 2 * DialGeometry.inset) * slot,
                              radial: 0.16 * (noise(seed + 1) - 0.5),
                              diameter: 0.15 + 0.09 * weight + 0.05 * noise(seed + 2))
            }
        }
    }

    static func minutes(_ seconds: TimeInterval) -> String {
        let minutes = Int(max(0, seconds) / 60)
        func plural(_ count: Int, _ unit: String) -> String { "\(count) \(unit)\(count == 1 ? "" : "s")" }
        if minutes == 0 { return "<1 min" }
        guard minutes >= 60 else { return plural(minutes, "min") }
        return "\(plural(minutes / 60, "hr")) \(plural(minutes % 60, "min"))"
    }
}

/// A 272° horseshoe measured from the reference: t runs from the upper-left cap,
/// down around the bottom, to the upper-right cap.
private struct DialGeometry {
    static let aspect: CGFloat = 2 / 1.777
    static let inset: CGFloat = 0.1
    let center: CGPoint
    let radius: CGFloat
    var centerline: CGFloat { radius * 0.787 }
    var thickness: CGFloat { radius * 0.422 }

    init(size: CGSize) {
        radius = min(size.width / 2, size.height / 1.777)
        center = CGPoint(x: size.width / 2, y: (size.height - radius * 1.777) / 2 + radius * 0.777)
    }

    func angle(_ t: CGFloat) -> Angle { .degrees(226 - 272 * Double(t)) }

    func point(_ t: CGFloat, radius: CGFloat? = nil, offset: CGFloat = 0) -> CGPoint {
        let angle = angle(t).radians
        let distance = (radius ?? centerline) + offset
        return CGPoint(x: center.x + distance * cos(angle), y: center.y + distance * sin(angle))
    }

    func arc(from start: CGFloat, to end: CGFloat) -> Path {
        Path { path in
            path.addArc(center: center, radius: centerline, startAngle: angle(end), endAngle: angle(start), clockwise: false)
        }
    }
}
