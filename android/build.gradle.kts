buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Workaround: some plugins (in pub cache) may not declare an Android namespace which
// causes AGP 7+/8+ to fail. Set a default namespace for library subprojects that
// don't declare one so the build can proceed without editing files in the pub cache.
subprojects {
    // Safely configure Android library projects when the Android plugin is applied.
    plugins.withId("com.android.library") {
        try {
            extensions.configure<com.android.build.gradle.LibraryExtension>("android") {
                if (namespace.isNullOrBlank()) {
                    namespace = "com.company.hacklite.${project.name}"
                }
                // Special handling for flutter_inappwebview
                if (project.name.contains("flutter_inappwebview")) {
                    namespace = "com.pichillilorenzo.flutter_inappwebview"
                }
            }
        } catch (e: Exception) {
            // ignore failures—this is a best-effort workaround for plugins missing namespace
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
