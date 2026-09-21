import SwiftUI

struct AmountKeyboard: View {
    @EnvironmentObject var loc: LocalizationManager
    @Binding var text: String
    var themeColor: Color = .accentColor
    let onConfirm: () -> Void

    private let rows: [[String]] = [
        ["1", "2", "3", "+"],
        ["4", "5", "6", "-"],
        ["7", "8", "9", "×"],
        [".", "0", "delete.left", "="]
    ]

    var body: some View {
        VStack(spacing: 5) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 5) {
                    ForEach(row, id: \.self) { key in
                        Button {
                            handleKeyPress(key)
                        } label: {
                            Group {
                                if key == "delete.left" {
                                    Image(systemName: "delete.left")
                                        .font(.callout.weight(.medium))
                                } else if isOperator(key) {
                                    Text(key)
                                        .font(.title3.weight(.semibold))
                                } else {
                                    Text(key)
                                        .font(.title3)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(keyBackgroundColor(key))
                            .foregroundStyle(keyForegroundColor(key))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }

            Button {
                saveWithAutoEvaluate()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body.weight(.semibold))
                    Text("Save")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(themeColor)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 0)
    }

    private func isOperator(_ key: String) -> Bool {
        ["+", "-", "×", "="].contains(key)
    }

    private func keyBackgroundColor(_ key: String) -> Color {
        if key == "=" {
            return themeColor.opacity(0.12)
        } else if isOperator(key) {
            return Color(.systemGray4)
        } else {
            return Color(.systemGray6)
        }
    }

    private func keyForegroundColor(_ key: String) -> Color {
        if key == "=" {
            return themeColor
        } else if isOperator(key) {
            return .secondary
        } else {
            return .primary
        }
    }

    private func handleKeyPress(_ key: String) {
        if key == "delete.left" {
            if !text.isEmpty { text.removeLast() }
        } else if key == "." {
            if !text.contains(".") { text += "." }
        } else if key == "+" || key == "-" || key == "×" {
            if text.isEmpty { return }
            let last = text.last
            if last == "+" || last == "-" || last == "×" {
                text.removeLast()
            }
            text += key
        } else if key == "=" {
            evaluateExpression()
        } else {
            if text == "0" && key != "." {
                text = key
            } else if text.contains(".") {
                let parts = text.split(separator: ".")
                if parts.count == 2 && parts[1].count >= 2 { return }
                text += key
            } else if text.count >= 12 {
                return
            } else {
                text += key
            }
        }
    }

    private func evaluateExpression() {
        let expr = text
            .replacingOccurrences(of: "×", with: "*")

        let nsExpr = NSExpression(format: expr)
        if let result = nsExpr.expressionValue(with: nil, context: nil) as? NSNumber {
            let doubleValue = result.doubleValue
            if doubleValue == floor(doubleValue) && abs(doubleValue) < 1e15 {
                text = String(format: "%.0f", doubleValue)
            } else {
                let rounded = (doubleValue * 100).rounded() / 100
                text = String(rounded)
            }
        }
    }

    private func saveWithAutoEvaluate() {
        if containsOperator(text) {
            evaluateExpression()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                onConfirm()
            }
        } else {
            onConfirm()
        }
    }

    private func containsOperator(_ s: String) -> Bool {
        s.contains("+") || s.contains("-") || s.contains("×")
    }
}
