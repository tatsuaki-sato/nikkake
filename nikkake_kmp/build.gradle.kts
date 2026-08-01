plugins {
    // 各サブプロジェクトのクラスローダで多重ロードされるのを避けるため、
    // ルートでは apply(false) で宣言だけしておく
    kotlin("multiplatform").apply(false)
    kotlin("plugin.serialization").version("1.9.21").apply(false)
    id("com.android.application").apply(false)
    id("com.android.library").apply(false)
    id("org.jetbrains.compose").apply(false)
}
