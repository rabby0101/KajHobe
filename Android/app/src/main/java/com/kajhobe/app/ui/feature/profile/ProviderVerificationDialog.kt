package com.kajhobe.app.ui.feature.profile

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import com.kajhobe.app.data.model.ProviderVerification

/**
 * Provider verification application dialog. Collects NID number + photos, an
 * (optional) certificate set, work-demo links, and a phone, then submits a
 * `pending` request for manual admin approval. Phone is treated as verified when
 * the account already signed up with a phone number.
 */
@Composable
fun ProviderVerificationDialog(
    existing: ProviderVerification?,
    accountPhone: String?,
    submitting: Boolean,
    onDismiss: () -> Unit,
    onSubmit: (
        nidNumber: String,
        nidFront: ByteArray?,
        nidBack: ByteArray?,
        certs: List<ByteArray>,
        demoUrls: List<String>,
        phone: String,
    ) -> Unit,
) {
    val context = LocalContext.current

    var nidNumber by remember { mutableStateOf(existing?.nid_number ?: "") }
    var nidFront by remember { mutableStateOf<ByteArray?>(null) }
    var nidBack by remember { mutableStateOf<ByteArray?>(null) }
    var certs by remember { mutableStateOf<List<ByteArray>>(emptyList()) }
    var demoUrls by remember { mutableStateOf(existing?.demo_video_urls ?: emptyList()) }
    var demoInput by remember { mutableStateOf("") }
    var phone by remember { mutableStateOf(accountPhone ?: existing?.phone ?: "") }
    var phoneError by remember { mutableStateOf(false) }

    fun readBytes(uri: Uri?): ByteArray? =
        uri?.let { runCatching { context.contentResolver.openInputStream(it)?.use { s -> s.readBytes() } }.getOrNull() }

    val pickFront = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { nidFront = readBytes(it) }
    val pickBack = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { nidBack = readBytes(it) }
    val pickCerts = rememberLauncherForActivityResult(ActivityResultContracts.GetMultipleContents()) { uris ->
        certs = uris.mapNotNull { readBytes(it) }
    }

    // Phone is optional contact info now (phone OTP postponed).
    val canSubmit = nidNumber.isNotBlank() && nidFront != null && !submitting

    Dialog(onDismissRequest = onDismiss) {
        Surface(shape = MaterialTheme.shapes.large, color = MaterialTheme.colorScheme.surface) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = 560.dp)
                    .verticalScroll(rememberScrollState())
                    .padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Icon(Icons.Filled.Verified, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                    Text("Become a Verified Provider", style = MaterialTheme.typography.titleMedium)
                }
                Text(
                    "Submit your NID, a phone number, and optionally certificates and work-demo videos. Our team reviews every application manually.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )

                OutlinedTextField(
                    value = nidNumber,
                    onValueChange = { nidNumber = it },
                    label = { Text("NID number") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )

                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                    OutlinedButton(onClick = { pickFront.launch("image/*") }, modifier = Modifier.weight(1f)) {
                        if (nidFront != null) Icon(Icons.Filled.Check, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                        Spacer(Modifier.width(4.dp)); Text("NID front")
                    }
                    OutlinedButton(onClick = { pickBack.launch("image/*") }, modifier = Modifier.weight(1f)) {
                        if (nidBack != null) Icon(Icons.Filled.Check, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                        Spacer(Modifier.width(4.dp)); Text("NID back")
                    }
                }

                OutlinedTextField(
                    value = phone,
                    onValueChange = { phone = it; phoneError = false },
                    label = { Text("Phone (01XXXXXXXXX)") },
                    enabled = accountPhone == null,
                    singleLine = true,
                    isError = phoneError,
                    supportingText = if (phoneError) {
                        { Text("Enter a valid Bangladeshi mobile number (01XXXXXXXXX).") }
                    } else null,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    modifier = Modifier.fillMaxWidth(),
                )
                if (accountPhone != null) {
                    Text("✓ Verified at signup", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
                }

                OutlinedButton(onClick = { pickCerts.launch("image/*") }, modifier = Modifier.fillMaxWidth()) {
                    Text(if (certs.isEmpty()) "Add certificates (optional)" else "${certs.size} certificate(s) selected")
                }

                // Work demos
                Text("Work demos (optional)", style = MaterialTheme.typography.labelMedium)
                demoUrls.forEachIndexed { index, url ->
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(url, style = MaterialTheme.typography.bodySmall, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
                        IconButton(onClick = { demoUrls = demoUrls.filterIndexed { i, _ -> i != index } }) {
                            Icon(Icons.Filled.Close, contentDescription = "Remove", tint = Color.Red)
                        }
                    }
                }
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(
                        value = demoInput,
                        onValueChange = { demoInput = it },
                        label = { Text("https://youtube.com/...") },
                        singleLine = true,
                        modifier = Modifier.weight(1f),
                    )
                    TextButton(onClick = {
                        val t = demoInput.trim()
                        if (t.isNotEmpty()) { demoUrls = demoUrls + t; demoInput = "" }
                    }) { Text("Add") }
                }

                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                    TextButton(onClick = onDismiss, modifier = Modifier.weight(1f)) { Text("Cancel") }
                    Button(
                        onClick = {
                            // Phone is optional, but if provided it must be a valid BD mobile
                            // number (matches the DB CHECK `^01[0-9]{9}$`). Validate up front for
                            // a clear message instead of a raw Postgres constraint error after upload.
                            val trimmed = phone.trim()
                            if (trimmed.isNotEmpty() && !Regex("^01[0-9]{9}$").matches(trimmed)) {
                                phoneError = true
                            } else {
                                onSubmit(nidNumber, nidFront, nidBack, certs, demoUrls, trimmed)
                            }
                        },
                        enabled = canSubmit,
                        modifier = Modifier.weight(1f),
                    ) { Text(if (submitting) "Submitting…" else "Submit") }
                }
            }
        }
    }
}
