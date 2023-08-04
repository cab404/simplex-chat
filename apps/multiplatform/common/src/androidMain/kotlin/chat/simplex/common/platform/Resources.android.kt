package chat.simplex.common.platform

import android.annotation.SuppressLint
import android.app.UiModeManager
import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.text.BidiFormatter
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import chat.simplex.common.model.AppPreferences
import com.russhwolf.settings.Settings
import com.russhwolf.settings.SharedPreferencesSettings
import dev.icerock.moko.resources.StringResource
import dev.icerock.moko.resources.desc.desc

@SuppressLint("DiscouragedApi")
@Composable
actual fun font(name: String, res: String, weight: FontWeight, style: FontStyle): Font {
  val context = LocalContext.current
  val id = context.resources.getIdentifier(res, "font", context.packageName)
  return Font(id, weight, style)
}

actual fun StringResource.localized(): String = desc().toString(context = androidAppContext)

actual fun isInNightMode() =
  (androidAppContext.getSystemService(Context.UI_MODE_SERVICE) as UiModeManager).nightMode == UiModeManager.MODE_NIGHT_YES

private val sharedPreferences: SharedPreferences by lazy { androidAppContext.getSharedPreferences(AppPreferences.SHARED_PREFS_ID, Context.MODE_PRIVATE) }
private val sharedPreferencesThemes: SharedPreferences by lazy { androidAppContext.getSharedPreferences(AppPreferences.SHARED_PREFS_THEMES_ID, Context.MODE_PRIVATE) }

actual val settings: Settings by lazy { SharedPreferencesSettings(sharedPreferences) }
actual val settingsThemes: Settings by lazy { SharedPreferencesSettings(sharedPreferencesThemes) }

actual fun screenOrientation(): ScreenOrientation = when (mainActivity.get()?.resources?.configuration?.orientation) {
  Configuration.ORIENTATION_PORTRAIT -> ScreenOrientation.PORTRAIT
  Configuration.ORIENTATION_LANDSCAPE -> ScreenOrientation.LANDSCAPE
  else -> ScreenOrientation.UNDEFINED
}

@Composable
actual fun screenWidth(): Dp = LocalConfiguration.current.screenWidthDp.dp

actual fun desktopExpandWindowToWidth(width: Dp) {}

actual fun isRtl(text: CharSequence): Boolean = BidiFormatter.getInstance().isRtl(text)
