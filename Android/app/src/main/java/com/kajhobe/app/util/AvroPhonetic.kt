package com.kajhobe.app.util

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * Avro Phonetic transliteration engine (Banglish -> Bangla).
 *
 * Original implementation of the well-known Avro Phonetic algorithm. The rule
 * table (`/avro_rules.json` on the classpath) is the MIT-licensed avrodict from
 * jsAvroPhonetic by Rifat Nabi / OmicronLab. This parser is an independent port
 * of the documented algorithm and is kept in sync with the web/iOS ports.
 */
object AvroPhonetic {

    @Serializable private data class Dict(val data: DictData)

    @Serializable private data class DictData(
        val patterns: List<Pattern>,
        val vowel: String,
        val consonant: String,
        val casesensitive: String,
    )

    @Serializable private data class Pattern(
        val find: String,
        val replace: String,
        val rules: List<Rule>? = null,
    )

    @Serializable private data class Rule(
        val matches: List<MatchRule>,
        val replace: String,
    )

    @Serializable private data class MatchRule(
        val type: String,
        val scope: String,
        val value: String? = null,
    )

    private val json = Json { ignoreUnknownKeys = true }

    private val data: DictData by lazy { load() }

    // Longest finds must win; only one find of a given length can match a cursor,
    // so a stable length-descending sort gives correct greedy matching.
    private val patterns: List<Pattern> by lazy { data.patterns.sortedByDescending { it.find.length } }
    private val nonRulePatterns: List<Pattern> by lazy { patterns.filter { it.rules == null } }
    private val rulePatterns: List<Pattern> by lazy { patterns.filter { it.rules != null } }

    private fun load(): DictData {
        val stream = AvroPhonetic::class.java.getResourceAsStream("/avro_rules.json")
            ?: error("avro_rules.json not found on classpath")
        val text = stream.bufferedReader().use { it.readText() }
        return json.decodeFromString<Dict>(text).data
    }

    private fun isVowel(c: Char) = data.vowel.contains(c.lowercaseChar())
    private fun isConsonant(c: Char) = data.consonant.contains(c.lowercaseChar())
    private fun isPunctuation(c: Char) = !isVowel(c) && !isConsonant(c)
    private fun isCaseSensitive(c: Char) = data.casesensitive.contains(c.lowercaseChar())

    private fun isExact(needle: String, hay: String, start: Int, end: Int, not: Boolean): Boolean =
        (start >= 0 && end <= hay.length && hay.substring(start, end) == needle) != not

    private fun fixCase(text: String): String =
        buildString { for (c in text) append(if (isCaseSensitive(c)) c else c.lowercaseChar()) }

    private fun firstMatch(fixed: String, cur: Int, list: List<Pattern>): Pattern? {
        for (p in list) {
            val end = cur + p.find.length
            if (end <= fixed.length && fixed.substring(cur, end) == p.find) return p
        }
        return null
    }

    private fun processMatch(m: MatchRule, fixed: String, cur: Int, curEnd: Int): Boolean {
        val negative = m.scope.startsWith("!")
        val scope = if (negative) m.scope.substring(1) else m.scope
        val chk = if (m.type == "prefix") cur - 1 else curEnd
        return when (scope) {
            "punctuation" -> {
                val cond = (chk < 0 && m.type == "prefix") ||
                    (chk >= fixed.length && m.type == "suffix") ||
                    isPunctuation(fixed[chk])
                cond != negative
            }
            "vowel" -> {
                val inRange = (chk >= 0 && m.type == "prefix") || (chk < fixed.length && m.type == "suffix")
                (inRange && isVowel(fixed[chk])) != negative
            }
            "consonant" -> {
                val inRange = (chk >= 0 && m.type == "prefix") || (chk < fixed.length && m.type == "suffix")
                (inRange && isConsonant(fixed[chk])) != negative
            }
            "exact" -> {
                val value = m.value ?: ""
                val start: Int
                val end: Int
                if (m.type == "prefix") {
                    start = cur - value.length
                    end = cur
                } else {
                    start = curEnd
                    end = curEnd + value.length
                }
                isExact(value, fixed, start, end, negative)
            }
            else -> false
        }
    }

    private fun processRules(rules: List<Rule>, fixed: String, cur: Int, curEnd: Int): String? {
        for (rule in rules) {
            var matched = true
            for (m in rule.matches) {
                if (!processMatch(m, fixed, cur, curEnd)) {
                    matched = false
                    break
                }
            }
            if (matched) return rule.replace
        }
        return null
    }

    /** Transliterate a Banglish string into Bangla using Avro Phonetic rules. */
    fun transliterate(text: String): String {
        val fixed = fixCase(text)
        val out = StringBuilder()
        var curEnd = 0
        var cur = 0
        while (cur < fixed.length) {
            if (cur < curEnd) {
                cur++
                continue
            }
            // Non-rule patterns take priority over rule patterns (matches reference).
            val nonRule = firstMatch(fixed, cur, nonRulePatterns)
            if (nonRule != null) {
                out.append(nonRule.replace)
                curEnd = cur + nonRule.find.length
                cur++
                continue
            }
            val rulePattern = firstMatch(fixed, cur, rulePatterns)
            val rules = rulePattern?.rules
            if (rules != null) {
                curEnd = cur + rulePattern.find.length
                out.append(processRules(rules, fixed, cur, curEnd) ?: rulePattern.replace)
                cur++
                continue
            }
            out.append(fixed[cur])
            curEnd = cur + 1
            cur++
        }
        return out.toString()
    }

    /**
     * Transliterate only the final, still-being-typed Latin word of [text],
     * leaving any text before the last word boundary untouched. Useful for live
     * per-word conversion where earlier words are already in Bangla.
     */
    fun transliterateLastWord(text: String): String {
        val match = Regex("[A-Za-z]+$").find(text) ?: return text
        val word = match.value
        return text.substring(0, text.length - word.length) + transliterate(word)
    }
}
