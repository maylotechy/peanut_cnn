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
}

subprojects {
    if (project.name != "app") {
        val configureAction = Action<Project> {
            if (plugins.hasPlugin("com.android.library")) {
                extensions.configure<com.android.build.gradle.LibraryExtension>("android") {
                    compileSdk = 34
                }
            }
        }
        if (state.executed) {
            configureAction.execute(this)
        } else {
            afterEvaluate(configureAction)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
