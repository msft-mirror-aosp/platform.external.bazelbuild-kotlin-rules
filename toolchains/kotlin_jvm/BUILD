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

"""Kotlin/JVM toolchain."""

load(":kt_jvm_toolchains.bzl", "kt_jvm_toolchains")
load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("@bazel_skylib//rules:common_settings.bzl", "string_flag")

licenses(["notice"])

package(
    default_visibility = ["//:internal"],
)

toolchain_type(name = kt_jvm_toolchains.name)

toolchain(
    name = "kt_jvm_toolchain_linux",
    exec_compatible_with = [
        "@platforms//os:linux",
    ],
    toolchain = ":kt_jvm_toolchain_linux_sts_jdk",
    toolchain_type = kt_jvm_toolchains.type,
    visibility = ["//visibility:public"],
)

# TODO: Remove this once cl/520112558 has made it into an Android rules release
alias(
    name = "kt_jvm_toolchain_impl",
    actual = ":kt_jvm_toolchain_linux_sts_jdk",
    visibility = ["//visibility:public"],
)

kt_jvm_toolchains.declare(
    name = "kt_jvm_toolchain_linux_sts_jdk",
    # TODO: Required due to magic attribute for DexArchiveAspect, remove once that
    # attribute is removed.
    visibility = ["//visibility:public"],
)

toolchain(
    name = "kt_jvm_toolchain_macos",
    exec_compatible_with = [
        "@platforms//os:macos",
    ],
    toolchain = ":kt_jvm_toolchain_no_turbine_darwin_jdk",
    toolchain_type = kt_jvm_toolchains.type,
    visibility = ["//visibility:public"],
)

kt_jvm_toolchains.declare(
    name = "kt_jvm_toolchain_no_turbine_darwin_jdk",
    enable_turbine_direct = False,
)

# Turn on profiling of Kotlin/JVM actions
#
# Matches if the value is a substring of the target label. Empty string matches nothing.
string_flag(
    name = "profiling_filter",
    build_setting_default = "",
    visibility = ["//visibility:private"],
)
