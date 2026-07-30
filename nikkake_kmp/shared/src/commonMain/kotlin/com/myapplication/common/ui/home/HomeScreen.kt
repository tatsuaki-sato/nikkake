package com.myapplication.common.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import cafe.adriel.voyager.core.screen.Screen
import cafe.adriel.voyager.navigator.LocalNavigator
import cafe.adriel.voyager.navigator.currentOrThrow
import com.myapplication.common.ui.theme.LocalColors
import com.myapplication.common.ui.workout.WorkoutScreen

data class Routine(val id: String, val name: String, val icon: String, val frequencyType: String, val frequencyValue: Int, val color: androidx.compose.ui.graphics.Color)

class HomeScreen : Screen {
    @Composable
    override fun Content() {
        val navigator = LocalNavigator.currentOrThrow
        val colors = LocalColors.current
        
        val todayRoutines = listOf(
            Routine(
                id = "1", 
                name = "今日のテストルーティン", 
                icon = "🔥", 
                frequencyType = "daily", 
                frequencyValue = 1,
                color = colors.primary
            )
        )

        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .background(colors.background)
                .padding(16.dp)
        ) {
            item {
                Column(modifier = Modifier.padding(bottom = 24.dp)) {
                    Text(
                        text = "こんにちは！",
                        fontSize = 28.sp,
                        fontWeight = FontWeight.Bold,
                        color = colors.textPrimary
                    )
                    Text(
                        text = "10月10日 (木)",
                        fontSize = 14.sp,
                        color = colors.textSecondary,
                        modifier = Modifier.padding(top = 4.dp)
                    )
                }
            }

            item {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 32.dp)
                        .background(colors.surfaceElevated, RoundedCornerShape(16.dp))
                        .border(1.dp, colors.border, RoundedCornerShape(16.dp))
                        .padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("🔥", fontSize = 32.sp, modifier = Modifier.padding(end = 16.dp))
                    Column {
                        Text("現在のストリーク", color = colors.textSecondary, fontSize = 12.sp)
                        Text("3 日連続", color = colors.accent, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                    }
                }
            }

            item {
                Text(
                    text = "今日のルーティン",
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold,
                    color = colors.textPrimary,
                    modifier = Modifier.padding(bottom = 16.dp)
                )
            }

            items(todayRoutines) { routine ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 12.dp)
                        .background(colors.surface, RoundedCornerShape(16.dp))
                        .border(1.dp, colors.border, RoundedCornerShape(16.dp))
                        .clickable { navigator.push(WorkoutScreen(routine.id)) }
                        .padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .size(48.dp)
                            .background(routine.color, CircleShape),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(routine.icon, fontSize = 24.sp)
                    }
                    Spacer(Modifier.width(16.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = routine.name,
                            color = colors.textPrimary,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier.padding(bottom = 4.dp)
                        )
                        Text(
                            text = if (routine.frequencyType == "daily") "毎日" else "その他",
                            color = colors.textSecondary,
                            fontSize = 12.sp
                        )
                    }
                    Box(modifier = Modifier.padding(8.dp)) {
                        Text("開始する", color = colors.primary)
                    }
                }
            }
        }
    }
}
