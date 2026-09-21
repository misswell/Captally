import SwiftUI

struct AmountKeyboard: View {
    enum Key: Hashable {
        case digit(String)
        case decimal
        case sum
        case difference
        case product
        case backspace
        case equals
    }

    private static let grid: [[Key]] = [
        [.digit("1"), .digit("2"), .digit("3"), .sum],
        [.digit("4"), .digit("5"), .digit("6"), .difference],
        [.digit("7"), .digit("8"), .digit("9"), .product],
        [.decimal, .digit("0"), .backspace, .equals],
    ]

    @EnvironmentObject var loc: LocalizationManager
    @Binding var text: String
    var themeColor: Color = .brand
    var isConfirmEnabled: Bool = true
    /// Receives the final amount. The expression is folded before the callback fires, so the
    /// caller never has to race a pending `@State` write.
    let onConfirm: (String) -> Void

    var body: some View {
        VStack(spacing: Metrics.s) {
            GlassGroup(spacing: Metrics.s) {
                ForEach(Self.grid, id: \.self) { row in
                    HStack(spacing: Metrics.s) {
                        ForEach(row, id: \.self) { key in
                            keyButton(key)
                        }
                    }
                }
            }

            Button(action: confirm) {
                Label(loc["quickEntry.save"], systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: Metrics.rowHeight)
            }
            .primaryAction(tint: themeColor)
            .disabled(!isConfirmEnabled)
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.bottom, Metrics.s)
        .sensoryFeedback(.impact, trigger: text)
    }

    private func keyButton(_ key: Key) -> some View {
        Button {
            press(key)
        } label: {
            keyLabel(key)
                .frame(maxWidth: .infinity, minHeight: Metrics.keyHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(keyColor(key))
        .glassKey(tint: keyTint(key))
    }

    @ViewBuilder
    private func keyLabel(_ key: Key) -> some View {
        switch key {
        case .digit(let value):
            Text(value).font(.title2.weight(.medium))
        case .decimal:
            Text(".").font(.title2.weight(.medium))
        case .sum, .difference, .product, .equals:
            Text(symbol(for: key)).font(.title3.weight(.semibold))
        case .backspace:
            Image(systemName: "delete.left").font(.callout)
        }
    }

    private func symbol(for key: Key) -> String {
        switch key {
        case .sum: return "+"
        case .difference: return "−"
        case .product: return "×"
        case .equals: return "="
        default: return ""
        }
    }

    private func keyColor(_ key: Key) -> Color {
        switch key {
        case .equals: return .brand
        case .sum, .difference, .product, .backspace: return .secondary
        default: return .primary
        }
    }

    private func keyTint(_ key: Key) -> Color? {
        switch key {
        case .equals: return .brand.opacity(0.35)
        case .sum, .difference, .product: return Color(.tertiarySystemFill)
        default: return nil
        }
    }

    private func press(_ key: Key) {
        switch key {
        case .digit(let value):
            appendDigit(value)
        case .decimal:
            if !currentSegment.contains(".") { text += "." }
        case .sum, .difference, .product:
            appendOperator(symbol(for: key))
        case .backspace:
            if !text.isEmpty { text.removeLast() }
        case .equals:
            if let folded = Self.evaluate(text) { text = folded }
        }
    }

    private var currentSegment: Substring {
        text.split(whereSeparator: { "+−×".contains($0) }).last ?? ""
    }

    private func appendDigit(_ value: String) {
        let segment = currentSegment
        if segment.contains(".") {
            let fraction = segment.split(separator: ".").last ?? ""
            if fraction.count >= 2 { return }
        } else if segment == "0" {
            // "0" is a placeholder, not a leading digit.
            text = String(text.dropLast()) + value
            return
        }
        if text.count >= 12 { return }
        text += value
    }

    private func appendOperator(_ symbol: String) {
        guard !text.isEmpty, !text.hasSuffix("+"), !text.hasSuffix("−"), !text.hasSuffix("×") else { return }
        text += symbol
    }

    private func confirm() {
        onConfirm(Self.evaluate(text) ?? text)
    }

    /// Folds the keypad's additive/multiplicative expression into a cent-accurate amount.
    /// Returns nil when there is nothing to fold, leaving the caller's text untouched.
    static func evaluate(_ expression: String) -> String? {
        let source = expression
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "−", with: "-")
        guard source.contains("+") || source.contains("-") || source.contains("*"),
              source.allSatisfy({ $0.isNumber || "+-*/.".contains($0) }),
              let value = NSExpression(format: source).expressionValue(with: nil, context: nil) as? NSNumber
        else { return nil }
        // Money is rounded through Decimal: folding via Double would hand the ledger a binary
        // approximation of a cent.
        let decimal = Decimal((value.doubleValue * 100).rounded()) / 100
        return NSDecimalNumber(decimal: decimal).stringValue
    }
}
