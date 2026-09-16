import PhotosUI
import SwiftUI

struct TicketEditorView: View {
    @ObservedObject var model: AppViewModel
    @State private var selectedCustomPhoto: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    PassPreviewView(
                        passKind: model.passKind,
                        fields: model.fields,
                        barcode: model.selectedBarcode,
                        passColor: model.passColor,
                        customFields: model.customFields,
                        customPhotoData: model.customPhotoData,
                        photoAspect: model.photoAspect
                    )

                    if !model.isCustomMode { passKindSection }

                    if let analysis = model.analysis {
                        ForEach(analysis.warnings, id: \.self) { warning in
                            WarningView(text: warning, isError: analysis.barcodeCandidates.isEmpty)
                        }
                        barcodeSection(analysis.barcodeCandidates)
                    }

                    if model.isCustomMode { customBarcodeSection }

                    fieldsSection
                    colorSection

                    AddToWalletButton(
                        isLoading: model.isCreatingPass,
                        isDisabled: !model.canCreatePass,
                        action: model.createPass
                    )

                    Text(L10n.text("Pase personal. Conserva el archivo original para cualquier comprobación."))
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
        .onChange(of: selectedCustomPhoto) { _, item in
            guard let item else { return }
            Task {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        throw AnyWalletError.invalidDocument
                    }
                    try model.setCustomPhoto(data: data)
                } catch {
                    model.errorMessage = error.localizedDescription
                }
                selectedCustomPhoto = nil
            }
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
            .accessibilityLabel(L10n.text("Volver"))

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.text("Nuevo pase")).font(.headline).foregroundStyle(AppTheme.ink)
                Text(model.isCustomMode ? L10n.text("Creado desde cero") : (model.analysis?.filename ?? ""))
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(1)
            }
            Spacer()
            if !model.isCustomMode {
                Label("\(model.analysis?.pageCount ?? 0)", systemImage: "doc")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.muted)
                    .padding(.horizontal, 9)
                    .frame(height: 30)
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
                    .overlay { RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line) }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 66)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var passKindSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(L10n.text("Tipo de pase")).font(.title3.bold()).foregroundStyle(AppTheme.ink)
            Picker(L10n.text("Tipo de pase"), selection: Binding(
                get: { model.passKind },
                set: model.selectPassKind
            )) {
                ForEach([PassKind.travel, .membership]) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private func barcodeSection(_ candidates: [BarcodeCandidate]) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(L10n.text("Código")).font(.title3.bold()).foregroundStyle(AppTheme.ink)
            if candidates.isEmpty {
                Label(L10n.text("Necesitas otro archivo con un código QR o de barras legible."), systemImage: "barcode.viewfinder")
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
            Text(L10n.text("Datos del pase")).font(.title3.bold()).foregroundStyle(AppTheme.ink)
            LabeledField(
                label: L10n.text("Título"),
                placeholder: model.passKind == .travel ? L10n.text("Mi billete") : L10n.text("Mi membresía"),
                text: $model.fields.title
            )
            if model.passKind == .travel {
                HStack(alignment: .top, spacing: 10) {
                    LabeledField(label: L10n.text("Origen"), placeholder: L10n.text("Origen"), text: $model.fields.origin)
                    LabeledField(label: L10n.text("Destino"), placeholder: L10n.text("Destino"), text: $model.fields.destination)
                }
                DateField(label: L10n.text("Fecha y hora"), pickerLabel: L10n.text("Fecha del viaje"), date: $model.fields.relevantDate)
                LabeledField(label: L10n.text("Viajero"), placeholder: L10n.text("Opcional"), text: $model.fields.passenger)
                HStack(alignment: .top, spacing: 10) {
                    LabeledField(label: L10n.text("Operador"), placeholder: L10n.text("Opcional"), text: $model.fields.issuer)
                    LabeledField(label: L10n.text("Referencia"), placeholder: L10n.text("Opcional"), text: $model.fields.reference)
                }
            } else if model.passKind == .membership {
                LabeledField(label: L10n.text("Comercio o programa"), placeholder: L10n.text("Ej. Lidl Plus"), text: $model.fields.issuer)
                LabeledField(label: L10n.text("Titular"), placeholder: L10n.text("Opcional"), text: $model.fields.memberName)
                LabeledField(label: L10n.text("Número de socio"), placeholder: L10n.text("Opcional"), text: $model.fields.memberNumber)
                DateField(label: L10n.text("Fecha de caducidad"), pickerLabel: L10n.text("Caducidad"), date: $model.fields.relevantDate)
            } else {
                customPhotoSection
                ForEach($model.customFields) { $field in
                    HStack(alignment: .bottom, spacing: 8) {
                        LabeledField(label: L10n.text("Etiqueta"), placeholder: L10n.text("Ej. Departamento"), text: $field.label)
                        LabeledField(label: L10n.text("Valor"), placeholder: L10n.text("Ej. Diseño"), text: $field.value)
                        Button(role: .destructive) { model.removeCustomField(id: field.id) } label: {
                            Image(systemName: "trash")
                                .frame(width: 42, height: 48)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(AppTheme.danger)
                        .accessibilityLabel(L10n.text("Eliminar campo"))
                    }
                }
                Button(action: model.addCustomField) {
                    Label(L10n.text("Añadir campo"), systemImage: "plus.circle")
                        .font(.subheadline.weight(.semibold))
                }
                .disabled(model.customFields.count >= 4)
            }
        }
    }

    private var customPhotoSection: some View {
        let photoData = model.customPhotoData
        let hasPhoto = photoData != nil
        return VStack(alignment: .leading, spacing: 10) {
            Text(L10n.text("IMAGEN (OPCIONAL)")).font(.caption2.bold()).foregroundStyle(AppTheme.muted)
            Picker(L10n.text("Proporción"), selection: $model.photoAspect) {
                ForEach(PhotoAspect.allCases) { aspect in Text(aspect.title).tag(aspect) }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                if let data = photoData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 92, height: 92 / model.photoAspect.ratio)
                        .frame(maxHeight: 122)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                VStack(alignment: .leading, spacing: 8) {
                    PhotosPicker(selection: $selectedCustomPhoto, matching: .images) {
                        Label(hasPhoto ? L10n.text("Cambiar foto") : L10n.text("Elegir foto"), systemImage: "photo")
                    }
                    if hasPhoto {
                        Button(L10n.text("Quitar"), role: .destructive) { model.customPhotoData = nil }
                    }
                    Text(L10n.text("Se comprime en el iPhone y el servidor solo la mantiene en memoria mientras firma."))
                        .font(.caption2)
                        .foregroundStyle(AppTheme.muted)
                }
            }
        }
        .padding(13)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line) }
    }

    private var customBarcodeSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text(L10n.text("Código opcional")).font(.title3.bold()).foregroundStyle(AppTheme.ink)
                Spacer()
                Picker(L10n.text("Formato"), selection: $model.customBarcodeFormat) {
                    ForEach([BarcodeFormat.qr, .code128, .pdf417, .aztec], id: \.rawValue) { format in
                        Text(format.title).tag(format)
                    }
                }
                .pickerStyle(.menu)
            }
            LabeledField(
                label: L10n.text("Contenido"),
                placeholder: L10n.text("Texto, número o URL"),
                text: $model.customBarcodeValue
            )
            Text(L10n.text("Déjalo vacío si tu pase no necesita código."))
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
            if !model.customBarcodeValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               model.selectedBarcode == nil {
                Text(L10n.text("El contenido no es compatible con el formato elegido."))
                    .font(.caption)
                    .foregroundStyle(AppTheme.danger)
            }
        }
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(L10n.text("Color")).font(.title3.bold()).foregroundStyle(AppTheme.ink)
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
                    Text(L10n.format("Página %d · %d bytes", candidate.page, candidate.byteLength))
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
                Text(isLoading ? L10n.text("Preparando pase…") : L10n.text("Añadir a Apple Wallet"))
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(.black, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
        .accessibilityLabel(isLoading ? L10n.text("Preparando pase") : L10n.text("Añadir a Apple Wallet"))
    }
}
