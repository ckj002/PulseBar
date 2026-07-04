import SwiftUI

struct MetricCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.background.opacity(0.58))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(.primary.opacity(0.08), lineWidth: 1)
                    )
            )
    }
}

struct MetricTitle: View {
    let icon: String
    let title: String

    var body: some View {
        Label {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
        } icon: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(.secondary)
    }
}

struct NetworkRateRow: View {
    let icon: String
    let label: String
    let value: String
    let unitSpacing: Double

    init(icon: String, label: String, value: String, unitSpacing: Double = 3) {
        self.icon = icon
        self.label = label
        self.value = value
        self.unitSpacing = unitSpacing
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .frame(width: 14)
                .foregroundStyle(.secondary)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            NetworkRateValueText(value: value, unitSpacing: CGFloat(unitSpacing.clamped(to: 0...8)))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
        }
    }
}

struct NetworkRateValueText: View {
    let value: String
    let unitSpacing: CGFloat

    var body: some View {
        let parts = rateParts

        HStack(spacing: unitSpacing) {
            Text(parts.number)
            if !parts.unit.isEmpty {
                Text(parts.unit)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }

    private var rateParts: (number: String, unit: String) {
        let parts = value.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else { return (value, "") }
        return (String(parts[0]), String(parts[1]))
    }
}

struct MetricValueBlock: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct UsageBarView: View {
    let value: Double
    let colors: [Color]

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.primary.opacity(0.1))

                Capsule()
                    .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(4, proxy.size.width * value.clampedUnit))
            }
        }
        .accessibilityLabel("Usage")
        .accessibilityValue(MetricFormatter.percent(value))
    }
}
