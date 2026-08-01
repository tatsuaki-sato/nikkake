import androidx.compose.ui.window.ComposeUIViewController
import com.myapplication.common.App

/** iOS側のエントリ。SwiftからこのViewControllerを表示する */
fun MainViewController() = ComposeUIViewController { App() }
