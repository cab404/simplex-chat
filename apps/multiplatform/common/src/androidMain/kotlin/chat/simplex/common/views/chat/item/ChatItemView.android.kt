package chat.simplex.common.views.chat.item

import android.Manifest
import android.os.Build
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableState
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp
import chat.simplex.common.model.ChatItem
import chat.simplex.common.model.MsgContent
import chat.simplex.common.platform.FileChooserLauncher
import chat.simplex.common.platform.saveImage
import chat.simplex.common.views.helpers.SharedContent
import chat.simplex.common.views.helpers.withApi
import chat.simplex.res.MR
import com.google.accompanist.permissions.rememberPermissionState
import dev.icerock.moko.resources.compose.painterResource
import dev.icerock.moko.resources.compose.stringResource

@Composable
actual fun ReactionIcon(text: String, fontSize: TextUnit) {
  Text(text, fontSize = fontSize)
}

@Composable
actual fun SaveContentItemAction(cItem: ChatItem, saveFileLauncher: FileChooserLauncher, showMenu: MutableState<Boolean>) {
  val writePermissionState = rememberPermissionState(permission = Manifest.permission.WRITE_EXTERNAL_STORAGE)
  ItemAction(stringResource(MR.strings.save_verb), painterResource(if (cItem.file?.fileSource?.cryptoArgs == null) MR.images.ic_download else MR.images.ic_lock_open_right), onClick = {
    when (cItem.content.msgContent) {
      is MsgContent.MCImage -> {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R || writePermissionState.hasPermission) {
          saveImage(cItem.file)
        } else {
          writePermissionState.launchPermissionRequest()
        }
      }
      is MsgContent.MCFile, is MsgContent.MCVoice, is MsgContent.MCVideo -> withApi { saveFileLauncher.launch(cItem.file?.fileName ?: "") }
      else -> {}
    }
    showMenu.value = false
  })
}
