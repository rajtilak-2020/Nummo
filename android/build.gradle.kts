allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")

    val configureSubproject = {
        val android = project.extensions.findByName("android")
        if (android is com.android.build.gradle.BaseExtension) {
            android.compileSdkVersion(36)
            val targetPlatformProp = (project.findProperty("target-platform") ?: rootProject.findProperty("target-platform")) as? String
            val targetPlatforms = targetPlatformProp?.split(",")
            if (targetPlatforms != null && targetPlatforms.isNotEmpty()) {
                val archMap = mapOf(
                    "android-arm" to "armeabi-v7a",
                    "android-arm64" to "arm64-v8a",
                    "android-x64" to "x86_64",
                    "android-x86" to "x86"
                )
                val targetAbis = targetPlatforms.mapNotNull { archMap[it.trim()] }.toSet()
                if (targetAbis.isNotEmpty()) {
                    android.defaultConfig.ndk.abiFilters.addAll(targetAbis)
                }
            }
        }
    }

    if (project.state.executed) {
        configureSubproject()
    } else {
        project.afterEvaluate {
            configureSubproject()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
