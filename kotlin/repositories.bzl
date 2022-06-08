# Copyright 2022 Google LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the License);
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Definitions for handling Bazel repositories used by the Kotlin rules."""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def kotlin_native_repositories():
    """Repositories required for Kotlin/Native."""
    bazel_skylib()

    # macOS toolchain and dependencies
    clang_llvm_darwin_macos()
    kotlin_native_macos()

    # Linux toolchain and dependencies
    clang_llvm_linux_x86_64()
    gcc_toolchain_linux_x86_64()
    kotlin_native_linux_x86_64()

def bazel_skylib():
    http_archive(
        name = "bazel_skylib",
        sha256 = "2ef429f5d7ce7111263289644d233707dba35e39696377ebab8b0bc701f7818e",
        urls = [
            "https://github.com/bazelbuild/bazel-skylib/releases/download/0.8.0/bazel-skylib.0.8.0.tar.gz",
        ],
    )

def clang_llvm_darwin_macos():
    http_archive(
        name = "kotlin_native_clang_llvm_darwin_macos",
        build_file = "@build_bazel_rules_kotlin//build_files:clang_llvm_darwin_macos.BUILD",
        sha256 = "9cd45a5277b5f4e9b0e2c0bf0de39901752cbf729d98e7ed697ea021df0a029a",
        strip_prefix = "clang-llvm-6.0.1-darwin-macos",
        urls = [
            "https://download.jetbrains.com/kotlin/native/clang-llvm-6.0.1-darwin-macos.tar.gz",
        ],
    )

def kotlin_native_macos():
    http_archive(
        name = "kotlin_native_macos",
        build_file = "@build_bazel_rules_kotlin//build_files:kotlin_native_macos.BUILD",
        sha256 = "100920f1a3352846bc5a2990c87cb71f221abf8261251632ad10c6459d962393",
        strip_prefix = "kotlin-native-macos-1.3.50",
        urls = [
            "https://github.com/JetBrains/kotlin/releases/download/v1.3.50/kotlin-native-macos-1.3.50.tar.gz",
        ],
    )

def clang_llvm_linux_x86_64():
    http_archive(
        name = "kotlin_native_clang_llvm_linux_x86_64",
        build_file = "@build_bazel_rules_kotlin//build_files:clang_llvm_linux_x86_64.BUILD",
        sha256 = "99ec34b65231d4b276c42dd64986218cf3ce8e85a0ed517262ca1dbba2f86557",
        strip_prefix = "clang-llvm-6.0.1-linux-x86-64",
        urls = [
            "https://download.jetbrains.com/kotlin/native/clang-llvm-6.0.1-linux-x86-64.tar.gz",
        ],
    )

def gcc_toolchain_linux_x86_64():
    http_archive(
        name = "kotlin_native_gcc_toolchain_linux_x86_64",
        build_file = "@build_bazel_rules_kotlin//build_files:gcc_toolchain_linux_x86_64.BUILD",
        sha256 = "ca25fc933fe45deb142f2672d3773227a65e652ebeb7bc6cc8425f747c5f8912",
        strip_prefix = "target-gcc-toolchain-3-linux-x86-64",
        urls = [
            "https://download.jetbrains.com/kotlin/native/target-gcc-toolchain-3-linux-x86-64.tar.gz",
        ],
    )

def kotlin_native_linux_x86_64():
    http_archive(
        name = "kotlin_native_linux_x86_64",
        build_file = "@build_bazel_rules_kotlin//build_files:kotlin_native_linux_x86_64.BUILD",
        sha256 = "15eb0589aef8dcb435e4cb04ef9a3ad90b8d936118b491618a70912cef742874",
        strip_prefix = "kotlin-native-linux-1.3.50",
        urls = [
            "https://github.com/JetBrains/kotlin/releases/download/v1.3.50/kotlin-native-linux-1.3.50.tar.gz",
        ],
    )
