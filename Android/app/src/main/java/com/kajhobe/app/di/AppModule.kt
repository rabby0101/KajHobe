package com.kajhobe.app.di

import com.kajhobe.app.data.cache.JobsCache
import com.kajhobe.app.data.createKajHobeSupabaseClient
import com.kajhobe.app.data.local.NotificationLocalState
import com.kajhobe.app.data.media.MediaUploadManager
import com.kajhobe.app.data.notifications.NotificationBadgeManager
import com.kajhobe.app.data.repository.AuthRepository
import com.kajhobe.app.data.repository.DealsRepository
import com.kajhobe.app.data.repository.JobsRepository
import com.kajhobe.app.data.repository.MessagesRepository
import com.kajhobe.app.data.repository.NotificationsRepository
import com.kajhobe.app.data.repository.ProfileRepository
import com.kajhobe.app.ui.feature.auth.AuthViewModel
import com.kajhobe.app.ui.feature.dashboard.DashboardViewModel
import com.kajhobe.app.ui.feature.dashboard.DealDetailViewModel
import com.kajhobe.app.ui.feature.home.AllJobsViewModel
import com.kajhobe.app.ui.feature.home.HomeViewModel
import com.kajhobe.app.ui.feature.jobs.JobDetailViewModel
import com.kajhobe.app.ui.feature.jobs.JobsViewModel
import com.kajhobe.app.ui.feature.messages.ChatViewModel
import com.kajhobe.app.ui.feature.messages.ConversationsViewModel
import com.kajhobe.app.ui.feature.notifications.NotificationsViewModel
import com.kajhobe.app.ui.feature.postjob.PostJobViewModel
import com.kajhobe.app.ui.navigation.NavigationEventBus
import com.kajhobe.app.ui.navigation.RootViewModel
import io.github.jan.supabase.SupabaseClient
import org.koin.android.ext.koin.androidContext
import org.koin.core.module.dsl.singleOf
import org.koin.core.module.dsl.viewModelOf
import org.koin.dsl.module

/**
 * Koin DI graph. Koin is pure-runtime DI (no KSP/KAPT codegen), chosen because
 * no stable KSP exists for Kotlin 2.3.x yet.
 */
val appModule = module {
    single<SupabaseClient> { createKajHobeSupabaseClient() }
    single { NavigationEventBus() }
    single { JobsCache(androidContext()) }
    single { MediaUploadManager(androidContext(), get()) }

    // Notification device-local state + bell badge
    single { NotificationLocalState(androidContext()) }
    single { NotificationBadgeManager(get(), get()) }

    // Repositories
    singleOf(::ProfileRepository)
    singleOf(::AuthRepository)
    singleOf(::JobsRepository)
    singleOf(::DealsRepository)
    singleOf(::NotificationsRepository)
    singleOf(::MessagesRepository)

    // ViewModels
    viewModelOf(::RootViewModel)
    viewModelOf(::AuthViewModel)
    viewModelOf(::HomeViewModel)
    viewModelOf(::AllJobsViewModel)
    viewModelOf(::JobsViewModel)
    viewModelOf(::JobDetailViewModel)
    viewModelOf(::PostJobViewModel)
    viewModelOf(::DashboardViewModel)
    viewModelOf(::DealDetailViewModel)
    viewModelOf(::NotificationsViewModel)
    viewModelOf(::ConversationsViewModel)
    viewModelOf(::ChatViewModel)
}
