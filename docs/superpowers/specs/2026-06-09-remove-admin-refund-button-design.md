# Remove Admin "Refund to Buyer" Button — Design

**Date:** 2026-06-09
**Status:** Approved
**Scope:** View-only change to `KajHobe/Payments/EscrowSectionView.swift`

## Goal

Hide the "Refund to buyer" admin button that appears in the **Escrow & Payment** section of the deal details view. The app has no in-app refund flow that should be exposed here; only manual admin payout remains a supported admin action.

## Background

`EscrowSectionView` is the "Escrow & Payment" card rendered inside `DealDetailView` (`KajHobe/DealDetailView.swift:45`). When the current user passes `EscrowNetworking.isCurrentUserAdmin()`, an admin action block (`adminActions(_:)`) is shown with up to two buttons depending on escrow state:

- `state == .released` → "Mark paid out to provider"
- `state == .held || state == .released` → "Refund to buyer"

The "Refund to buyer" button is only visible to admins — regular buyers/providers never see it. The user has confirmed they want this specific button removed while keeping the payout button intact.

## Design

### Changes (all in `KajHobe/Payments/EscrowSectionView.swift`)

1. **`adminActions(_ escrow:)` — lines 87–110**
   Delete the second conditional block that renders the "Refund to buyer" button (lines 102–108). The first conditional block (payout) stays untouched.

   ```swift
   // REMOVE these lines (102-108):
   if escrow.state == .held || escrow.state == .released {
       Button(action: { adminRefund(escrow) }) {
           Label("Refund to buyer", systemImage: "arrow.uturn.backward.circle")
               .frame(maxWidth: .infinity).padding()
               .background(Color.orange.opacity(0.15)).foregroundColor(.orange).cornerRadius(10)
       }.disabled(isWorking)
   }
   ```

2. **`adminRefund(_ escrow:)` — lines 178–189**
   Delete the unused private method. It is only called by the button being removed, and removing it eliminates dead code.

### Explicitly NOT changed

- `EscrowNetworking.markRefunded(escrowId:note:)` — keep intact so refunds can still be triggered via other surfaces (server-side, future admin tools).
- `PaymentProvider.refund(escrowId:note:)` and its implementations in `KajHobe/Payments/PaymentProvider.swift` — keep intact for the same reason.
- `EscrowState.refunded` enum case, its display label "Refunded", `roleCopy` branch ("This payment was refunded to the buyer."), and its color/icon — still used to **display** already-refunded deals that may have been refunded through any path.
- The "Mark paid out to provider" button and its `adminMarkPaidOut` handler — still supported.
- The `isAdmin` flag, the `adminActions` view container, and the "Admin" section divider/label — payout still needs them.
- `EscrowNetworking.isCurrentUserAdmin()` — still needed for the payout gating.
- All other files in the project.

## Resulting UI behavior

| User role | Escrow state | Admin block contents after change |
|-----------|--------------|-----------------------------------|
| Non-admin | any | hidden (no change) |
| Admin | `.held` | empty (no buttons) |
| Admin | `.released` | "Mark paid out to provider" only |
| Admin | `.paid_out` / `.refunded` / `.failed` / `.pending` / `.resolved` | empty (no buttons) |

The `adminActions` container's "Admin" label and divider will still render even when the block is empty (e.g., for `.held` state as admin). This matches the existing pattern of the container being shown whenever `isAdmin` is true and an escrow exists, and is acceptable visual cost for the minimal-scope change. (Empty admin block is a minor cosmetic side-effect — acceptable per YAGNI; revisit only if it looks bad in practice.)

## Risk Assessment

- **Risk:** Essentially zero.
- **Blast radius:** One SwiftUI view file. No data model, no API surface, no DB schema touched.
- **Rollback:** Single-file revert via git.
- **Behavioral change for users:** Admins lose the in-app ability to issue refunds. The networking layer still supports refunds if needed from elsewhere.

## Verification

1. Build the project: `xcodebuild -project KajHobe.xcodeproj -scheme KajHobe -destination 'platform=iOS Simulator,name=iPhone 16' build` — must compile without warnings about unused `adminRefund` (we're removing it).
2. Open any deal where the current user is an admin and escrow is in `.released` state — confirm only the "Mark paid out to provider" button is visible.
3. Open any deal where the current user is an admin and escrow is in `.held` state — confirm the "Admin" section renders with no buttons.
4. Open a deal as a non-admin user — confirm no admin block is visible (unchanged behavior).
5. Open a deal whose escrow is already `.refunded` (from any source) — confirm the status badge and "This payment was refunded to the buyer." copy still display correctly.

## Out of Scope

- Removing the `EscrowNetworking.markRefunded` wrapper or the `refund(escrowId:note:)` protocol method.
- Removing the `refunded` escrow state.
- Adding any other refund surface (e.g., a buyer-initiated refund button) — explicitly not requested.
- Removing the entire admin block — only the refund button is in scope.
