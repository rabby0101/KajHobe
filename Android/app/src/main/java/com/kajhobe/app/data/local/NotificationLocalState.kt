package com.kajhobe.app.data.local

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringSetPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.kajhobe.app.data.model.parseIsoMillis
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

private val Context.notifDataStore by preferencesDataStore("notification_local_state")

/**
 * Device-local read / cleared state for notifications — the Android port of iOS
 * `NotificationLocalState`.
 *
 * Notifications are transient: the SERVER is the source of truth for *what* exists
 * (job_interests, notifications) and for real actions (accept / reject), while THIS store —
 * persisted in DataStore, scoped per user — owns whether each notification is read or cleared.
 *
 * Unread rule: `createdAt > baseline && id ∉ read && id ∉ cleared`. The `baseline` is stamped
 * the first time a user is configured on a build with this store, so the entire pre-existing
 * backlog is implicitly "read" and never inflates the badge — without a server migration.
 *
 * Trade-off (intentional, matches iOS): state lives on-device, so it does not sync across
 * devices and resets on reinstall.
 *
 * Reads ([isUnread]/[isCleared]) are synchronous against an in-memory mirror; writes persist
 * asynchronously and bump [revision] so observers (the feed + the bell badge) recompute.
 */
class NotificationLocalState(private val context: Context) {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    /** Bumped on every mutation so observers re-render / recompute (iOS @Published revision). */
    private val _revision = MutableStateFlow(0)
    val revision: StateFlow<Int> = _revision.asStateFlow()

    @Volatile private var userId: String = ""
    @Volatile private var readIds: Set<String> = emptySet()
    @Volatile private var clearedIds: Set<String> = emptySet()
    // Until the per-user baseline is loaded, treat everything as read (MAX) so we never flash
    // the whole backlog as unread during the brief async load.
    @Volatile private var baseline: Long = Long.MAX_VALUE

    private fun readKey(uid: String) = stringSetPreferencesKey("notif.read.$uid")
    private fun clearedKey(uid: String) = stringSetPreferencesKey("notif.cleared.$uid")
    private fun baselineKey(uid: String) = longPreferencesKey("notif.baseline.$uid")

    /** Scope the store to a user and load their persisted state. Idempotent. */
    fun configure(uid: String) {
        if (uid.isEmpty() || uid == userId) return
        userId = uid
        baseline = Long.MAX_VALUE
        readIds = emptySet()
        clearedIds = emptySet()
        scope.launch { load(uid) }
    }

    private suspend fun load(uid: String) {
        runCatching {
            val prefs = context.notifDataStore.data.first()
            // Union with any mutations that landed before the async load finished.
            readIds = (prefs[readKey(uid)] ?: emptySet()) + readIds
            clearedIds = (prefs[clearedKey(uid)] ?: emptySet()) + clearedIds
            val stored = prefs[baselineKey(uid)]
            baseline = if (stored != null) {
                stored
            } else {
                val now = System.currentTimeMillis()
                context.notifDataStore.edit { it[baselineKey(uid)] = now }
                now
            }
        }
        bump()
    }

    // MARK: - Queries

    fun isCleared(id: String): Boolean = clearedIds.contains(id)

    fun isUnread(id: String, createdAtIso: String?): Boolean {
        if (clearedIds.contains(id) || readIds.contains(id)) return false
        val created = parseIsoMillis(createdAtIso) ?: return false
        return created > baseline
    }

    // MARK: - Mutations

    fun markRead(id: String) = markRead(listOf(id))

    fun markRead(ids: List<String>) {
        val newOnes = ids.filter { it !in readIds }
        if (newOnes.isEmpty()) return
        readIds = readIds + newOnes
        persistRead()
        bump()
    }

    fun clear(id: String) = clear(listOf(id))

    fun clear(ids: List<String>) {
        if (ids.isEmpty()) return
        clearedIds = clearedIds + ids
        readIds = readIds - ids.toSet()
        persistCleared()
        persistRead()
        bump()
    }

    // MARK: - Persistence

    private fun persistRead() {
        val uid = userId
        val snapshot = readIds
        scope.launch { runCatching { context.notifDataStore.edit { it[readKey(uid)] = snapshot } } }
    }

    private fun persistCleared() {
        val uid = userId
        val snapshot = clearedIds
        scope.launch { runCatching { context.notifDataStore.edit { it[clearedKey(uid)] = snapshot } } }
    }

    private fun bump() {
        _revision.value = _revision.value + 1
    }
}
