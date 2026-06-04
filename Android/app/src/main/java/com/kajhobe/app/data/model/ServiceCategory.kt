package com.kajhobe.app.data.model

import kotlinx.serialization.Serializable

/** Backend service category — iOS ServiceCategory. */
@Serializable
data class ServiceCategory(
    val id: String,
    val name: String,
    val description: String? = null,
    val icon: String? = null,
    val created_at: String? = null,
) {
    val displayIcon: String get() = icon ?: "🔧"
}

/** Hardcoded categories with Bengali names + emoji — iOS HardcodedServiceCategory. */
data class HardcodedServiceCategory(
    val id: String,
    val name: String,
    val bengaliName: String,
    val icon: String,
    val color: String,
) {
    companion object {
        val categories: List<HardcodedServiceCategory> = listOf(
            HardcodedServiceCategory("1", "Home Repair & Maintenance", "ঘর মেরামত ও রক্ষণাবেক্ষণ", "🔧", "blue"),
            HardcodedServiceCategory("2", "Home Services", "ঘরোয়া সেবা", "🏠", "green"),
            HardcodedServiceCategory("3", "Education & Tutoring", "শিক্ষা ও গৃহশিক্ষকতা", "📚", "purple"),
            HardcodedServiceCategory("4", "Technology & IT", "প্রযুক্তি ও আইটি", "💻", "indigo"),
            HardcodedServiceCategory("5", "Automotive", "গাড়ি ও যানবাহন", "🚗", "red"),
            HardcodedServiceCategory("6", "Personal Services", "ব্যক্তিগত সেবা", "✂️", "pink"),
            HardcodedServiceCategory("7", "Construction & Renovation", "নির্মাণ ও সংস্কার", "🔨", "orange"),
            HardcodedServiceCategory("8", "Food & Catering", "খাদ্য ও ক্যাটারিং", "🍽️", "yellow"),
            HardcodedServiceCategory("9", "Mobile & Electronics", "মোবাইল ও ইলেকট্রনিক্স", "📱", "teal"),
            HardcodedServiceCategory("10", "Events & Entertainment", "অনুষ্ঠান ও বিনোদন", "🎉", "cyan"),
        )

        fun categoryNames(): List<String> = categories.map { it.name }
        fun byName(name: String): HardcodedServiceCategory? = categories.firstOrNull { it.name == name }
    }
}
