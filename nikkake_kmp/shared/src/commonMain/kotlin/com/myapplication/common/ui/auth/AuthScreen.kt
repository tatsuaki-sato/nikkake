package com.myapplication.common.ui.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import cafe.adriel.voyager.core.screen.Screen
import cafe.adriel.voyager.navigator.LocalNavigator
import cafe.adriel.voyager.navigator.currentOrThrow
import com.myapplication.common.store.AuthStore
import com.myapplication.common.ui.theme.LocalColors
import kotlinx.coroutines.launch

class LoginScreen(private val authStore: AuthStore = AuthStore()) : Screen {
    @Composable
    override fun Content() {
        val navigator = LocalNavigator.currentOrThrow
        val colors = LocalColors.current
        val coroutineScope = rememberCoroutineScope()
        
        var email by remember { mutableStateOf("") }
        var password by remember { mutableStateOf("") }
        
        val errorMsg by authStore.errorMsg.collectAsState()
        val isLoading by authStore.isLoading.collectAsState()

        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(colors.background)
                .padding(24.dp),
            contentAlignment = Alignment.Center
        ) {
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                // Header
                Text(
                    text = "nikkake",
                    fontSize = 42.sp,
                    fontWeight = FontWeight.Bold,
                    color = colors.primaryLight,
                    letterSpacing = 2.sp,
                    modifier = Modifier.padding(bottom = 8.dp)
                )
                Text(
                    text = "毎日の日課を、習慣に。",
                    fontSize = 16.sp,
                    color = colors.textSecondary,
                    modifier = Modifier.padding(bottom = 48.dp)
                )

                // Error Msg
                if (errorMsg.isNotEmpty()) {
                    Text(
                        text = errorMsg,
                        color = colors.error,
                        modifier = Modifier.padding(bottom = 16.dp),
                        textAlign = TextAlign.Center
                    )
                }

                // Email
                Column(modifier = Modifier.fillMaxWidth().padding(bottom = 20.dp)) {
                    Text(
                        text = "メールアドレス",
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Medium,
                        color = colors.textPrimary,
                        modifier = Modifier.padding(bottom = 8.dp)
                    )
                    OutlinedTextField(
                        value = email,
                        onValueChange = { email = it },
                        placeholder = { Text("example@email.com", color = colors.textSecondary) },
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                        colors = TextFieldDefaults.outlinedTextFieldColors(
                            textColor = colors.textPrimary,
                            backgroundColor = colors.surface,
                            focusedBorderColor = colors.border,
                            unfocusedBorderColor = colors.border
                        ),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.fillMaxWidth()
                    )
                }

                // Password
                Column(modifier = Modifier.fillMaxWidth().padding(bottom = 20.dp)) {
                    Text(
                        text = "パスワード",
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Medium,
                        color = colors.textPrimary,
                        modifier = Modifier.padding(bottom = 8.dp)
                    )
                    OutlinedTextField(
                        value = password,
                        onValueChange = { password = it },
                        placeholder = { Text("••••••••", color = colors.textSecondary) },
                        visualTransformation = PasswordVisualTransformation(),
                        colors = TextFieldDefaults.outlinedTextFieldColors(
                            textColor = colors.textPrimary,
                            backgroundColor = colors.surface,
                            focusedBorderColor = colors.border,
                            unfocusedBorderColor = colors.border
                        ),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.fillMaxWidth()
                    )
                }

                // Login Button
                Button(
                    onClick = {
                        coroutineScope.launch {
                            authStore.login(email, password)
                        }
                    },
                    enabled = !isLoading,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 12.dp)
                        .height(56.dp),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(
                        backgroundColor = colors.primary,
                        contentColor = Color.White
                    )
                ) {
                    if (isLoading) {
                        CircularProgressIndicator(color = Color.White)
                    } else {
                        Text("ログイン", fontSize = 16.sp, fontWeight = FontWeight.Bold)
                    }
                }

                // Link to Register
                TextButton(
                    onClick = { 
                        authStore.clearError()
                        navigator.push(RegisterScreen(authStore)) 
                    },
                    modifier = Modifier.padding(top = 24.dp)
                ) {
                    Text(
                        text = "アカウントをお持ちでない方はこちら",
                        color = colors.primaryLight,
                        fontSize = 14.sp
                    )
                }
            }
        }
    }
}

class RegisterScreen(private val authStore: AuthStore = AuthStore()) : Screen {
    @Composable
    override fun Content() {
        val navigator = LocalNavigator.currentOrThrow
        val colors = LocalColors.current
        val coroutineScope = rememberCoroutineScope()
        
        var displayName by remember { mutableStateOf("") }
        var email by remember { mutableStateOf("") }
        var password by remember { mutableStateOf("") }
        var confirmPassword by remember { mutableStateOf("") }
        
        val errorMsg by authStore.errorMsg.collectAsState()
        val isLoading by authStore.isLoading.collectAsState()

        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(colors.background)
                .padding(24.dp),
            contentAlignment = Alignment.Center
        ) {
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                // Title
                Text(
                    text = "アカウント作成",
                    fontSize = 28.sp,
                    fontWeight = FontWeight.Bold,
                    color = colors.textPrimary,
                    modifier = Modifier.padding(bottom = 32.dp),
                    textAlign = TextAlign.Center
                )

                // Error Msg
                if (errorMsg.isNotEmpty()) {
                    Text(
                        text = errorMsg,
                        color = colors.error,
                        modifier = Modifier.padding(bottom = 16.dp),
                        textAlign = TextAlign.Center
                    )
                }

                // Display Name
                Column(modifier = Modifier.fillMaxWidth().padding(bottom = 20.dp)) {
                    Text(
                        text = "表示名",
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Medium,
                        color = colors.textPrimary,
                        modifier = Modifier.padding(bottom = 8.dp)
                    )
                    OutlinedTextField(
                        value = displayName,
                        onValueChange = { displayName = it },
                        placeholder = { Text("ニックネーム", color = colors.textSecondary) },
                        colors = TextFieldDefaults.outlinedTextFieldColors(
                            textColor = colors.textPrimary,
                            backgroundColor = colors.surface,
                            focusedBorderColor = colors.border,
                            unfocusedBorderColor = colors.border
                        ),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.fillMaxWidth()
                    )
                }

                // Email
                Column(modifier = Modifier.fillMaxWidth().padding(bottom = 20.dp)) {
                    Text(
                        text = "メールアドレス",
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Medium,
                        color = colors.textPrimary,
                        modifier = Modifier.padding(bottom = 8.dp)
                    )
                    OutlinedTextField(
                        value = email,
                        onValueChange = { email = it },
                        placeholder = { Text("example@email.com", color = colors.textSecondary) },
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                        colors = TextFieldDefaults.outlinedTextFieldColors(
                            textColor = colors.textPrimary,
                            backgroundColor = colors.surface,
                            focusedBorderColor = colors.border,
                            unfocusedBorderColor = colors.border
                        ),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.fillMaxWidth()
                    )
                }

                // Password
                Column(modifier = Modifier.fillMaxWidth().padding(bottom = 20.dp)) {
                    Text(
                        text = "パスワード (6文字以上)",
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Medium,
                        color = colors.textPrimary,
                        modifier = Modifier.padding(bottom = 8.dp)
                    )
                    OutlinedTextField(
                        value = password,
                        onValueChange = { password = it },
                        placeholder = { Text("••••••••", color = colors.textSecondary) },
                        visualTransformation = PasswordVisualTransformation(),
                        colors = TextFieldDefaults.outlinedTextFieldColors(
                            textColor = colors.textPrimary,
                            backgroundColor = colors.surface,
                            focusedBorderColor = colors.border,
                            unfocusedBorderColor = colors.border
                        ),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.fillMaxWidth()
                    )
                }

                // Confirm Password
                Column(modifier = Modifier.fillMaxWidth().padding(bottom = 20.dp)) {
                    Text(
                        text = "パスワード (確認用)",
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Medium,
                        color = colors.textPrimary,
                        modifier = Modifier.padding(bottom = 8.dp)
                    )
                    OutlinedTextField(
                        value = confirmPassword,
                        onValueChange = { confirmPassword = it },
                        placeholder = { Text("••••••••", color = colors.textSecondary) },
                        visualTransformation = PasswordVisualTransformation(),
                        colors = TextFieldDefaults.outlinedTextFieldColors(
                            textColor = colors.textPrimary,
                            backgroundColor = colors.surface,
                            focusedBorderColor = colors.border,
                            unfocusedBorderColor = colors.border
                        ),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.fillMaxWidth()
                    )
                }

                // Register Button
                Button(
                    onClick = {
                        coroutineScope.launch {
                            authStore.register(displayName, email, password, confirmPassword)
                        }
                    },
                    enabled = !isLoading,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 12.dp)
                        .height(56.dp),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(
                        backgroundColor = colors.primary,
                        contentColor = Color.White
                    )
                ) {
                    if (isLoading) {
                        CircularProgressIndicator(color = Color.White)
                    } else {
                        Text("登録して始める", fontSize = 16.sp, fontWeight = FontWeight.Bold)
                    }
                }

                // Link to Login
                TextButton(
                    onClick = { 
                        authStore.clearError()
                        navigator.pop() 
                    },
                    modifier = Modifier.padding(top = 24.dp)
                ) {
                    Text(
                        text = "既にアカウントをお持ちの方はこちら",
                        color = colors.primaryLight,
                        fontSize = 14.sp
                    )
                }
            }
        }
    }
}
