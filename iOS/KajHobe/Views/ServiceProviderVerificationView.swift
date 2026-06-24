import SwiftUI
import PhotosUI
import Supabase

/// Service-provider verification application. Opened when a user turns on the
/// "Service Provider" toggle. Collects NID number + photos, a verified phone,
/// optional certificates, and YouTube-style work-demo links, then submits a
/// `pending` request for manual admin approval. The Verified badge is only
/// granted by the admin panel — never by this screen.
struct ServiceProviderVerificationView: View {
    /// Existing request used to prefill on resubmit (e.g. after a rejection).
    var existing: ProviderVerification?
    /// The account's phone, if it signed up by phone (already verified).
    var accountPhone: String?
    /// Called after a successful submit so the caller can refresh state.
    var onSubmitted: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var nidNumber = ""
    @State private var nidFrontItem: PhotosPickerItem?
    @State private var nidFrontData: Data?
    @State private var nidBackItem: PhotosPickerItem?
    @State private var nidBackData: Data?
    @State private var certItems: [PhotosPickerItem] = []
    @State private var certData: [Data] = []
    @State private var demoURLs: [String] = []
    @State private var demoInput = ""

    // Phone is optional contact info now (phone OTP postponed); verified only if
    // it came from the account's signup phone.
    @State private var phone = ""
    @State private var phoneVerified = false

    @State private var isSubmitting = false
    @State private var errorMessage = ""

    private var canSubmit: Bool {
        !nidNumber.trimmingCharacters(in: .whitespaces).isEmpty
            && nidFrontData != nil
            && !isSubmitting
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("verify_intro".localized)
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section("verify_nid_section".localized) {
                    TextField("verify_nid_number".localized, text: $nidNumber)
                        .keyboardType(.numbersAndPunctuation)
                    docPickerRow(title: "verify_nid_front".localized, item: $nidFrontItem, data: $nidFrontData)
                    docPickerRow(title: "verify_nid_back".localized, item: $nidBackItem, data: $nidBackData)
                }

                Section("verify_phone_section".localized) {
                    TextField("phone_hint_bd".localized, text: $phone)
                        .keyboardType(.numberPad)
                        .disabled(phoneVerified)
                    if phoneVerified {
                        Label("verified".localized, systemImage: "checkmark.seal.fill")
                            .font(.caption).foregroundStyle(.blue)
                    }
                }

                Section {
                    PhotosPicker(selection: $certItems, maxSelectionCount: 6, matching: .images) {
                        Label("verify_add_certificates".localized, systemImage: "doc.badge.plus")
                    }
                    if !certData.isEmpty {
                        Text(String(format: "verify_certificates_count".localized, certData.count))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("verify_certificates_section".localized)
                } footer: {
                    Text("verify_certificates_hint".localized)
                }

                Section {
                    demoLinksRows
                } header: {
                    Text("verify_demos_section".localized)
                } footer: {
                    Text("verify_demos_hint".localized)
                }

                if !errorMessage.isEmpty {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }

                Section {
                    Button { submit() } label: {
                        HStack {
                            if isSubmitting { ProgressView().scaleEffect(0.8) }
                            Text("verify_submit".localized).fontWeight(.semibold)
                        }
                    }
                    .disabled(!canSubmit)
                }
            }
            .navigationTitle("verify_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) { dismiss() }
                }
            }
        }
        .onAppear(perform: prefill)
        .onChange(of: nidFrontItem) { _, item in loadImage(item, into: $nidFrontData) }
        .onChange(of: nidBackItem) { _, item in loadImage(item, into: $nidBackData) }
        .onChange(of: certItems) { _, items in loadCertImages(items) }
    }

    // MARK: - Demo links UI

    @ViewBuilder
    private var demoLinksRows: some View {
        ForEach(Array(demoURLs.enumerated()), id: \.offset) { index, url in
            HStack {
                Image(systemName: "play.rectangle.fill").foregroundStyle(.red)
                Text(url).font(.caption).lineLimit(1)
                Spacer()
                Button {
                    demoURLs.remove(at: index)
                } label: { Image(systemName: "minus.circle.fill").foregroundStyle(.red) }
                .buttonStyle(.plain)
            }
        }
        HStack {
            TextField("verify_demo_url_placeholder".localized, text: $demoInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
            Button {
                let trimmed = demoInput.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { demoURLs.append(trimmed); demoInput = "" }
            } label: { Image(systemName: "plus.circle.fill") }
            .disabled(demoInput.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func docPickerRow(title: String, item: Binding<PhotosPickerItem?>, data: Binding<Data?>) -> some View {
        PhotosPicker(selection: item, matching: .images) {
            HStack {
                Label(title, systemImage: "photo.badge.plus")
                Spacer()
                if data.wrappedValue != nil {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }
        }
    }

    // MARK: - Logic

    private func prefill() {
        phone = accountPhone ?? existing?.phone ?? ""
        // A phone that already exists on the auth account is considered verified.
        if let account = accountPhone, !account.isEmpty { phoneVerified = true; phone = account }
        else if existing?.phone_verified == true { phoneVerified = true }
        nidNumber = existing?.nid_number ?? ""
        demoURLs = existing?.demo_video_urls ?? []
    }

    private func loadImage(_ item: PhotosPickerItem?, into target: Binding<Data?>) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await MainActor.run { target.wrappedValue = data }
            }
        }
    }

    private func loadCertImages(_ items: [PhotosPickerItem]) {
        Task {
            var loaded: [Data] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self) { loaded.append(data) }
            }
            await MainActor.run { certData = loaded }
        }
    }

    private func submit() {
        // Phone is optional, but if provided it must be a valid BD mobile number
        // (matches the DB CHECK `^01[0-9]{9}$`). Validate up front for a clear
        // message instead of a raw Postgres constraint error after the uploads.
        let trimmedPhone = phone.trimmingCharacters(in: .whitespaces)
        if !trimmedPhone.isEmpty,
           trimmedPhone.range(of: "^01[0-9]{9}$", options: .regularExpression) == nil {
            errorMessage = "verify_phone_invalid".localized
            return
        }

        isSubmitting = true
        errorMessage = ""
        Task {
            do {
                let user = try supabase.auth.requireCurrentUser()
                let net = ProfileNetworking.shared
                let stamp = Int(Date().timeIntervalSince1970)

                var frontPath: String?
                if let data = nidFrontData {
                    frontPath = try await net.uploadProviderDoc(
                        bucket: "provider-nid", fileName: "nid-front-\(stamp).jpg", data: data)
                }
                var backPath: String?
                if let data = nidBackData {
                    backPath = try await net.uploadProviderDoc(
                        bucket: "provider-nid", fileName: "nid-back-\(stamp).jpg", data: data)
                }
                var certPaths: [String] = []
                for (i, data) in certData.enumerated() {
                    let path = try await net.uploadProviderDoc(
                        bucket: "provider-certificates", fileName: "cert-\(stamp)-\(i).jpg", data: data)
                    certPaths.append(path)
                }

                // Phone is optional now. Send nil (not "") when blank so the DB's
                // `phone IS NULL OR phone ~ '^01[0-9]{9}$'` CHECK isn't violated.
                let payload = ProviderVerificationSubmit(
                    user_id: user.id.uuidString,
                    status: "pending",
                    nid_number: nidNumber.trimmingCharacters(in: .whitespaces),
                    nid_front_path: frontPath,
                    nid_back_path: backPath,
                    phone: trimmedPhone.isEmpty ? nil : trimmedPhone,
                    phone_verified: phoneVerified && !trimmedPhone.isEmpty,
                    certificate_paths: certPaths,
                    demo_video_urls: demoURLs,
                    submitted_at: ISO8601DateFormatter().string(from: Date())
                )
                try await net.submitVerification(payload)

                await MainActor.run {
                    isSubmitting = false
                    onSubmitted()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = String(format: "verify_submit_failed".localized, error.localizedDescription)
                }
            }
        }
    }
}
