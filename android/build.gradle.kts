allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Emulate legacy jcenter() method on RepositoryHandler for legacy Flutter plugins
try {
    val metaClass = groovy.lang.GroovySystem.getMetaClassRegistry()
        .getMetaClass(org.gradle.api.artifacts.dsl.RepositoryHandler::class.java)
    if (metaClass is groovy.lang.ExpandoMetaClass) {
        metaClass.registerInstanceMethod("jcenter", object : groovy.lang.Closure<Any>(this) {
            fun doCall(): Any {
                val handler = delegate as org.gradle.api.artifacts.dsl.RepositoryHandler
                return handler.mavenCentral()
            }
        })
    }
} catch (_: Throwable) {}

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
