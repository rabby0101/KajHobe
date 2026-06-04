package com.kajhobe.app.data.model

import kotlinx.serialization.json.Json

/**
 * Shared JSON configuration mirroring iOS's tolerant decoders
 * (decodeIfPresent fallbacks, ignored unknown keys).
 *
 *  - ignoreUnknownKeys: backend may return extra columns we don't model
 *  - coerceInputValues: null / invalid enum values fall back to defaults instead of crashing
 *  - explicitNulls=false: omit null fields when encoding inserts
 */
val AppJson: Json = Json {
    ignoreUnknownKeys = true
    coerceInputValues = true
    explicitNulls = false
    isLenient = true
}
