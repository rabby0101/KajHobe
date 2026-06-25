package com.kajhobe.app.data.dashboard

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.kajhobe.app.data.model.AppJson
import com.kajhobe.app.data.model.DashboardData
import com.kajhobe.app.data.model.Deal
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.Serializable

/** Snapshot of the dashboard summary + active deals — what we cache to disk. */
@Serializable
data class DashboardSnapshot(
    val dashboard: DashboardData,
    val activeDeals: List<Deal>,
)

private val Context.dashboardDataStore by preferencesDataStore("dashboard_cache")

/**
 * In-memory + DataStore cache for the dashboard (mirrors iOS `DashboardCache.shared`).
 * Registered as a Koin singleton, so the in-memory mirror survives navigation.
 */
class DashboardCache(private val context: Context) {

    @Volatile
    private var memory: DashboardSnapshot? = null

    private val key = stringPreferencesKey("dashboard_snapshot_json")

    /** Synchronous in-memory snapshot — null on a cold start. */
    fun peek(): DashboardSnapshot? = memory

    /**
     * Read the snapshot, preferring the in-memory mirror. Falls back to a blocking
     * DataStore read so `peek()`-only callers (e.g. the first frame) can paint
     * without going through a coroutine.
     */
    fun peekOrLoadBlocking(): DashboardSnapshot? {
        memory?.let { return it }
        return runCatching {
            val prefs = runBlocking { context.dashboardDataStore.data.first() }
            val json = prefs[key] ?: return null
            AppJson.decodeFromString(DashboardSnapshot.serializer(), json)
                .also { memory = it }
        }.getOrNull()
    }

    /** Coroutine version: read from disk and cache the result. */
    suspend fun load(): DashboardSnapshot? {
        memory?.let { return it }
        return runCatching {
            val prefs = context.dashboardDataStore.data.first()
            val json = prefs[key] ?: return null
            AppJson.decodeFromString(DashboardSnapshot.serializer(), json).also { memory = it }
        }.getOrNull()
    }

    /** Update the in-memory mirror and persist to disk. */
    suspend fun save(snapshot: DashboardSnapshot) {
        memory = snapshot
        runCatching {
            val json = AppJson.encodeToString(DashboardSnapshot.serializer(), snapshot)
            context.dashboardDataStore.edit { it[key] = json }
        }
    }
}
