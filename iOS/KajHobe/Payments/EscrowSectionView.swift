import SwiftUI
import Supabase

// ---------------------------------------------------------------------------
// EscrowSectionView — read-only "Escrow & Payment" card for DealDetailView.
//
// Payment now happens at OFFER ACCEPTANCE (see ChatView "Accept & Pay"), so by
// the time a deal exists its escrow is already `held` (or later). This card no
// longer collects payment — it shows status + role copy, plus admin payout/refund.
// ---------------------------------------------------------------------------
struct EscrowSectionView: View {
    let dealId: String

    @State private var escrow: EscrowTransaction?
    @State private var isAdmin = false
    @State private var currentUserId: String = (supabase.auth.currentUser?.id.uuidString.lowercased() ?? "")
    @State private var isLoading = true
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var isBuyer: Bool {
        guard let e = escrow else { return false }
        return e.client_id.lowercased() == currentUserId
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lock.shield.fill").foregroundColor(.indigo)
                Text("Escrow & Payment").font(.headline).fontWeight(.medium)
                Spacer()
            }

            if isLoading {
                HStack { ProgressView(); Text("Loading…").foregroundColor(.secondary).font(.subheadline) }
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let escrow {
                statusBadge(for: escrow.state)
                Text(roleCopy(for: escrow.state))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                amountRow(escrow)

                if let err = errorMessage {
                    Text(err).font(.caption).foregroundColor(.red)
                }

                if isAdmin {
                    adminActions(escrow)
                }
            } else {
                Text("No payment record for this deal.")
                    .font(.subheadline).foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .task { await reload(initial: true) }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func statusBadge(for state: EscrowState) -> some View {
        HStack(spacing: 6) {
            Image(systemName: state.systemImage)
            Text(state.label).fontWeight(.semibold)
        }
        .font(.subheadline)
        .foregroundColor(color(for: state))
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(color(for: state).opacity(0.12))
        .cornerRadius(20)
    }

    @ViewBuilder
    private func amountRow(_ escrow: EscrowTransaction) -> some View {
        HStack {
            Text(escrow.formattedAmount).font(.title3).fontWeight(.bold)
            Text(escrow.state == .paid_out ? "paid to provider" : "deal amount")
                .font(.caption).foregroundColor(.secondary)
            Spacer()
        }
    }

    @ViewBuilder
    private func adminActions(_ escrow: EscrowTransaction) -> some View {
        VStack(spacing: 8) {
            Divider()
            Text("Admin").font(.caption).foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if escrow.state == .released {
                Button(action: { adminMarkPaidOut(escrow) }) {
                    Label("Mark paid out to provider", systemImage: "arrow.up.right.circle.fill")
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.green).foregroundColor(.white).cornerRadius(10)
                }.disabled(isWorking)
            }

            if escrow.state == .held || escrow.state == .released {
                Button(action: { adminRefund(escrow) }) {
                    Label("Refund to buyer", systemImage: "arrow.uturn.backward.circle")
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.orange.opacity(0.15)).foregroundColor(.orange).cornerRadius(10)
                }.disabled(isWorking)
            }
        }
    }

    // MARK: - Copy / colors

    private func roleCopy(for state: EscrowState) -> String {
        switch state {
        case .pending:
            return isBuyer ? "Payment not completed for this deal."
                           : "Waiting for the client's payment."
        case .held:
            return isBuyer ? "Your payment is held safely in escrow until the work is done."
                           : "Payment is secured in escrow and will be released when the deal completes."
        case .released:
            return isBuyer ? "Deal complete — the payment is being released to the provider."
                           : "Deal complete — your payout is being processed."
        case .paid_out:
            return isBuyer ? "The provider has been paid. Thank you!"
                           : "You've been paid for this deal."
        case .refunded:
            return "This payment was refunded to the buyer."
        case .failed:
            return "The last payment attempt failed."
        }
    }

    private func color(for state: EscrowState) -> Color {
        switch state {
        case .pending:  return .orange
        case .held:     return .blue
        case .released: return .purple
        case .paid_out: return .green
        case .refunded: return .gray
        case .failed:   return .red
        }
    }

    // MARK: - Actions

    private func reload(initial: Bool = false) async {
        if initial { isLoading = true }
        async let escrowTask = try? EscrowNetworking.shared.fetchEscrow(forDealId: dealId)
        async let adminTask = EscrowNetworking.shared.isCurrentUserAdmin()
        let (fetched, admin) = await (escrowTask, adminTask)
        await MainActor.run {
            // Keep the existing row on a transient fetch error (nil); only overwrite on success.
            if let fetched { self.escrow = fetched }
            self.isAdmin = admin
            self.isLoading = false
        }
    }

    private func adminMarkPaidOut(_ escrow: EscrowTransaction) {
        Task {
            await MainActor.run { isWorking = true; errorMessage = nil }
            do {
                try await EscrowNetworking.shared.markPaidOut(escrowId: escrow.id, note: "Manual bKash payout")
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
            await reload()
            await MainActor.run { isWorking = false }
        }
    }

    private func adminRefund(_ escrow: EscrowTransaction) {
        Task {
            await MainActor.run { isWorking = true; errorMessage = nil }
            do {
                try await EscrowNetworking.shared.markRefunded(escrowId: escrow.id, note: "Manual refund")
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
            await reload()
            await MainActor.run { isWorking = false }
        }
    }
}
