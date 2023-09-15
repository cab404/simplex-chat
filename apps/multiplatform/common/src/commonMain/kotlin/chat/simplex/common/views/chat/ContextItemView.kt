package chat.simplex.common.views.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material.*
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import dev.icerock.moko.resources.compose.painterResource
import dev.icerock.moko.resources.compose.stringResource
import androidx.compose.desktop.ui.tooling.preview.Preview
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import chat.simplex.common.ui.theme.*
import chat.simplex.common.views.chat.item.*
import chat.simplex.common.model.*
import chat.simplex.res.MR
import kotlinx.datetime.Clock

@Composable
fun ContextItemView(
  contextItem: ChatItem,
  contextIcon: Painter,
  cancelContextItem: () -> Unit
) {
  val sent = contextItem.chatDir.sent
  val sentColor = CurrentColors.collectAsState().value.appColors.sentMessage
  val receivedColor = CurrentColors.collectAsState().value.appColors.receivedMessage

  @Composable
  fun msgContentView(lines: Int) {
    MarkdownText(
      contextItem.text, contextItem.formattedText,
      maxLines = lines,
      linkMode = SimplexLinkMode.DESCRIPTION,
      modifier = Modifier.fillMaxWidth(),
    )
  }

  Row(
    Modifier
      .padding(top = 8.dp)
      .background(if (sent) sentColor else receivedColor),
    verticalAlignment = Alignment.CenterVertically
  ) {
    Row(
      Modifier
        .padding(vertical = 12.dp)
        .fillMaxWidth()
        .weight(1F),
      verticalAlignment = Alignment.CenterVertically
    ) {
      Icon(
        contextIcon,
        modifier = Modifier
          .padding(horizontal = 8.dp)
          .height(20.dp)
          .width(20.dp),
        contentDescription = stringResource(MR.strings.icon_descr_context),
        tint = MaterialTheme.colors.secondary,
      )
      val sender = contextItem.memberDisplayName
      if (sender != null) {
        Column(
          horizontalAlignment = Alignment.Start,
          verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
          Text(
            sender,
            style = TextStyle(fontSize = 13.5.sp, color = CurrentColors.value.colors.secondary)
          )
          msgContentView(lines = 2)
        }
      } else {
        msgContentView(lines = 3)
      }
    }
    IconButton(onClick = cancelContextItem) {
      Icon(
        painterResource(MR.images.ic_close),
        contentDescription = stringResource(MR.strings.cancel_verb),
        tint = MaterialTheme.colors.primary,
        modifier = Modifier.padding(10.dp)
      )
    }
  }
}

@Preview
@Composable
fun PreviewContextItemView() {
  SimpleXTheme {
    ContextItemView(
      contextItem = ChatItem.getSampleData(1, CIDirection.DirectRcv(), Clock.System.now(), "hello"),
      contextIcon = painterResource(MR.images.ic_edit_filled)
    ) {}
  }
}
