package com.myapplication.common.ui.routine

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.ExtendedFloatingActionButton
import androidx.compose.material.Icon
import androidx.compose.material.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import cafe.adriel.voyager.core.screen.Screen
import cafe.adriel.voyager.navigator.LocalNavigator
import cafe.adriel.voyager.navigator.currentOrThrow
import com.myapplication.common.domain.Routine
import com.myapplication.common.store.AppStores
import com.myapplication.common.ui.theme.LocalColors

class RoutineListScreen : Screen {
    @Composable
    override fun Content() {
        val navigator = LocalNavigator.currentOrThrow
        val colors = LocalColors.current
        val routines by AppStores.routineStore.routines.collectAsState()

        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(colors.background)
        ) {
            if (routines.isEmpty()) {
                Column(
                    modifier = Modifier.fillMaxSize().padding(32.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    Text(text = "📋", fontSize = 64.sp, modifier = Modifier.padding(bottom = 16.dp))
                    Text(
                        text = "ルーティンがありません",
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Bold,
                        color = colors.textPrimary,
                        modifier = Modifier.padding(bottom = 8.dp)
                    )
                    Text(
                        text = "右下のボタンから新しいルーティンを作成しましょう。",
                        color = colors.textSecondary,
                        fontSize = 14.sp
                    )
                }
            } else {
                LazyColumn(
                    contentPadding = PaddingValues(16.dp),
                    modifier = Modifier.fillMaxSize()
                ) {
                    items(routines) { item ->
                        RoutineCard(item, onEdit = {
                            // Edit navigation would go here
                        })
                    }
                }
            }

            ExtendedFloatingActionButton(
                text = { Text("新しく作る", color = Color.White) },
                icon = { Icon(Icons.Default.Add, contentDescription = "Add", tint = Color.White) },
                onClick = { navigator.push(RoutineCreateScreen()) },
                backgroundColor = colors.primary,
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .padding(24.dp)
            )
        }
    }
}

@Composable
fun RoutineCard(item: Routine, onEdit: () -> Unit) {
    val colors = LocalColors.current
    val alpha = if (item.isActive) 1f else 0.5f

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 12.dp)
            .alpha(alpha)
            .border(1.dp, colors.border, RoundedCornerShape(16.dp))
            .background(colors.surface, RoundedCornerShape(16.dp))
            .clickable { onEdit() }
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        val bgColor = try {
            Color(item.color.replace("#", "FF").toLong(16))
        } catch (e: Exception) {
            colors.surfaceElevated
        }

        Box(
            modifier = Modifier
                .size(48.dp)
                .clip(CircleShape)
                .background(bgColor),
            contentAlignment = Alignment.Center
        ) {
            Text(text = item.icon, fontSize = 24.sp)
        }

        Spacer(modifier = Modifier.width(16.dp))

        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = item.name,
                color = colors.textPrimary,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(bottom = 4.dp)
            )
            val frequencyText = when (item.frequencyType) {
                "daily" -> "毎日"
                "every_n_days" -> "${item.frequencyValue}日ごと"
                else -> "曜日指定"
            }
            Text(
                text = frequencyText,
                color = colors.textSecondary,
                fontSize = 12.sp
            )
        }

        Box(modifier = Modifier.padding(8.dp)) {
            Text(text = "✏️", fontSize = 16.sp)
        }
    }
}
