plugins {
    kotlin("multiplatform")
    id("com.android.library")
    id("org.jetbrains.compose")
    kotlin("plugin.serialization")
}

kotlin {
    androidTarget()

    jvm("desktop")

    listOf(
        iosX64(),
        iosArm64(),
        iosSimulatorArm64()
    ).forEach { iosTarget ->
        iosTarget.binaries.framework {
            baseName = "shared"
            isStatic = true
        }
    }

    sourceSets {
        val commonMain by getting {
            dependencies {
                implementation(compose.runtime)
                implementation(compose.foundation)
                implementation(compose.material)
                @OptIn(org.jetbrains.compose.ExperimentalComposeLibrary::class)
                implementation(compose.components.resources)

                implementation("io.ktor:ktor-client-core:2.3.7")
                implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
                implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.2")
                // 日付計算をプラットフォーム間で揃えるために使う。
                // ストリークや「今日やる予定か」の判定はタイムゾーン依存なので自前実装は避ける。
                implementation("org.jetbrains.kotlinx:kotlinx-datetime:0.5.0")

                // 画面遷移はComposeの状態だけで足りる規模なので、
                // ナビゲーションライブラリは入れていない（ui/AppNavigator.kt を参照）
            }
        }
        val commonTest by getting {
            dependencies {
                implementation(kotlin("test"))
                implementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.7.3")
            }
        }
        val androidMain by getting {
            dependencies {
                api("androidx.activity:activity-compose:1.7.2")
                api("androidx.appcompat:appcompat:1.6.1")
                api("androidx.core:core-ktx:1.10.1")
                implementation("io.ktor:ktor-client-okhttp:2.3.7")
            }
        }
        val androidUnitTest by getting {
            dependencies {
                implementation(kotlin("test"))
            }
        }
        val iosX64Main by getting
        val iosArm64Main by getting
        val iosSimulatorArm64Main by getting
        val iosMain by creating {
            dependsOn(commonMain)
            iosX64Main.dependsOn(this)
            iosArm64Main.dependsOn(this)
            iosSimulatorArm64Main.dependsOn(this)
            dependencies {
                implementation("io.ktor:ktor-client-darwin:2.3.7")
            }
        }
        val desktopMain by getting {
            dependencies {
                implementation(compose.desktop.common)
                // デスクトップ(JVM)向けのKtorエンジン。Android は okhttp、iOS は darwin を使う
                implementation("io.ktor:ktor-client-cio:2.3.7")
            }
        }
        // 契約テスト(packages/contract/domain_cases.json)はファイル読み込みが要るので
        // commonTest ではなく JVM 側に置く。
        // ServerRepository のテストもここに置く。応答を差し替えた MockEngine を使うため
        val desktopTest by getting {
            dependencies {
                implementation(kotlin("test"))
                implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.2")
                implementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.7.3")
                implementation("io.ktor:ktor-client-mock:2.3.7")
            }
        }
    }
}

android {
    compileSdk = (findProperty("android.compileSdk") as String).toInt()
    namespace = "com.myapplication.common"

    sourceSets["main"].manifest.srcFile("src/androidMain/AndroidManifest.xml")
    sourceSets["main"].res.srcDirs("src/androidMain/res")
    sourceSets["main"].resources.srcDirs("src/commonMain/resources")

    defaultConfig {
        minSdk = (findProperty("android.minSdk") as String).toInt()
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlin {
        jvmToolchain(17)
    }
}

// 契約テストは packages/contract/ を読む。
// テストの作業ディレクトリはモジュール直下なので、絶対パスをシステムプロパティで渡す。
tasks.withType<Test>().configureEach {
    systemProperty("nikkake.contractDir", rootProject.projectDir.parentFile.resolve("packages/contract").absolutePath)
}
