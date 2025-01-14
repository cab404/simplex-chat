package chat.simplex.common.views.usersettings

import android.Manifest
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import chat.simplex.common.model.ServerCfg
import com.google.accompanist.permissions.rememberPermissionState

@Composable
actual fun ScanProtocolServer(onNext: (ServerCfg) -> Unit) {
  val cameraPermissionState = rememberPermissionState(permission = Manifest.permission.CAMERA)
  LaunchedEffect(Unit) {
    cameraPermissionState.launchPermissionRequest()
  }
  ScanProtocolServerLayout(onNext)
}
