package com.myapplication

import MainView
import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.appcompat.app.AppCompatActivity
import com.myapplication.common.data.NikkakeStorage

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // ローカル保存にContextが要るので、UIを組む前に用意しておく。
        // これが済んでいれば、サインインの有無に関係なくアプリは完全に動く。
        NikkakeStorage.init(applicationContext)

        setContent {
            MainView()
        }
    }
}
