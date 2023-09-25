import org.jetbrains.compose.desktop.application.dsl.TargetFormat
import org.jetbrains.kotlin.util.capitalizeDecapitalize.toLowerCaseAsciiOnly

plugins {
  kotlin("multiplatform")
  id("org.jetbrains.compose")
  id("io.github.tomtzook.gradle-cmake") version "1.2.2"
}

group = "chat.simplex"
version = extra["desktop.version_name"] as String


kotlin {
  jvm {
    jvmToolchain(11)
    withJava()
  }
  sourceSets {
    val jvmMain by getting {
      dependencies {
        implementation(project(":common"))
        implementation(compose.desktop.currentOs)
        implementation("net.java.dev.jna:jna:5.13.0")
      }
    }
    val jvmTest by getting
  }
}

// https://github.com/JetBrains/compose-multiplatform/tree/master/tutorials/Native_distributions_and_local_execution
compose {
  desktop {
    application {
      // For debugging via VisualVM
      val debugJava = false
      if (debugJava) {
        jvmArgs += listOf(
          "-Dcom.sun.management.jmxremote.port=8080",
          "-Dcom.sun.management.jmxremote.ssl=false",
          "-Dcom.sun.management.jmxremote.authenticate=false"
        )
      }
      mainClass = "chat.simplex.desktop.MainKt"
      nativeDistributions {
        // For debugging via VisualVM
        if (debugJava) {
          modules("jdk.zipfs", "jdk.unsupported", "jdk.management.agent")
        } else {
          // 'jdk.unsupported' is for vlcj
          modules("jdk.zipfs", "jdk.unsupported")
        }
        //includeAllModules = true
        outputBaseDir.set(project.file("../release"))
        targetFormats(
          TargetFormat.Deb, TargetFormat.Dmg, TargetFormat.Msi, TargetFormat.Exe
          //, TargetFormat.AppImage // Gradle doesn't sync on Mac with it
        )
        linux {
          iconFile.set(project.file("src/jvmMain/resources/distribute/simplex.png"))
          appCategory = "Messenger"
        }
        windows {
          packageName = "SimpleX"
          iconFile.set(project.file("src/jvmMain/resources/distribute/simplex.ico"))
          console = true
          perUserInstall = true
          dirChooser = true
        }
        macOS {
          packageName = "SimpleX"
          iconFile.set(project.file("src/jvmMain/resources/distribute/simplex.icns"))
          appCategory = "public.app-category.social-networking"
          bundleID = "chat.simplex.app"
          val identity = rootProject.extra["desktop.mac.signing.identity"] as String?
          val keychain = rootProject.extra["desktop.mac.signing.keychain"] as String?
          val appleId = rootProject.extra["desktop.mac.notarization.apple_id"] as String?
          val password = rootProject.extra["desktop.mac.notarization.password"] as String?
          val teamId = rootProject.extra["desktop.mac.notarization.team_id"] as String?
          if (identity != null && keychain != null && appleId != null && password != null) {
            signing {
              sign.set(true)
              this.identity.set(identity)
              this.keychain.set(keychain)
            }
            notarization {
              this.appleID.set(appleId)
              this.password.set(password)
              this.ascProvider.set(teamId)
            }
          }
        }
        val os = System.getProperty("os.name", "generic").toLowerCaseAsciiOnly()
        if (os.contains("mac") || os.contains("win")) {
          packageName = "SimpleX"
        } else {
          packageName = "simplex"
        }
        // Packaging requires to have version like MAJOR.MINOR.PATCH
        var adjustedVersion = rootProject.extra["desktop.version_name"] as String
        adjustedVersion = adjustedVersion.replace(Regex("[^0-9.]"), "")
        if (adjustedVersion.split(".").size != 3) {
          adjustedVersion += ".0"
        }
        version = adjustedVersion
      }
    }
  }
}

val cppPath = "../common/src/commonMain/cpp"
cmake {
  // Run this command to make build for all targets:
  // ./gradlew common:cmakeBuild -PcrossCompile
  if (project.hasProperty("crossCompile")) {
    machines.customMachines.register("linux-amd64") {
      toolchainFile.set(project.file("$cppPath/toolchains/x86_64-linux-gnu-gcc.cmake"))
    }
    /*machines.customMachines.register("linux-aarch64") {
      toolchainFile.set(project.file("$cppPath/toolchains/aarch64-linux-gnu-gcc.cmake"))
    }*/
    machines.customMachines.register("win-amd64") {
      toolchainFile.set(project.file("$cppPath/toolchains/x86_64-windows-mingw32-gcc.cmake"))
    }
    if (machines.host.name == "mac-amd64") {
      machines.customMachines.register("mac-amd64") {
        toolchainFile.set(project.file("$cppPath/toolchains/x86_64-mac-apple-darwin-gcc.cmake"))
      }
    }
    if (machines.host.name == "mac-aarch64") {
      machines.customMachines.register("mac-aarch64") {
        toolchainFile.set(project.file("$cppPath/toolchains/aarch64-mac-apple-darwin-gcc.cmake"))
      }
    }
  }
  val compileMachineTargets = arrayListOf<com.github.tomtzook.gcmake.targets.TargetMachine>(machines.host)
  compileMachineTargets.addAll(machines.customMachines)
  targets {
    val main by creating {
      cmakeLists.set(file("$cppPath/desktop/CMakeLists.txt"))
      targetMachines.addAll(compileMachineTargets.toSet())
    }
  }
}

tasks.named("clean") {
  dependsOn("cmakeClean")
}
tasks.named("compileJava") {
  dependsOn("cmakeBuildAndCopy")
}
afterEvaluate {
  tasks.create("cmakeBuildAndCopy") {
    dependsOn("cmakeBuild")
    val copyDetails = mutableMapOf<String, ArrayList<FileCopyDetails>>()
    copy {
      from("${project(":desktop").buildDir}/cmake/main/linux-amd64", "$cppPath/desktop/libs/linux-x86_64", "$cppPath/desktop/libs/linux-x86_64/deps")
      into("src/jvmMain/resources/libs/linux-x86_64")
      include("*.so*")
      eachFile {
        path = name
      }
      includeEmptyDirs = false
      duplicatesStrategy = DuplicatesStrategy.INCLUDE
    }
    copy {
      val destinationDir = "src/jvmMain/resources/libs/linux-x86_64/vlc"
      from("$cppPath/desktop/libs/linux-x86_64/deps/vlc")
      into(destinationDir)
      includeEmptyDirs = false
      duplicatesStrategy = DuplicatesStrategy.INCLUDE
      copyIfNeeded(destinationDir, copyDetails)
    }
    copy {
      from("${project(":desktop").buildDir}/cmake/main/linux-aarch64", "$cppPath/desktop/libs/linux-aarch64", "$cppPath/desktop/libs/linux-aarch64/deps")
      into("src/jvmMain/resources/libs/linux-aarch64")
      include("*.so*")
      eachFile {
        path = name
      }
      includeEmptyDirs = false
      duplicatesStrategy = DuplicatesStrategy.INCLUDE
    }
    copy {
      val destinationDir = "src/jvmMain/resources/libs/linux-aarch64/vlc"
      from("$cppPath/desktop/libs/linux-aarch64/deps/vlc")
      into(destinationDir)
      includeEmptyDirs = false
      duplicatesStrategy = DuplicatesStrategy.INCLUDE
      copyIfNeeded(destinationDir, copyDetails)
    }
    copy {
      from("${project(":desktop").buildDir}/cmake/main/win-amd64", "$cppPath/desktop/libs/windows-x86_64", "$cppPath/desktop/libs/windows-x86_64/deps")
      into("src/jvmMain/resources/libs/windows-x86_64")
      include("*.dll")
      eachFile {
        path = name
      }
      includeEmptyDirs = false
      duplicatesStrategy = DuplicatesStrategy.INCLUDE
    }
    copy {
      val destinationDir = "src/jvmMain/resources/libs/windows-x86_64/vlc"
      from("$cppPath/desktop/libs/windows-x86_64/deps/vlc")
      into(destinationDir)
      includeEmptyDirs = false
      duplicatesStrategy = DuplicatesStrategy.INCLUDE
      copyIfNeeded(destinationDir, copyDetails)
    }
    copy {
      from("${project(":desktop").buildDir}/cmake/main/mac-x86_64", "$cppPath/desktop/libs/mac-x86_64", "$cppPath/desktop/libs/mac-x86_64/deps")
      into("src/jvmMain/resources/libs/mac-x86_64")
      include("*.dylib")
      eachFile {
        path = name
      }
      includeEmptyDirs = false
      duplicatesStrategy = DuplicatesStrategy.INCLUDE
    }
    copy {
      val destinationDir = "src/jvmMain/resources/libs/mac-x86_64/vlc"
      from("$cppPath/desktop/libs/mac-x86_64/deps/vlc")
      into(destinationDir)
      includeEmptyDirs = false
      duplicatesStrategy = DuplicatesStrategy.INCLUDE
      copyIfNeeded(destinationDir, copyDetails)
    }
    copy {
      from("${project(":desktop").buildDir}/cmake/main/mac-aarch64", "$cppPath/desktop/libs/mac-aarch64", "$cppPath/desktop/libs/mac-aarch64/deps")
      into("src/jvmMain/resources/libs/mac-aarch64")
      include("*.dylib")
      eachFile {
        path = name
      }
      includeEmptyDirs = false
      duplicatesStrategy = DuplicatesStrategy.INCLUDE
    }
    copy {
      val destinationDir = "src/jvmMain/resources/libs/mac-aarch64/vlc"
      from("$cppPath/desktop/libs/mac-aarch64/deps/vlc")
      into(destinationDir)
      includeEmptyDirs = false
      duplicatesStrategy = DuplicatesStrategy.INCLUDE
      copyIfNeeded(destinationDir, copyDetails)
    }
    doLast {
      copyDetails.forEach { (destinationDir, details) ->
        details.forEach { detail ->
          val target = File(projectDir.absolutePath + File.separator + destinationDir + File.separator + detail.path)
          if (target.exists()) {
            target.setLastModified(detail.lastModified)
          }
        }
      }
    }
  }
}

fun CopySpec.copyIfNeeded(destinationDir: String, into: MutableMap<String, ArrayList<FileCopyDetails>>) {
  val details = arrayListOf<FileCopyDetails>()
  eachFile {
    val targetFile = File(destinationDir, path)
    if (file.lastModified() == targetFile.lastModified() && file.length() == targetFile.length()) {
      exclude()
    } else {
      details.add(this)
    }
  }
  into[destinationDir] = details
}
