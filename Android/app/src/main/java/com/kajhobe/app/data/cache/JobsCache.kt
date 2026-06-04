package com.kajhobe.app.data.cache

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.kajhobe.app.data.model.AppJson
import com.kajhobe.app.data.model.Job
import kotlinx.coroutines.flow.first
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.SetSerializer
import kotlinx.serialization.builtins.serializer

/** Snapshot of the jobs list plus the set of job ids the user has already opened. */
data class CachedJobs(val jobs: List<Job>, val viewedIds: Set<String>)

private val Context.jobsDataStore by preferencesDataStore("jobs_cache")

/**
 * Disk-persisted (DataStore) + in-memory cache for the Jobs list, so the list paints
 * instantly on a cold start and navigation feels seamless. Reuses the tolerant [AppJson].
 * Registered as a Koin singleton, so the in-memory mirror survives navigation.
 */
class JobsCache(private val context: Context) {

    @Volatile
    private var memory: CachedJobs? = null

    private val jobsKey = stringPreferencesKey("jobs_json")
    private val viewedKey = stringPreferencesKey("viewed_ids_json")

    /** Synchronous in-memory snapshot — null on a cold start (use [load] to read disk). */
    fun peek(): CachedJobs? = memory

    /** Return the in-memory snapshot, or read and deserialize from disk and cache it. */
    suspend fun load(): CachedJobs? {
        memory?.let { return it }
        return runCatching {
            val prefs = context.jobsDataStore.data.first()
            val jobsJson = prefs[jobsKey] ?: return null
            val viewedJson = prefs[viewedKey]
            val jobs = AppJson.decodeFromString(ListSerializer(Job.serializer()), jobsJson)
            val viewed = viewedJson
                ?.let { AppJson.decodeFromString(SetSerializer(String.serializer()), it) }
                .orEmpty()
            CachedJobs(jobs, viewed).also { memory = it }
        }.getOrNull()
    }

    /** Update the in-memory mirror and persist to disk. */
    suspend fun save(jobs: List<Job>, viewedIds: Set<String>) {
        memory = CachedJobs(jobs, viewedIds)
        runCatching {
            val jobsJson = AppJson.encodeToString(ListSerializer(Job.serializer()), jobs)
            val viewedJson = AppJson.encodeToString(SetSerializer(String.serializer()), viewedIds)
            context.jobsDataStore.edit {
                it[jobsKey] = jobsJson
                it[viewedKey] = viewedJson
            }
        }
    }
}
