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

// TRIK PAMUNGKAS: Memaksa semua plugin (termasuk file_picker) mematuhi SDK 36
subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.property("android") as? com.android.build.gradle.BaseExtension
            android?.let {
                if (it.compileSdkVersion != "android-36") {
                    it.compileSdkVersion("android-36")
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}