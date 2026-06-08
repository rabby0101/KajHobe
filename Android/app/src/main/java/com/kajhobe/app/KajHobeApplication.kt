package com.kajhobe.app

import android.app.Application
import com.kajhobe.app.di.appModule
import org.koin.android.ext.koin.androidContext
import org.koin.android.ext.koin.androidLogger
import org.koin.core.context.startKoin

/**
 * Application entry point. Initialises Koin (DI).
 * Notification channels (FCM) and the presence lifecycle observer are added in later phases.
 */
class KajHobeApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        startKoin {
            androidLogger()
            androidContext(this@KajHobeApplication)
            modules(appModule)
        }
    }
}
