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

load("@//kotlin:rules.bzl", "kt_jvm_library")
load("@//tests/analysis:jvm_library_test.bzl", "jvm_library_test")
load("@//tests/analysis:util.bzl", "ONLY_FOR_ANALYSIS_TEST_TAGS")

package(
    default_testonly = True,
    default_visibility = ["@//tests/analysis/jvm_library/friends:__subpackages__"],
)

licenses(["notice"])

jvm_library_test(
    name = "no_kt_exported_friend_trans_package_test",
    expected_friend_jar_names = [],
    target_under_test = ":no_kt_exported_friend_trans_package",
)

kt_jvm_library(
    name = "no_kt_exported_friend_trans_package",
    srcs = ["Input.kt"],
    tags = ONLY_FOR_ANALYSIS_TEST_TAGS,
    deps = [
        # Exports :friend from this package
        "@//tests/analysis/jvm_library/friends/sub:kt_exports_friend",
    ],
)

jvm_library_test(
    name = "has_java_exported_friend_in_package_test",
    expected_friend_jar_names = [
        "libjava_exports_friend-hjar.jar",
        "friend-compile.jar",
    ],
    target_under_test = ":has_java_exported_friend_in_package",
)

kt_jvm_library(
    name = "has_java_exported_friend_in_package",
    srcs = ["Input.kt"],
    tags = ONLY_FOR_ANALYSIS_TEST_TAGS,
    deps = [":java_exports_friend"],
)

java_library(
    name = "java_exports_friend",
    srcs = ["Input.java"],
    tags = ONLY_FOR_ANALYSIS_TEST_TAGS,
    exports = [":friend"],
)

jvm_library_test(
    name = "has_kt_exported_friend_in_package_test",
    expected_friend_jar_names = [
        "kt_exports_friend-compile.jar",
        "friend-compile.jar",
    ],
    target_under_test = ":has_kt_exported_friend_in_package",
)

kt_jvm_library(
    name = "has_kt_exported_friend_in_package",
    srcs = ["Input.kt"],
    tags = ONLY_FOR_ANALYSIS_TEST_TAGS,
    deps = [":kt_exports_friend"],
)

kt_jvm_library(
    name = "kt_exports_friend",
    srcs = ["Input.kt"],
    tags = ONLY_FOR_ANALYSIS_TEST_TAGS,
    exports = [":friend"],
)

jvm_library_test(
    name = "has_direct_friend_in_package_test",
    expected_friend_jar_names = ["friend-compile.jar"],
    target_under_test = ":has_direct_friend_in_package",
)

kt_jvm_library(
    name = "has_direct_friend_in_package",
    srcs = ["Input.kt"],
    tags = ONLY_FOR_ANALYSIS_TEST_TAGS,
    deps = [":friend"],
)

kt_jvm_library(
    name = "friend",
    srcs = ["Input.kt"],
    tags = ONLY_FOR_ANALYSIS_TEST_TAGS,
)
