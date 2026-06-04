package com.kajhobe.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import com.kajhobe.app.ui.navigation.RootNavHost
import com.kajhobe.app.ui.theme.KajHobeTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            KajHobeTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    RootNavHost()
                }
            }
        }
    }
}
