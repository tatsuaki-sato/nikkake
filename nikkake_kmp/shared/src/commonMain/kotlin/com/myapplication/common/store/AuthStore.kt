package com.myapplication.common.store

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.delay

class AuthStore {
    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _errorMsg = MutableStateFlow("")
    val errorMsg: StateFlow<String> = _errorMsg.asStateFlow()

    private val _user = MutableStateFlow<String?>(null)
    val user: StateFlow<String?> = _user.asStateFlow()

    suspend fun login(email: String, password: String) {
        if (email.isEmpty() || password.isEmpty()) {
            _errorMsg.value = "メールアドレスとパスワードを入力してください"
            return
        }
        _isLoading.value = true
        _errorMsg.value = ""
        
        // Mock API call
        delay(500)
        _isLoading.value = false
        // In a real app we'd save session and user here
        _user.value = "mock_user_id"
    }

    suspend fun register(displayName: String, email: String, password: String, confirm: String) {
        if (displayName.isEmpty() || email.isEmpty() || password.isEmpty() || confirm.isEmpty()) {
            _errorMsg.value = "すべての項目を入力してください"
            return
        }
        if (password != confirm) {
            _errorMsg.value = "パスワードが一致しません"
            return
        }
        if (password.length < 6) {
            _errorMsg.value = "パスワードは6文字以上で入力してください"
            return
        }

        _isLoading.value = true
        _errorMsg.value = ""
        
        // Mock API call
        delay(500)
        _isLoading.value = false
        // In a real app we'd save session and user here
        _user.value = "mock_user_id"
    }

    fun clearError() {
        _errorMsg.value = ""
    }
}
