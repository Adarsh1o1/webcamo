buildscript {
    repositories {
        google()
        mavenCentral()
        // ✅ Add these lines in Kotlin DSL syntax
        maven(url = "https://www.jitpack.io")
        maven(url = "https://github.com/arthenica/maven-repo/raw/master")
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.2.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.22")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        // ✅ Add these lines in Kotlin DSL syntax
        maven(url = "https://www.jitpack.io")
        maven(url = "https://github.com/arthenica/maven-repo/raw/master")
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
