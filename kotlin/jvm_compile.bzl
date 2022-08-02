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

"""Compile method that can compile kotlin or java sources"""

load(":common.bzl", "common")
load(":traverse_exports.bzl", "kt_traverse_exports")
load(":compiler_plugin.bzl", "KtCompilerPluginInfo")

_RULE_FAMILY = common.RULE_FAMILY

def kt_jvm_compile(
        ctx,
        output,
        srcs,
        common_srcs,
        deps,
        plugins,
        runtime_deps,
        exports,
        javacopts,
        kotlincopts,
        neverlink,
        testonly,
        android_lint_plugins,
        resource_files,
        exported_plugins,
        manifest = None,
        merged_manifest = None,
        classpath_resources = [],
        kt_toolchain = None,
        java_toolchain = None,
        android_lint_rules_jars = depset(),
        disable_lint_checks = [],
        r_java = None,
        output_srcjar = None,
        flogger_runtime = None,
        rule_family = _RULE_FAMILY.UNKNOWN,
        annotation_processor_additional_outputs = [],
        annotation_processor_additional_inputs = [],
        coverage_srcs = [],
        **_kwargs):
    """
    The Kotlin JVM Compile method.

    Args:
      ctx: The context.
      output: A File. The output jar.
      srcs: List of Files. The Kotlin and Java sources.
      common_srcs: List of common source files.
      deps: List of targets. A list of dependencies.
      plugins: List of targets. A list of jvm plugins.
      runtime_deps: List of targets. A list of runtime deps.
      exports: List of targets. A list of exports.
      javacopts: List of strings. A list of Java compile options.
      kotlincopts: List of strings. A list of Kotlin compile options.
      neverlink: A bool. Signifies whether the target is only used for compile-time.
      testonly: A bool. Signifies whether the target is only used for testing only.
      android_lint_plugins: List of targets. An list of android lint plugins to
        execute as a part of linting.
      resource_files: List of Files. The list of Android Resource files.
      exported_plugins: List of exported javac/kotlinc plugins
      manifest: A File. The raw Android manifest. Optional.
      merged_manifest: A File. The merged Android manifest. Optional.
      classpath_resources: List of Files. The list of classpath resources (kt_jvm_library only).
      kt_toolchain: The Kotlin toolchain.
      java_toolchain: The Java toolchain.
      android_lint_rules_jars: Depset of Files. Standalone Android Lint rule Jar artifacts.
      disable_lint_checks: Whether to disable link checks.
        NOTE: This field should only be used when the provider is not produced
        by a target. For example, the JavaInfo created for the Android R.java
        within an android_library rule.
      r_java: A JavaInfo provider. The JavaInfo provider for the Android R.java
        which is both depended on and propagated as an export.
        NOTE: This field accepts a JavaInfo, but should only be used for the
        Android R.java within an android_library rule.
      output_srcjar: Target output file for generated source jar. Default filename used if None.
      flogger_runtime: JavaInfo, Flogger runtime. Optional
      rule_family: The family of the rule calling this function. Element of common.RULE_FAMILY.
        May be used to enable/disable some features.
      annotation_processor_additional_outputs: sequence of Files. A list of
        files produced by an annotation processor.
      annotation_processor_additional_inputs: sequence of Files. A list of
        files consumed by an annotation processor.
      coverage_srcs: Files to use as the basis when computing code coverage. These are typically
        handwritten files that were inputs to generated `srcs`. Should be disjoint with `srcs`.
      **_kwargs: Unused kwargs so that parameters are easy to add and remove.

    Returns:
      A struct that carries the following fields: java_info and validations.
    """
    if type(java_toolchain) != "JavaToolchainInfo":
        # Allow passing either a target or a provider until all callers are updated
        java_toolchain = java_toolchain[java_common.JavaToolchainInfo]

    java_infos = []
    use_flogger = False

    friend_jars = depset(transitive = [
        _select_friend_jars(dep)
        for dep in deps
        if _is_eligible_friend(ctx, dep)
    ])

    # Skip deps validation check for any android_library target with no kotlin sources: b/239721906
    has_kt_srcs = any([common.is_kt_src(src) for src in srcs])
    if rule_family != _RULE_FAMILY.ANDROID_LIBRARY or has_kt_srcs:
        kt_traverse_exports.expand_forbidden_deps(deps + runtime_deps + exports)

    for dep in deps:
        # Collect JavaInfo providers and info about plugins (JavaPluginData).
        if JavaInfo in dep:
            java_infos.append(dep[JavaInfo])

        else:
            fail("Unexpected dependency (must provide JavaInfo): %s" % dep.label)

    java_infos.extend(kt_toolchain.kotlin_libs)

    # TODO: Inject the runtime library from the flogger API target
    if use_flogger:
        if not flogger_runtime:
            fail("Dependency on flogger exists, but flogger_runtime not passed")
        java_infos.append(flogger_runtime)

    if kotlincopts != None and "-Werror" in kotlincopts:
        fail("Flag -Werror is not permitted")

    if classpath_resources and rule_family != _RULE_FAMILY.JVM_LIBRARY:
        fail("resources attribute only allowed for jvm libraries")

    # The r_java field only support Android resources Jar files. For now, verify
    # that the name of the jar matches "_resources.jar". This check does not to
    # prevent malicious use, the intent is to prevent accidental usage.
    r_java_info = []
    if r_java:
        for jar in r_java.outputs.jars:
            if not jar.class_jar.path.endswith("_resources.jar"):
                fail("Error, illegal dependency provided for r_java. This " +
                     "only supports Android resource Jar files, " +
                     "'*_resources.jar'.")
        r_java_info.append(r_java)

    return common.kt_jvm_library(
        ctx,
        android_lint_plugins = android_lint_plugins,  # List of JavaInfo
        android_lint_rules_jars = android_lint_rules_jars,
        classpath_resources = classpath_resources,
        common_srcs = common_srcs,
        coverage_srcs = coverage_srcs,
                deps = r_java_info + java_infos,
        disable_lint_checks = disable_lint_checks,
        exported_plugins = [e[JavaPluginInfo] for e in exported_plugins if (JavaPluginInfo in e)],
        # Not all exported targets contain a JavaInfo (e.g. some only have CcInfo)
        exports = r_java_info + [e[JavaInfo] for e in exports if JavaInfo in e],
        friend_jars = friend_jars,
        java_toolchain = java_toolchain,
        javacopts = javacopts,
        kotlincopts = kotlincopts,
        compile_jdeps = kt_traverse_exports.expand_direct_jdeps(deps),
        kt_toolchain = kt_toolchain,
        manifest = manifest,
        merged_manifest = merged_manifest,
        native_libraries = [p[CcInfo] for p in deps + runtime_deps + exports if CcInfo in p],
        neverlink = neverlink,
        output = output,
        output_srcjar = output_srcjar,
        plugins = common.kt_plugins_map(
            java_plugin_infos = [plugin[JavaPluginInfo] for plugin in plugins if (JavaPluginInfo in plugin)],
            kt_compiler_plugin_infos = kt_traverse_exports.expand_compiler_plugins(deps).to_list() + [
                plugin[KtCompilerPluginInfo]
                for plugin in plugins
                if (KtCompilerPluginInfo in plugin)
            ],
        ),
        resource_files = resource_files,
        runtime_deps = [d[JavaInfo] for d in runtime_deps if JavaInfo in d],
        srcs = srcs,
        testonly = testonly,
        rule_family = rule_family,
        annotation_processor_additional_outputs = annotation_processor_additional_outputs,
        annotation_processor_additional_inputs = annotation_processor_additional_inputs,
    )

# TODO Delete this
compile = kt_jvm_compile

def _is_eligible_friend(ctx, friend):
    """
    Determines if `ctx` is allowed to call `friend` a friend (and use its `internal` members).

    To be eligibile, `ctx` must be one of:
      - in the parallel `java/` package from a `javatests/` package
      - in the parallel `main/java` package from a `test/java` package
      - another target in the same `BUILD` file

    Args:
      ctx: (ctx) The current target
      friend: (Target) A potential friend of `ctx`
    """

    ctx_pkg = ctx.label.package + "/"
    friend_pkg = friend.label.package + "/"

    if not (JavaInfo in friend):
        fail("Friend eligibility should only ever be checked on targets with JavaInfo: %s" % friend.label)

    if ctx_pkg == friend_pkg:
        # Allow friends on targets in the same package
        return True

    if "javatests/" in ctx_pkg and "java/" in friend_pkg:
        # Allow friends from javatests/ on the parallel java/ package
        ctx_root = ctx_pkg.rsplit("javatests/", 1)[1]
        friend_root = friend_pkg.rsplit("java/", 1)[1]
        if ctx_root == friend_root:
            return True

    if ("test/java/" in ctx_pkg and "main/java/" in friend_pkg and
        True):
        # Allow friends from test/java/ on the parallel main/java/ package
        ctx_split = ctx_pkg.rsplit("test/java/", 1)
        friend_split = friend_pkg.rsplit("main/java/", 1)
        if ctx_split == friend_split:
            return True

    return False

def _select_friend_jars(friend):
    # We can't simply use `JavaInfo.compile_jars` because we only want the JARs directly created by
    # `friend`, and not JARs from its `exports`
    return depset([output.compile_jar for output in friend[JavaInfo].java_outputs if output.compile_jar])
