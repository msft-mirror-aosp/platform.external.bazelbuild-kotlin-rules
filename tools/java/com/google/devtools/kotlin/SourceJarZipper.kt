/*
 * * Copyright 2022 Google LLC. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the License);
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.google.devtools.kotlin

import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.Paths
import java.nio.file.StandardCopyOption
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream
import javax.lang.model.SourceVersion
import kotlin.system.exitProcess
import picocli.CommandLine
import picocli.CommandLine.Command
import picocli.CommandLine.Model.CommandSpec
import picocli.CommandLine.Option
import picocli.CommandLine.ParameterException
import picocli.CommandLine.Parameters
import picocli.CommandLine.Spec

@Command(
  name = "source-jar-zipper",
  subcommands = [Unzip::class, Zip::class],
  description = ["A tool to pack and unpack srcjar files"],
)
class SourceJarZipper : Runnable {
  @Spec private lateinit var spec: CommandSpec
  override fun run() {
    throw ParameterException(spec.commandLine(), "Specify a command: zip or unzip")
  }
}

fun main(args: Array<String>) {
  val exitCode = CommandLine(SourceJarZipper()).execute(*args)
  exitProcess(exitCode)
}

@Command(name = "zip", description = ["Zip source files into a source jar file"])
class Zip : Runnable {

  @Parameters(index = "0", paramLabel = "outputJar", description = ["Output jar"])
  lateinit var outputJar: Path

  @Option(
    names = ["-i", "--ignore_not_allowed_files"],
    description = ["Ignore not .kt, .java or invalid file paths without raising an exception"],
  )
  var ignoreNotAllowedFiles = false

  @Option(
    names = ["--kotlin_srcs"],
    split = ",",
    description = ["Kotlin source files"],
  )
  val kotlinSrcs = mutableListOf<Path>()

  @Option(
    names = ["--common_srcs"],
    split = ",",
    description = ["Common source files"],
  )
  val commonSrcs = mutableListOf<Path>()

  companion object {
    const val PACKAGE_SPACE = "package "
  }

  override fun run() {
    check(kotlinSrcs.isNotEmpty() or commonSrcs.isNotEmpty()) {
      "Expected at least one source file."
    }

    // Validating files and getting paths for resulting .jar in one cycle
    // for each _srcs list
    val sourcePathToKtZipPath = mutableMapOf<Path, Path>()
    val sourcePathToCommonZipPath = mutableMapOf<Path, Path>()
    val errors = mutableListOf<String>()

    fun Path.getPackagePath(): Path {
      this.toFile().bufferedReader().use { stream ->
        while (true) {
          val line = stream.readLine() ?: return this.fileName

          if (line.startsWith(PACKAGE_SPACE)) {
            // Kotlin allows usage of reserved words in package names framing them 
            // with backquote symbol "`"
            val packageName = line.substring(PACKAGE_SPACE.length).trim().replace(";", "").replace("`", "")
            if (!SourceVersion.isName(packageName)) {
              errors.add("${this} contains an invalid package name")
              return this.fileName
            }
            return Paths.get(packageName.replace(".", "/")).resolve(this.fileName)
          }
        }
      }
    }

    fun Path.validateFile(): Boolean {
      when {
        !Files.isRegularFile(this) -> {
          if (!ignoreNotAllowedFiles) errors.add("${this} is not a file")
          return false
        }
        !this.toString().endsWith(".kt") && !this.toString().endsWith(".java") -> {
          if (!ignoreNotAllowedFiles) errors.add("${this} is not a Kotlin file")
          return false
        }
        else -> return true
      }
    }

    for (sourcePath in kotlinSrcs) {
      if (sourcePath.validateFile()) {
        sourcePathToKtZipPath[sourcePath] = sourcePath.getPackagePath()
      }
    }

    for (sourcePath in commonSrcs) {
      if (sourcePath.validateFile()) {
        sourcePathToCommonZipPath[sourcePath] = sourcePath.getPackagePath()
      }
    }

    if (sourcePathToKtZipPath.isEmpty() && sourcePathToCommonZipPath.isEmpty()) {
      errors.add("Expected at least one valid source file .kt or .java")
    }
    check(errors.isEmpty()) { errors.joinToString("\n") }

    fun MutableMap<Path, Path>.writeToStream(
      zipper: ZipOutputStream,
      prefix: String = "",
    ) {
      for ((sourcePath, zipPath) in this) {
        BufferedInputStream(Files.newInputStream(sourcePath)).use { inputStream ->
          val entry = ZipEntry(Paths.get(prefix).resolve(zipPath).toString())
          entry.time = 0
          zipper.putNextEntry(entry)
          inputStream.copyTo(zipper, bufferSize = 1024)
        }
      }
    }

    ZipOutputStream(BufferedOutputStream(Files.newOutputStream(outputJar))).use { zipper ->
      sourcePathToKtZipPath.writeToStream(zipper)
      sourcePathToCommonZipPath.writeToStream(zipper, "common-srcs")
    }
  }
}

@Command(name = "unzip", description = ["Unzip a jar archive into a specified directory"])
class Unzip : Runnable {

  @Parameters(index = "0", paramLabel = "inputJar", description = ["Jar archive to unzip"])
  lateinit var inputJar: Path

  @Parameters(index = "1", paramLabel = "outputDir", description = ["Output directory"])
  lateinit var outputDir: Path

  override fun run() {
    ZipInputStream(Files.newInputStream(inputJar)).use { unzipper ->
      while (true) {
        val zipEntry: ZipEntry? = unzipper.nextEntry
        if (zipEntry == null) return

        val entryName = zipEntry.name
        check(!entryName.contains("./")) { "Cannot unpack srcjar with relative path ${entryName}" }

        if (!entryName.endsWith(".kt") && !entryName.endsWith(".java")) continue

        val entryPath = outputDir.resolve(entryName)
        if (!Files.exists(entryPath.parent)) Files.createDirectories(entryPath.parent)
        Files.copy(unzipper, entryPath, StandardCopyOption.REPLACE_EXISTING)
      }
    }
  }
}
