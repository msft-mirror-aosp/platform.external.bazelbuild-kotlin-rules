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

"""Kotlin kt_jvm_library rule."""

load("//bazel:stubs.bzl", "register_extension_info")
load("//:visibility.bzl", "RULES_KOTLIN")
load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("//bazel:stubs.bzl", "lint_actions")
load("//bazel:stubs.bzl", "LINT_REGISTRY")
load("//bazel:stubs.bzl", "registry_checks_for_package")
load(":jvm_library.internal.bzl", "kt_jvm_library_helper")

visibility(RULES_KOTLIN)

def kt_jvm_library(
        name,
        srcs = None,
        common_srcs = None,
        data = None,
        exports = None,
        deps = None,
        runtime_deps = None,
        proguard_specs = None,
        plugins = None,
        exported_plugins = None,
        resources = None,
        tags = None,
        javacopts = None,
        custom_kotlincopts = None,
        disable_lint_checks = None,
        transitive_configs = None,
        **kwargs):
    """This rule compiles Kotlin (and Java) sources into a Jar file.

    Most Java-like libraries
    and binaries can depend on this rule, and this rule can in turn depend on Kotlin and
    Java libraries. This rule supports a subset of attributes supported by `java_library`.
    In addition to documentation provided as part of this rule, please also refer to their
    documentation as part of `java_library`.

    Args:
      name: Name of the target.
      srcs: A list of sources to compile.
      common_srcs: A list of common sources to compile for multi-platform projects.
      data: A list of data dependencies.
      exports: A list of targets to export to rules that depend on this one.
      deps: A list of dependencies. NOTE: kt_library targets cannot be added here (yet).
      runtime_deps: Libraries to make available to the final binary or test at runtime only.
      proguard_specs: Proguard specifications to go along with this library.
      plugins: Java annotation processors to run at compile-time.
      exported_plugins: https://bazel.build/reference/be/java#java_plugin rules to export to direct
        dependencies.
      resources: A list of data files to include in the Jar, see
        https://bazel.build/reference/be/java#java_library.resources.
      tags: A list of string tags passed to generated targets.
      testonly: Whether this target is intended only for tests.
      javacopts: Additional flags to pass to javac if used.
      custom_kotlincopts: Additional flags to pass to Kotlin compiler.
      disable_lint_checks: A list of AndroidLint checks to be skipped.
      transitive_configs:  Blaze feature flags (if any) on which this target depends.
      deprecation: Standard attribute, see
        https://bazel.build/reference/be/common-definitions#common.deprecation.
      features: Features enabled.
      **kwargs: Other keyword arguments.
    """
    srcs = srcs or []
    common_srcs = common_srcs or []
    data = data or []
    exports = exports or []
    deps = deps or []
    runtime_deps = runtime_deps or []
    plugins = plugins or []
    exported_plugins = exported_plugins or []
    proguard_specs = proguard_specs or []
    resources = resources or []

    # Helps go/build_cleaner to identify the targets generated by the macro.
    tags = (tags or []) + ["kt_jvm_library"]

    javacopts = javacopts or []
    disable_lint_checks = disable_lint_checks or []

    kt_jvm_library_helper(
        name = name,
        srcs = srcs,
        common_srcs = common_srcs,
        deps = deps,
        exports = exports,
        runtime_deps = runtime_deps,
        plugins = plugins,
        exported_plugins = exported_plugins,
        resources = resources,
        javacopts = javacopts,
        custom_kotlincopts = custom_kotlincopts,
        proguard_specs = proguard_specs,
        data = data,
        disable_lint_checks = disable_lint_checks,
        tags = tags,
        transitive_configs = transitive_configs,
        **dicts.add(
            kwargs,
            {
                # Dictionary necessary to set private attributes.
                "$android_lint_baseline_file": lint_actions.get_android_lint_baseline_file(native.package_name()),
                "$android_lint_plugins": registry_checks_for_package(LINT_REGISTRY, native.package_name()),
            },
        )
    )

register_extension_info(
    extension = kt_jvm_library,
    label_regex_for_dep = "{extension_name}",
)
