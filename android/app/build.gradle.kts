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
    // NDK 版本：:jni 模块（path_provider 的 native 构建）钉死 Flutter 默认的
    // 28.2（实测换 30.0 直接构建失败）——28.2 不在 CI 镜像预装列表里，
    // 由 workflow 显式安装 + 缓存兜底（PITFALLS #20）。
    ndkVersion = System.getenv("NDK_VERSION") ?: "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.my_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
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

    buildTypes {
        release {
            // 有完整签名（key.properties 四字段齐）时用 release 签名；否则降级 debug
            signingConfig = if (signingComplete) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
