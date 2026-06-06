import Foundation

/// Master switch for app console logging.
/// - `false` (default): everything is muted EXCEPT files listed in `kLoggingAllowlist`.
/// - `true`: every `print(...)` in the app emits (full firehose).
private let kConsoleLoggingEnabled = false

/// While the master switch is off, only `print(...)` calls originating from these files emit.
/// Matched against the last path component of `#fileID` (e.g. "MessagesView.swift").
/// Currently scoped to the Messages ("Messages" tab) feature: conversation list, chat screen,
/// input field, networking, conversation view model, and the unread-message badge manager.
/// Shared utilities (ProfileNetworking, PresenceManager) are intentionally excluded to avoid
/// app-wide log noise. Add/remove filenames here to retarget which area is logged. Empty the set
/// (with the master switch off) to mute everything.
private let kLoggingAllowlist: Set<String> = [
    "MessagesView.swift",
    "MessagesNetworking.swift",
    "ChatView.swift",
    "ChatTextFieldView.swift",
    "ConversationViewModel.swift",
    "MessageBadgeManager.swift",
]

/// Module-local shadow of `Swift.print`. Swift resolves unqualified `print(...)` calls in the
/// app target to this function in preference to the stdlib, so every existing call site routes
/// here with zero edits. `file` is captured at the call site via the `#fileID` default argument
/// (magic literals as default arguments evaluate in the caller's context), letting us gate output
/// per source file. Code that must always print can call `Swift.print(...)` explicitly.
func print(_ items: Any..., separator: String = " ", terminator: String = "\n", file: String = #fileID) {
    let name = file.split(separator: "/").last.map(String.init) ?? file
    guard kConsoleLoggingEnabled || kLoggingAllowlist.contains(name) else { return }
    Swift.print(items.map { "\($0)" }.joined(separator: separator), terminator: terminator)
}
