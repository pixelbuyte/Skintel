import SwiftUI

/// `.input` from the spec: cream, 1px line, 14pt radius, 52pt tall.
struct SKTextField: View {
    let placeholder: String
    @Binding var text: String
    var secure = false
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .sentences
    var submitLabel: SubmitLabel = .done
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        Group {
            if secure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(autocapitalization)
            }
        }
        .textContentType(contentType)
        .autocorrectionDisabled(secure || keyboard == .emailAddress || keyboard == .URL)
        .submitLabel(submitLabel)
        .onSubmit { onSubmit?() }
        .font(SKFont.body)
        .foregroundStyle(SKColor.ink)
        .padding(.horizontal, SKSpace.lg)
        .frame(height: 52)
        .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.button, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SKRadius.button, style: .continuous).stroke(SKColor.line, lineWidth: 1)
        }
    }
}

/// Multi-line input for pasted INCI lists and journal notes.
struct SKTextEditor: View {
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat = 120
    var mono = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(mono ? SKFont.data : SKFont.body)
                    .foregroundStyle(SKColor.muted.opacity(0.7))
                    .padding(.horizontal, SKSpace.lg + 4)
                    .padding(.top, 14)
                    .accessibilityHidden(true)
            }
            TextEditor(text: $text)
                .font(mono ? SKFont.data : SKFont.body)
                .foregroundStyle(SKColor.ink)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, SKSpace.md)
                .padding(.vertical, 6)
                .frame(minHeight: minHeight)
                .autocorrectionDisabled(mono)
                .textInputAutocapitalization(mono ? .never : .sentences)
        }
        .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(SKColor.line, lineWidth: 1)
        }
        .accessibilityLabel(placeholder)
    }
}

/// "SKIN TYPE" / "CONCERNS · PICK ANY" heading above a field group.
struct SKFieldLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).skLabelStyle().padding(.bottom, 2)
    }
}
