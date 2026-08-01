import androidx.compose.runtime.Composable
import com.myapplication.common.App

/**
 * Android側のエントリ。
 * ストレージにContextが必要なので、Application#onCreate で
 * com.myapplication.common.data.NikkakeStorage.init(context) を呼んでおくこと。
 */
@Composable
fun MainView() = App()
