package com.myapplication.common.ui.routine

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.Button
import androidx.compose.material.ButtonDefaults
import androidx.compose.material.Text
import androidx.compose.material.TextField
import androidx.compose.material.TextFieldDefaults
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
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
import kotlin.random.Random

val ROUTINE_ICONS = listOf("🏋️", "🏃", "🧘", "🏊", "🚴")

class RoutineCreateScreen : Screen {
    @Composable
    override fun Content() {
        val navigator = LocalNavigator.currentOrThrow
        val colors = LocalColors.current
        
        var name by remember { mutableStateOf("") }
        var icon by remember { mutableStateOf(ROUTINE_ICONS[0]) }

        val scrollState = rememberScrollState()

        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(colors.background)
                .verticalScroll(scrollState)
                .padding(16.dp)
        ) {
            // Section: Name
            Text(
                text = "ルーティン名",
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                color = colors.textPrimary,
                modifier = Modifier.padding(bottom = 8.dp)
            )
            TextField(
                value = name,
                onValueChange = { name = it },
                placeholder = { Text("例: 上半身トレーニング", color = colors.textSecondary) },
                colors = TextFieldDefaults.textFieldColors(
                    backgroundColor = colors.surface,
                    textColor = colors.textPrimary,
                    focusedIndicatorColor = Color.Transparent,
                    unfocusedIndicatorColor = Color.Transparent
                ),
                shape = RoundedCornerShape(8.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .border(1.dp, colors.border, RoundedCornerShape(8.dp))
                    .padding(bottom = 24.dp)
            )

            // Section: Icon
            Text(
                text = "アイコン",
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                color = colors.textPrimary,
                modifier = Modifier.padding(bottom = 8.dp)
            )
            LazyRow(
                modifier = Modifier.fillMaxWidth().padding(bottom = 24.dp)
            ) {
                items(ROUTINE_ICONS) { i ->
                    val isSelected = icon == i
                    val borderColor = if (isSelected) colors.primary else Color.Transparent
                    val borderWidth = if (isSelected) 2.dp else 0.dp
                    Box(
                        modifier = Modifier
                            .padding(end = 12.dp)
                            .size(48.dp)
                            .clip(CircleShape)
                            .background(colors.surfaceElevated)
                            .border(borderWidth, borderColor, CircleShape)
                            .clickable { icon = i },
                        contentAlignment = Alignment.Center
                    ) {
                        Text(text = i, fontSize = 24.sp)
                    }
                }
            }

            // Save button
            Button(
                onClick = {
                    if (name.isNotBlank()) {
                        AppStores.routineStore.addRoutine(
                            Routine(
                                id = Random.nextInt().toString(),
                                name = name,
                                icon = icon,
                                color = "#FF0000",
                                frequencyType = "daily",
                                frequencyValue = 1,
                                isActive = true
                            )
                        )
                        navigator.pop()
                    }
                },
                colors = ButtonDefaults.buttonColors(backgroundColor = colors.primary),
                shape = RoundedCornerShape(8.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp)
            ) {
                Text(
                    text = "作成する",
                    color = Color.White,
                    fontWeight = FontWeight.Bold,
                    fontSize = 16.sp
                )
            }
            
            Spacer(modifier = Modifier.height(40.dp))
        }
    }
}
