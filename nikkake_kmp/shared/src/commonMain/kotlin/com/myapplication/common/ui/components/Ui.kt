package com.myapplication.common.ui.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.AlertDialog
import androidx.compose.material.Button
import androidx.compose.material.ButtonDefaults
import androidx.compose.material.CircularProgressIndicator
import androidx.compose.material.Text
import androidx.compose.material.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.myapplication.common.ui.theme.LocalPalette
import com.myapplication.common.ui.theme.Radii
import com.myapplication.common.ui.theme.Spacing

/**
 * 画面をまたいで使う小さな部品。
 * testTag ではなく contentDescription を使っているのは、
 * Compose UI Test と実際のアクセシビリティの両方で同じ識別子が効くため。
 */

fun Modifier.tag(id: String): Modifier = semantics { contentDescription = id }

@Composable
fun AppCard(
    modifier: Modifier = Modifier,
    color: Color? = null,
    padding: PaddingValues = PaddingValues(Spacing.md),
    content: @Composable () -> Unit,
) {
    val palette = LocalPalette.current

    Box(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(Radii.lg))
            .background(color ?: palette.surface)
            .border(1.dp, palette.border, RoundedCornerShape(Radii.lg))
            .padding(padding),
    ) {
        content()
    }
}

@Composable
fun SectionTitle(text: String, modifier: Modifier = Modifier) {
    Text(
        text = text,
        modifier = modifier.padding(bottom = Spacing.md),
        fontSize = 18.sp,
        fontWeight = FontWeight.Bold,
        color = LocalPalette.current.textPrimary,
    )
}

@Composable
fun FieldLabel(text: String) {
    Text(
        text = text,
        modifier = Modifier.padding(bottom = Spacing.sm),
        fontSize = 13.sp,
        fontWeight = FontWeight.SemiBold,
        color = LocalPalette.current.textSecondary,
    )
}

enum class ButtonVariant { PRIMARY, SECONDARY, GHOST, DANGER }

@Composable
fun AppButton(
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    variant: ButtonVariant = ButtonVariant.PRIMARY,
    enabled: Boolean = true,
    loading: Boolean = false,
) {
    val palette = LocalPalette.current

    val background = when (variant) {
        ButtonVariant.PRIMARY -> palette.primary
        ButtonVariant.SECONDARY -> palette.surfaceElevated
        ButtonVariant.GHOST, ButtonVariant.DANGER -> Color.Transparent
    }
    val foreground = when (variant) {
        ButtonVariant.PRIMARY -> Color.White
        ButtonVariant.SECONDARY -> palette.textPrimary
        ButtonVariant.GHOST -> palette.primaryLight
        ButtonVariant.DANGER -> palette.error
    }
    val border = when (variant) {
        ButtonVariant.SECONDARY -> BorderStroke(1.dp, palette.border)
        ButtonVariant.DANGER -> BorderStroke(1.dp, palette.error)
        else -> null
    }

    Button(
        onClick = onClick,
        modifier = modifier.fillMaxWidth().height(48.dp),
        enabled = enabled && !loading,
        elevation = null,
        shape = RoundedCornerShape(Radii.sm),
        border = border,
        colors = ButtonDefaults.buttonColors(
            backgroundColor = background,
            contentColor = foreground,
            disabledBackgroundColor = background.copy(alpha = 0.4f),
            disabledContentColor = foreground.copy(alpha = 0.6f),
        ),
    ) {
        if (loading) {
            CircularProgressIndicator(color = foreground, strokeWidth = 2.dp, modifier = Modifier.height(20.dp))
        } else {
            Text(label, fontWeight = FontWeight.Bold, fontSize = 15.sp)
        }
    }
}

@Composable
fun EmptyState(
    icon: String,
    title: String,
    message: String,
    modifier: Modifier = Modifier,
    action: (@Composable () -> Unit)? = null,
) {
    val palette = LocalPalette.current

    Column(
        modifier = modifier.fillMaxWidth().padding(Spacing.xl),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(icon, fontSize = 56.sp)
        Text(
            title,
            modifier = Modifier.padding(top = Spacing.md, bottom = Spacing.sm),
            fontSize = 18.sp,
            fontWeight = FontWeight.Bold,
            color = palette.textPrimary,
        )
        Text(message, textAlign = TextAlign.Center, color = palette.textSecondary, fontSize = 14.sp)
        if (action != null) {
            Box(Modifier.padding(top = Spacing.lg)) { action() }
        }
    }
}

@Composable
fun ErrorText(message: String?) {
    if (message.isNullOrEmpty()) return

    Text(
        text = message,
        modifier = Modifier.tag("error-message").padding(bottom = Spacing.md),
        color = LocalPalette.current.error,
        fontSize = 14.sp,
    )
}

@Composable
fun SelectableChip(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val palette = LocalPalette.current

    Box(
        modifier = modifier
            .clip(RoundedCornerShape(Radii.pill))
            .background(if (selected) palette.primary else palette.surface)
            .border(
                1.dp,
                if (selected) palette.primary else palette.border,
                RoundedCornerShape(Radii.pill),
            )
            .clickable(onClick = onClick)
            .padding(horizontal = Spacing.md, vertical = Spacing.sm),
    ) {
        Text(
            label,
            color = if (selected) Color.White else palette.textPrimary,
            fontSize = 13.sp,
            fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal,
        )
    }
}

@Composable
fun StatBlock(label: String, value: String, valueTag: String, modifier: Modifier = Modifier) {
    val palette = LocalPalette.current

    Column(modifier = modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Text(label, fontSize = 11.sp, color = palette.textSecondary)
        Text(
            value,
            modifier = Modifier.tag(valueTag).padding(top = Spacing.xs),
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold,
            color = palette.textPrimary,
        )
    }
}

@Composable
fun LabeledRow(label: String, value: String, valueTag: String) {
    val palette = LocalPalette.current

    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = Spacing.sm),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, fontSize = 14.sp, color = palette.textSecondary)
        Text(
            value,
            modifier = Modifier.tag(valueTag),
            fontSize = 15.sp,
            fontWeight = FontWeight.Bold,
            color = palette.textPrimary,
        )
    }
}

/**
 * 削除など取り返しのつかない操作の確認。
 * プラットフォームのネイティブダイアログではなくComposeで描くのは、
 * 3実装で同じ文言・同じ導線にでき、UIテストからも同じ手順で操作できるため。
 */
@Composable
fun ConfirmDialog(
    title: String,
    message: String,
    confirmLabel: String,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
) {
    val palette = LocalPalette.current

    AlertDialog(
        onDismissRequest = onDismiss,
        backgroundColor = palette.surfaceElevated,
        title = { Text(title, color = palette.textPrimary) },
        text = { Text(message, color = palette.textSecondary) },
        confirmButton = {
            TextButton(onClick = onConfirm, modifier = Modifier.tag("confirm-action")) {
                Text(confirmLabel, color = palette.error)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("キャンセル", color = palette.textSecondary)
            }
        },
    )
}
