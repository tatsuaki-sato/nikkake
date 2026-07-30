package com.myapplication.common.ui.workout

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Button
import androidx.compose.material.ButtonDefaults
import androidx.compose.material.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import cafe.adriel.voyager.core.screen.Screen
import cafe.adriel.voyager.navigator.LocalNavigator
import cafe.adriel.voyager.navigator.currentOrThrow
import com.myapplication.common.ui.theme.LocalColors

class WorkoutScreen(val routineId: String) : Screen {
    @Composable
    override fun Content() {
        val navigator = LocalNavigator.currentOrThrow
        val colors = LocalColors.current
        var isCompleted by remember { mutableStateOf(false) }

        if (isCompleted) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .background(colors.background)
                    .padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                Text("🎉", fontSize = 72.sp, modifier = Modifier.padding(bottom = 24.dp))
                Text("お疲れ様でした！", fontSize = 28.sp, fontWeight = FontWeight.Bold, color = colors.textPrimary, modifier = Modifier.padding(bottom = 8.dp))
                Text("今日のテストルーティン を完了しました", fontSize = 16.sp, color = colors.textSecondary, modifier = Modifier.padding(bottom = 48.dp))
                
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 48.dp)
                        .background(colors.surfaceElevated, RoundedCornerShape(16.dp))
                        .padding(24.dp),
                    horizontalArrangement = Arrangement.SpaceAround
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("1", fontSize = 32.sp, fontWeight = FontWeight.Bold, color = colors.primaryLight, modifier = Modifier.padding(bottom = 4.dp))
                        Text("種目", fontSize = 14.sp, color = colors.textSecondary)
                    }
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("3", fontSize = 32.sp, fontWeight = FontWeight.Bold, color = colors.primaryLight, modifier = Modifier.padding(bottom = 4.dp))
                        Text("完了セット", fontSize = 14.sp, color = colors.textSecondary)
                    }
                }

                Button(
                    onClick = { navigator.pop() },
                    modifier = Modifier.fillMaxWidth().height(56.dp),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(backgroundColor = colors.primary)
                ) {
                    Text("ホームへ戻る", color = colors.background, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                }
            }
        } else {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .background(colors.background)
                    .padding(top = 50.dp)
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 20.dp, vertical = 20.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("今日のテストルーティン", fontSize = 20.sp, fontWeight = FontWeight.Bold, color = colors.textPrimary)
                    Button(
                        onClick = { isCompleted = true },
                        colors = ButtonDefaults.buttonColors(backgroundColor = colors.primary),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text("完了する", color = colors.background, fontWeight = FontWeight.Bold)
                    }
                }

                Column(modifier = Modifier.padding(horizontal = 20.dp)) {
                    Text("1. スクワット", fontSize = 24.sp, fontWeight = FontWeight.Bold, color = colors.textPrimary, modifier = Modifier.padding(bottom = 24.dp))
                    
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(colors.surface, RoundedCornerShape(12.dp))
                            .border(1.dp, colors.border, RoundedCornerShape(12.dp))
                            .padding(16.dp)
                    ) {
                        Row(modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp)) {
                            Text("Set", modifier = Modifier.weight(1f), color = colors.textSecondary, fontWeight = FontWeight.Bold)
                            Text("kg", modifier = Modifier.weight(1f), color = colors.textSecondary, fontWeight = FontWeight.Bold)
                            Text("Reps", modifier = Modifier.weight(1f), color = colors.textSecondary, fontWeight = FontWeight.Bold)
                            Text("Done", modifier = Modifier.weight(1f), color = colors.textSecondary, fontWeight = FontWeight.Bold)
                        }

                        (1..3).forEach { setNum ->
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(vertical = 12.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text("$setNum", modifier = Modifier.weight(1f), color = colors.textSecondary)
                                Text("-", modifier = Modifier.weight(1f), color = colors.textPrimary, fontSize = 18.sp)
                                Text("10", modifier = Modifier.weight(1f), color = colors.textPrimary, fontSize = 18.sp)
                                Box(
                                    modifier = Modifier
                                        .weight(1f)
                                        .height(32.dp)
                                        .background(colors.background, RoundedCornerShape(16.dp))
                                        .border(1.dp, colors.border, RoundedCornerShape(16.dp)),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text("✓", color = colors.textSecondary)
                                }
                            }
                        }
                    }

                    Row(
                        modifier = Modifier.fillMaxWidth().padding(top = 32.dp),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .padding(end = 8.dp)
                                .background(colors.surfaceElevated, RoundedCornerShape(8.dp))
                                .padding(16.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Text("前の種目", color = colors.textPrimary, fontWeight = FontWeight.Bold)
                        }
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .padding(start = 8.dp)
                                .background(colors.surfaceElevated, RoundedCornerShape(8.dp))
                                .padding(16.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Text("次の種目", color = colors.textPrimary, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
        }
    }
}
