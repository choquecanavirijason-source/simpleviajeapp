import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// ─── CARGA DE PROPIEDADES (opcional, por si luego firmas release) ────────────
val keystoreProperties = Properties().apply {
    File(rootProject.projectDir, "key.properties").takeIf { it.exists() }?.also {
        load(FileInputStream(it))
    }
}

android {
    namespace = "com.simpleviaje.app"

    compileSdk = 36

    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11

        // ✅ NECESARIO para flutter_local_notifications (y otras libs)
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.simpleviaje.app"

        minSdk = flutter.minSdkVersion

        // Si quieres igualarlo al otro:
        targetSdk = 35
        // Si prefieres lo default de Flutter, usa esto en lugar de 35:
        // targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Solo crea signingConfig release si existe key.properties
        if (keystoreProperties.getProperty("storeFile") != null) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile")!!)
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // ✅ Si existe la firma release, úsala; si no, usa debug (como tu template)
            signingConfigs.findByName("release")?.let {
                signingConfig = it
            } ?: run {
                signingConfig = signingConfigs.getByName("debug")
            }

            // Puedes dejarlo así por ahora
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    // ✅ Core library desugaring (esto es lo que te faltaba)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    // ✅ Firebase BoM (maneja versiones automáticamente)
    implementation(platform("com.google.firebase:firebase-bom:34.8.0"))

    // ✅ Agrega solo lo que vayas a usar (ejemplos comunes)
    implementation("com.google.firebase:firebase-analytics")
    // implementation("com.google.firebase:firebase-auth")
    // implementation("com.google.firebase:firebase-firestore")
    // implementation("com.google.firebase:firebase-messaging")
    // implementation("com.google.firebase:firebase-crashlytics")
}

flutter {
    source = "../.."
}
