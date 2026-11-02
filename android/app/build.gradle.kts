import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Local signing config (android/key.properties, git-ignored -- see AGENTS.md release rules)
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasKeystore = keystorePropertiesFile.exists()
if (hasKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
} else {
    logger.warn("key.properties missing -- release falls back to debug signing (CI dev build)")
}

android {
    namespace = "com.example.my_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion // 模板原样——NDK 不做任何干预（回退决定见 PITFALLS #23）

    compileOptions {
        // flutter_local_notifications（v10+）要求 core library desugaring
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        // Shizuku UserService 的 IShellService AIDL 接口
        aidl = true
    }

    lint {
        // ShellService 是 Shizuku UserService（反射实例化，含 Context 构造）；
        // Instantiatable 对 app 组件的常规要求不适用（lint 提示的官方豁免法）。
        disable += "Instantiatable"
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.my_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // sentry_flutter 10.x 要求 minSdk ≥ 26（Manifest 合并强制）；测试机均 Android 12+
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // 签名四字段完整性校验：任一缺失则视为无签名（降级 debug，避免 as String 空炸）
    val signingComplete = hasKeystore &&
        listOf("keyAlias", "keyPassword", "storeFile", "storePassword")
            .all { keystoreProperties[it] != null }

    signingConfigs {
        if (signingComplete) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    packaging {
        jniLibs {
            // proot 必须以可执行实体落盘（Android 10+ W^X 只许从
            // nativeLibraryDir 执行）：.so 解压到 lib 目录，不用
            // extractNativeLibs=false 的 APK 直载模式。
            useLegacyPackaging = true
        }
    }

    buildTypes {
        release {
            // 有完整签名（key.properties 四字段齐）时用 release 签名；否则降级 debug
            signingConfig = if (signingComplete) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // R8 混淆规则（flutter_p2p_connection keep 等，见 proguard-rules.pro）
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // flutter_local_notifications（v10+）要求 core library desugaring（README 指定版本）
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Shizuku UserService（DSHA 契约：standard 13.1.5）
    implementation("dev.rikka.shizuku:api:13.1.5")
    implementation("dev.rikka.shizuku:provider:13.1.5")
}
