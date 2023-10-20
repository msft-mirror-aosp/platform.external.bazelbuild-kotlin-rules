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

load("//kotlin/common/testing:testing_rules.bzl", "kt_testing_rules")
load("//kotlin/jvm/testing:for_analysis.bzl", ktfa = "kt_for_analysis")

package(
    default_applicable_licenses = ["//:license"],
    default_testonly = True,
)

licenses(["notice"])

kt_testing_rules.assert_failure_test(
    name = "xpkg_srcs_java_only_test",
    msg_contains = "in its package",
    target_under_test = ktfa.kt_jvm_library(
        name = "xpkg_srcs_java_only",
        srcs = ["//tests/jvm/analysis/jvm_library/srcs_pkg/sub:Input.java"],
    ),
)

kt_testing_rules.assert_failure_test(
    name = "xpkg_srcs_kt_only_test",
    msg_contains = "in its package",
    target_under_test = ktfa.kt_jvm_library(
        name = "xpkg_srcs_kt_only",
        srcs = ["//tests/jvm/analysis/jvm_library/srcs_pkg/sub:Input.kt"],
    ),
)

kt_testing_rules.assert_failure_test(
    name = "xpkg_srcs_kt_and_java_test",
    msg_contains = "in its package",
    target_under_test = ktfa.kt_jvm_library(
        name = "xpkg_srcs_kt_and_java",
        srcs = [
            "//tests/jvm/analysis/jvm_library/srcs_pkg/sub:Input.java",
            "//tests/jvm/analysis/jvm_library/srcs_pkg/sub:Input.kt",
        ],
    ),
)

kt_testing_rules.assert_failure_test(
    name = "xpkg_common_srcs_kt_only_test",
    msg_contains = "in its package",
    target_under_test = ktfa.kt_jvm_library(
        name = "xpkg_common_srcs_kt_only",
        srcs = ["//tests/jvm/analysis/jvm_library/srcs_pkg/sub:Input.kt"],
    ),
)
