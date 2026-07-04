import SwiftUI

struct LineGraphView: View {
    let values: [Double]
    let colors: [Color]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                graphGrid

                AreaGraphShape(values: values)
                    .fill(
                        LinearGradient(
                            colors: [colors.last ?? .accentColor, .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(0.22)

                LineGraphShape(values: values)
                    .stroke(
                        LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }

    private var graphGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { index in
                Rectangle()
                    .fill(index == 3 ? .clear : .primary.opacity(0.06))
                    .frame(height: index == 3 ? 0 : 1)
                if index < 3 {
                    Spacer()
                }
            }
        }
    }
}

struct LineGraphShape: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let normalizedValues = values.map(\.clampedUnit)

        guard let first = normalizedValues.first else { return path }

        if normalizedValues.count == 1 {
            let y = rect.maxY - rect.height * first
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
            return path
        }

        let step = rect.width / CGFloat(normalizedValues.count - 1)

        for index in normalizedValues.indices {
            let x = rect.minX + CGFloat(index) * step
            let y = rect.maxY - rect.height * normalizedValues[index]
            let point = CGPoint(x: x, y: y)

            if index == normalizedValues.startIndex {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        return path
    }
}

struct AreaGraphShape: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        var path = LineGraphShape(values: values).path(in: rect)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
