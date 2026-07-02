// ─────────────────────────────────────────────────────────────────────────────
// CLEAN ROUTE: a UI-free `shared` Gradle module holding the domain/data layer.
// Path: shared/build.gradle.kts
//
// Move the Compose-free packages here from composeApp/src/commonMain:
//   core/network, core/storage, core/sync, core/auth, core/format, core/i18n,
//   core/build, core/deeplink, and every features/*/ Repository / Model / Parser /
//   Service / *Storage file. Leave the Compose screens & components in composeApp.
//
// composeApp/build.gradle.kts then adds:  implementation(projects.shared)
// ─────────────────────────────────────────────────────────────────────────────

plugins {
    alias(libs.plugins.kotlinMultiplatform)
    alias(libs.plugins.androidKotlinMultiplatformLibrary)
    alias(libs.plugins.kotlinxSerialization)
    // NO composeMultiplatform / composeCompiler here — this module has no UI.
    // Add SKIE for ergonomic Swift suspend/Flow interop:
    //   alias(libs.plugins.skie)   // co.touchlab.skie  (add to libs.versions.toml)
}

kotlin {
    android {
        namespace = "com.nuvio.app.shared"
        compileSdk {
            version = release(libs.versions.android.compileSdk.get().toInt()) {
                minorApiLevel = libs.versions.android.compileSdkMinor.get().toInt()
            }
        }
        minSdk = libs.versions.android.minSdk.get().toInt()
    }

    val appleTargets = listOf(
        iosArm64(),
        iosSimulatorArm64(),
        tvosArm64(),            // NEW
        tvosSimulatorArm64(),   // NEW
    )

    appleTargets.forEach { target ->
        target.compilations.getByName("main") {
            cinterops {
                create("commoncrypto") {
                    defFile(project.file("src/nativeInterop/cinterop/commoncrypto.def"))
                    compilerOpts("-I${project.projectDir}/src/nativeInterop/cinterop")
                }
            }
            defaultSourceSet.dependencies {
                implementation(libs.ktor.client.darwin)
            }
        }
        target.binaries.framework {
            baseName = "SharedCore"
            isStatic = true
        }
    }

    sourceSets {
        commonMain.dependencies {
            implementation(libs.ktor.client.core)
            implementation(libs.ktor.client.contentNegotiation)   // adjust to catalog names
            implementation(libs.kotlinx.serialization.json)
            implementation(libs.kotlinx.coroutines.core)
            implementation(libs.kotlinx.atomicfu)
            implementation(libs.kermit)
            implementation(libs.supabase.postgrest)
            implementation(libs.supabase.auth)
            implementation(libs.supabase.functions)
            // NO Compose, coil, haze, navigation-compose, material3, lifecycle-compose.
        }
        androidMain.dependencies {
            implementation(libs.ktor.client.android)
        }
        commonTest.dependencies {
            implementation(libs.kotlin.test)
        }
    }
}

// Intermediate Darwin source set lets iOS + tvOS share one set of `actual`s:
//   shared/src/appleMain/kotlin   ← actuals using NSUserDefaults, NSFileManager, etc.
//   shared/src/tvosMain/kotlin    ← only the few tvOS-specific overrides
