val localNdk = file("../.tooling/android-sdk/ndk/28.2.13676358")
if (localNdk.isDirectory) {
    subprojects {
        extensions.extraProperties.set("flutter.installedNdkVersions", "28.2.13676358")
        pluginManager.withPlugin("com.android.library") {
            val android = extensions.getByName("android")
            android.javaClass.getMethod("setNdkPath", String::class.java)
                .invoke(android, localNdk.absolutePath)
            android.javaClass.getMethod("setNdkVersion", String::class.java)
                .invoke(android, "28.2.13676358")
        }
    }
}
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
