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

load("//kotlin/jvm/testing:for_analysis.bzl", ktfa = "kt_for_analysis")
load("//kotlin/jvm/testing:jvm_library_analysis_test.bzl", "kt_jvm_library_analysis_test")

package(
    default_applicable_licenses = ["//:license"],
    default_testonly = True,
)

licenses(["notice"])

kt_jvm_library_analysis_test(
    name = "has_plugin_and_only_kt_srcs_test",
    expect_processor_classpath = True,
    expected_exported_processor_classes = [],
    expected_processor_classes = ["java.plugin.class"],
    target_under_test = ktfa.kt_jvm_library(
        name = "has_plugin_and_only_kt_srcs",
        srcs = ["Input.kt"],
        plugins = [":java_plugin_with_processor"],
    ),
)

kt_jvm_library_analysis_test(
    name = "has_plugin_and_only_java_srcs_test",
    expect_processor_classpath = True,
    expected_exported_processor_classes = [],
    expected_processor_classes = ["java.plugin.class"],
    target_under_test = ktfa.kt_jvm_library(
        name = "has_plugin_and_only_java_srcs",
        srcs = ["Input.java"],
        plugins = [":java_plugin_with_processor"],
    ),
)

kt_jvm_library_analysis_test(
    name = "has_plugin_without_processor_test",
    expect_processor_classpath = True,
    expected_exported_processor_classes = [],
    target_under_test = ktfa.kt_jvm_library(
        name = "has_plugin_without_processor",
        srcs = ["Input.java"],
        plugins = [":java_plugin_without_processor"],
    ),
)

kt_jvm_library_analysis_test(
    name = "has_exported_plugin_test",
    expect_processor_classpath = False,
    expected_exported_processor_classes = ["java.plugin.class"],
    expected_processor_classes = [],  # exported plugin should *not* run on expoter itself
    target_under_test = ktfa.kt_jvm_library(
        name = "has_exported_plugin",
        srcs = ["Input.kt"],
        exported_plugins = [":java_plugin_with_processor"],
    ),
)

[
    kt_jvm_library_analysis_test(
        name = "dep_on_" + exporter + "_test",
        expect_processor_classpath = True,
        expected_processor_classes = ["java.plugin.class"],
        target_under_test = ktfa.kt_jvm_library(
            name = "dep_on_" + exporter,
            srcs = ["Input.kt"],
            deps = [exporter],
        ),
    )
    for exporter in [
        "java_library_with_exported_plugin",
        "kt_jvm_library_with_exported_plugin",
    ] + [
        "kt_jvm_library_exporting_java_library_with_exported_plugin",
        "kt_jvm_library_exporting_kt_jvm_library_with_exported_plugin",
    ]
]

[
    kt_jvm_library_analysis_test(
        name = "kt_jvm_library_exporting_" + export + "_test",
        expect_processor_classpath = False,
        expected_exported_processor_classes = ["java.plugin.class"],
        expected_processor_classes = [],
        target_under_test = ktfa.kt_jvm_library(
            name = "kt_jvm_library_exporting_" + export,
            srcs = ["Input.kt"],
            exports = [export],
        ),
    )
    for export in [
        "java_library_with_exported_plugin",
        "kt_jvm_library_with_exported_plugin",
    ]
]

ktfa.java_library(
    name = "java_library_with_exported_plugin",
    srcs = ["Input.java"],
    exported_plugins = [":java_plugin_with_processor"],
)

ktfa.kt_jvm_library(
    name = "kt_jvm_library_with_exported_plugin",
    srcs = ["Input.kt"],
    exported_plugins = [":java_plugin_with_processor"],
)

java_plugin(
    name = "java_plugin_with_processor",
    srcs = ["Input.java"],
    processor_class = "java.plugin.class",
)

java_plugin(
    name = "java_plugin_without_processor",
    srcs = ["Input.java"],
)
