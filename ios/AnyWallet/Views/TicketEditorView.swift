import SwiftUI

struct TicketEditorView: View {
    @ObservedObject var model: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    PassPreviewView(
                        passKind: model.passKind,
                        fields: model.fields,
                        barcode: model.selectedBarcode,
                        passColor: model.passColor
                    )

                    passKindSection

                    if let analysis = model.analysis {
                        ForEach(analysis.warnings, id: \.self) { warning in
                            WarningView(text: warning, isError: analysis.barcodeCandidates.isEmpty)
                        }
                        barcodeSection(analysis.barcodeCandidates)
                    }

                    fieldsSection
                    colorSection

                    AddToWalletButton(
                        isLoading: model.isCreatingPass,
                        isDisabled: !model.canCreatePass,
                        action: model.createPass
                    )

                    Text("Pase personal. Conserva el archivo original para cualquier comprobación.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                }
                .padding(16)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: model.reset) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel("Volver")

            VStack(alignment: .leading, spacing: 2) {
                Text("Nuevo pase").font(.headline).foregroundStyle(AppTheme.ink)
                Text(model.analysis?.filename ?? "")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(1)
            }
            Spacer()
            Label("\(model.analysis?.pageCount ?? 0)", systemImage: "doc")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.muted)
                .padding(.horizontal, 9)
                .frame(height: 30)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
                .overlay { RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line) }
        }
        .padding(.horizontal, 16)
        .frame(height: 66)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var passKindSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Tipo de pase").font(.title3.bold()).foregroundStyle(AppTheme.ink)
            Picker("Tipo de pase", selection: Binding(
                get: { model.passKind },
                set: model.selectPassKind
            )) {
                ForEach(PassKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private func barcodeSection(_ candidates: [BarcodeCandidate]) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Código").font(.title3.bold()).foregroundStyle(AppTheme.ink)
            if candidates.isEmpty {
                Label("Necesitas otro archivo con un código QR o de barras legible.", systemImage: "barcode.viewfinder")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.danger)
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                    .padding(.horizontal, 14)
                    .background(AppTheme.danger.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    .overlay { RoundedRectangle(cornerRadius: 8).stroke(AppTheme.danger.opacity(0.25)) }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(candidates.enumerated()), id: \.element.id) { index, candidate in
                            BarcodeChoice(
                                candidate: candidate,
                                index: index,
                                isSelected: candidate.id == model.selectedBarcodeID
                            ) {
                                model.selectedBarcodeID = candidate.id
                            }
                        }
                    }
                }
            }
        }
    }

    private var fieldsSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Datos del pase").font(.title3.bold()).foregroundStyle(AppTheme.ink)
            LabeledField(
                label: "Título",
                placeholder: model.passKind == .travel ? "Mi billete" : "Mi membresía",
                text: $model.fields.title
            )
            if model.passKind == .travel {
                HStack(alignment: .top, spacing: 10) {
                    LabeledField(label: "Origen", placeholder: "Origen", text: $model.fields.origin)
                    LabeledField(label: "Destino", placeholder: "Destino", text: $model.fields.destination)
                }
                DateField(label: "Fecha y hora", pickerLabel: "Fecha del viaje", date: $model.fields.relevantDate)
                LabeledField(label: "Viajero", placeholder: "Opcional", text: $model.fields.passenger)
                HStack(alignment: .top, spacing: 10) {
                    LabeledField(label: "Operador", placeholder: "Opcional", text: $model.fields.issuer)
                    LabeledField(label: "Referencia", placeholder: "Opcional", text: $model.fields.reference)
                }
            } else {
                LabeledField(label: "Comercio o programa", placeholder: "Ej. Lidl Plus", text: $model.fields.issuer)
                LabeledField(label: "Titular", placeholder: "Opcional", text: $model.fields.memberName)
                LabeledField(label: "Número de socio", placeholder: "Opcional", text: $model.fields.memberNumber)
                DateField(label: "Fecha de caducidad", pickerLabel: "Caducidad", date: $model.fields.relevantDate)
            }
        }
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Color").font(.title3.bold()).foregroundStyle(AppTheme.ink)
            HStack(spacing: 13) {
                ForEach(PassColor.choices) { option in
                    Button {
                        model.passColor = option
                    } label: {
                        ZStack {
                            Circle().fill(option.color).frame(width: 42, height: 42)
                            if model.passColor == option {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.name)
                    .accessibilityAddTraits(model.passColor == option ? .isSelected : [])
                }
            }
        }
    }
}

private struct LabeledField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label.uppercased())
                .font(.caption2.bold())
                .foregroundStyle(AppTheme.muted)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(.horizontal, 13)
                .frame(height: 48)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
                .overlay { RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line) }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct DateField: View {
    let label: String
    let pickerLabel: String
    @Binding var date: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(label, isOn: Binding(
                get: { date != nil },
                set: { enabled in date = enabled ? (date ?? Date()) : nil }
            ))
            .font(.subheadline.weight(.semibold))
            .tint(AppTheme.accent)

            if date != nil {
                DatePicker(
                    pickerLabel,
                    selection: Binding(get: { date ?? Date() }, set: { date = $0 }),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(13)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line) }
    }
}

private struct BarcodeChoice: View {
    let candidate: BarcodeCandidate
    let index: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(uiImage: candidate.preview)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 82, height: 70)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(candidate.format.title) \(index + 1)").font(.subheadline.bold()).foregroundStyle(AppTheme.ink)
                    Text("Página \(candidate.page) · \(candidate.byteLength) bytes")
                        .font(.caption2).foregroundStyle(AppTheme.muted)
                    if let value = candidate.readableValue {
                        Text(value).font(.caption2).foregroundStyle(AppTheme.muted).lineLimit(1)
                    }
                }
                Spacer(minLength: 2)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.muted)
            }
            .padding(10)
            .frame(width: 292, height: 94)
            .background(isSelected ? AppTheme.accent.opacity(0.06) : AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay { RoundedRectangle(cornerRadius: 8).stroke(isSelected ? AppTheme.accent : AppTheme.line, lineWidth: isSelected ? 2 : 1) }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct WarningView: View {
    let text: String
    let isError: Bool

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(isError ? AppTheme.danger : Color(red: 0.60, green: 0.40, blue: 0))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background((isError ? AppTheme.danger : Color.yellow).opacity(0.09))
            .overlay(alignment: .leading) {
                Rectangle().fill(isError ? AppTheme.danger : Color.yellow.opacity(0.8)).frame(width: 3)
            }
    }
}

private struct AddToWalletButton: View {
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 32, height: 32)
                } else {
                    Image("WalletIcon")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                }
                Text(isLoading ? "Preparando pase…" : "Añadir a Apple Wallet")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(.black, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
        .accessibilityLabel(isLoading ? "Preparando pase" : "Añadir a Apple Wallet")
    }
}
