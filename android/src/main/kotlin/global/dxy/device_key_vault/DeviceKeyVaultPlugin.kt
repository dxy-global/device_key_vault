package global.dxy.device_key_vault

import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * One secret per app install, behind strong biometrics.
 *
 * The secret is encrypted with an AES-GCM key in the Android KeyStore that
 * requires a biometric match for every use and is invalidated when a
 * biometric is enrolled. Only the ciphertext and IV sit in SharedPreferences;
 * without a match they are useless.
 */
class DeviceKeyVaultPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "device_key_vault")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivity() { activity = null }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "availability" -> result.success(availability())
            "store" -> {
                val secret = call.argument<String>("secret")
                val prompt = call.argument<String>("prompt")
                if (secret == null || prompt == null) {
                    result.error("failed", "store needs secret and prompt", null)
                } else {
                    store(secret, prompt, result)
                }
            }
            "unlock" -> {
                val prompt = call.argument<String>("prompt")
                if (prompt == null) result.error("failed", "unlock needs prompt", null) else unlock(prompt, result)
            }
            "clear" -> {
                clear()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun availability(): Map<String, Any?> =
        when (BiometricManager.from(context).canAuthenticate(BIOMETRIC_STRONG)) {
            BiometricManager.BIOMETRIC_SUCCESS -> mapOf("ready" to true, "kind" to kind(), "reason" to null)
            BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> mapOf("ready" to false, "kind" to null, "reason" to "not_enrolled")
            else -> mapOf("ready" to false, "kind" to null, "reason" to "no_hardware")
        }

    private fun kind(): String {
        val pm = context.packageManager
        val face = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && pm.hasSystemFeature(PackageManager.FEATURE_FACE)
        val finger = pm.hasSystemFeature(PackageManager.FEATURE_FINGERPRINT)
        return when {
            finger && !face -> "fingerprint"
            face && !finger -> "face"
            else -> "other"
        }
    }

    private fun store(secret: String, prompt: String, result: MethodChannel.Result) {
        val host = activity as? FragmentActivity
            ?: return result.error("unavailable", "MainActivity must extend FlutterFragmentActivity", null)
        if (BiometricManager.from(context).canAuthenticate(BIOMETRIC_STRONG) != BiometricManager.BIOMETRIC_SUCCESS) {
            return result.error("unavailable", null, null)
        }
        clear()
        val cipher = try {
            Cipher.getInstance(TRANSFORMATION).apply { init(Cipher.ENCRYPT_MODE, newKey()) }
        } catch (e: Exception) {
            return result.error("failed", e.message, null)
        }
        authenticate(host, prompt, cipher, result) { ready ->
            val ciphertext = ready.doFinal(secret.toByteArray(Charsets.UTF_8))
            prefs().edit()
                .putString(KEY_IV, Base64.encodeToString(ready.iv, Base64.NO_WRAP))
                .putString(KEY_CIPHERTEXT, Base64.encodeToString(ciphertext, Base64.NO_WRAP))
                .apply()
            result.success(null)
        }
    }

    private fun unlock(prompt: String, result: MethodChannel.Result) {
        val host = activity as? FragmentActivity
            ?: return result.error("unavailable", "MainActivity must extend FlutterFragmentActivity", null)
        val iv = prefs().getString(KEY_IV, null)
        val ciphertext = prefs().getString(KEY_CIPHERTEXT, null)
        val key = existingKey()
        if (iv == null || ciphertext == null || key == null) return result.error("not_found", null, null)
        if (BiometricManager.from(context).canAuthenticate(BIOMETRIC_STRONG) == BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED) {
            clear()
            return result.error("invalidated", null, null)
        }
        val cipher = try {
            Cipher.getInstance(TRANSFORMATION).apply {
                init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, Base64.decode(iv, Base64.NO_WRAP)))
            }
        } catch (e: KeyPermanentlyInvalidatedException) {
            clear()
            return result.error("invalidated", null, null)
        } catch (e: Exception) {
            return result.error("failed", e.message, null)
        }
        authenticate(host, prompt, cipher, result) { ready ->
            result.success(String(ready.doFinal(Base64.decode(ciphertext, Base64.NO_WRAP)), Charsets.UTF_8))
        }
    }

    private fun authenticate(
        host: FragmentActivity,
        prompt: String,
        cipher: Cipher,
        result: MethodChannel.Result,
        onReady: (Cipher) -> Unit,
    ) {
        val callback = object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(res: BiometricPrompt.AuthenticationResult) {
                val ready = res.cryptoObject?.cipher ?: return result.error("failed", "no cipher", null)
                try {
                    onReady(ready)
                } catch (e: Exception) {
                    result.error("failed", e.message, null)
                }
            }

            override fun onAuthenticationError(code: Int, message: CharSequence) {
                result.error(codeFor(code), message.toString(), null)
            }
            // onAuthenticationFailed is one non-matching attempt. The prompt
            // stays open for another try, so there is nothing to answer yet.
        }
        val info = BiometricPrompt.PromptInfo.Builder()
            .setTitle(prompt)
            .setNegativeButtonText(host.getString(android.R.string.cancel))
            .setAllowedAuthenticators(BIOMETRIC_STRONG)
            .build()
        BiometricPrompt(host, ContextCompat.getMainExecutor(context), callback)
            .authenticate(info, BiometricPrompt.CryptoObject(cipher))
    }

    private fun codeFor(code: Int): String = when (code) {
        BiometricPrompt.ERROR_USER_CANCELED, BiometricPrompt.ERROR_NEGATIVE_BUTTON, BiometricPrompt.ERROR_CANCELED -> "cancelled"
        BiometricPrompt.ERROR_LOCKOUT, BiometricPrompt.ERROR_LOCKOUT_PERMANENT -> "locked_out"
        BiometricPrompt.ERROR_NO_BIOMETRICS, BiometricPrompt.ERROR_HW_NOT_PRESENT, BiometricPrompt.ERROR_HW_UNAVAILABLE -> "unavailable"
        else -> "failed"
    }

    private fun newKey(): SecretKey {
        val spec = KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setUserAuthenticationRequired(true)
            .setInvalidatedByBiometricEnrollment(true)
            .apply {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
                }
            }
            .build()
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE).run {
            init(spec)
            generateKey()
        }
    }

    private fun existingKey(): SecretKey? =
        KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }.getKey(ALIAS, null) as? SecretKey

    private fun clear() {
        KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }.deleteEntry(ALIAS)
        prefs().edit().clear().apply()
    }

    private fun prefs() = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    companion object {
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val ALIAS = "global.dxy.device_key_vault"
        private const val PREFS = "global.dxy.device_key_vault"
        private const val KEY_IV = "iv"
        private const val KEY_CIPHERTEXT = "ciphertext"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
    }
}
