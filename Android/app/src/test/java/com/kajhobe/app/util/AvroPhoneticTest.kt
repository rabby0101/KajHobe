package com.kajhobe.app.util

import org.junit.Assert.assertEquals
import org.junit.Test
import java.text.Normalizer

/**
 * Keep these word pairs in sync with the web (`engine.test.ts`) and iOS Avro
 * tests so all three ports stay consistent. Values are canonical Avro Phonetic
 * outputs (Bengali consonants carry an inherent "o", so e.g. `bhalo` -> ভাল and
 * ধন্যবাদ is typed `dhonyobad`).
 */
class AvroPhoneticTest {

    private fun nfc(s: String) = Normalizer.normalize(s, Normalizer.Form.NFC)

    private val pairs = listOf(
        "ami" to "আমি",
        "kaj" to "কাজ",
        "kemon" to "কেমন",
        "bangla" to "বাংলা",
        "banglay" to "বাংলায়",
        "bhalo" to "ভাল",
        "dhonyobad" to "ধন্যবাদ",
    )

    @Test
    fun transliteratesWordPairs() {
        for ((input, expected) in pairs) {
            assertEquals(input, nfc(expected), nfc(AvroPhonetic.transliterate(input)))
        }
    }

    @Test
    fun transliteratesReferenceSentence() {
        assertEquals(
            nfc("আমি বাংলায় গান গাই"),
            nfc(AvroPhonetic.transliterate("ami banglay gan gai")),
        )
    }

    @Test
    fun transliteratesOnlyLastWord() {
        assertEquals(nfc("আমি কাজ"), nfc(AvroPhonetic.transliterateLastWord("আমি kaj")))
        assertEquals("আমি ", AvroPhonetic.transliterateLastWord("আমি "))
    }
}
