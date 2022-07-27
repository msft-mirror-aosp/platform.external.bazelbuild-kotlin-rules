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

_RULE_FAMILY = common.RULE_FAMILY
_PARCELIZE_V2_RUNTIME = "@kotlinc//:parcelize_runtime"

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
        flogger_plugin = None,
        parcelize_plugin_v2 = None,
        compose_plugin = None,
        rule_family = _RULE_FAMILY.UNKNOWN,
        annotation_processor_additional_outputs = [],
        annotation_processor_additional_inputs = [],
        coverage_srcs = []):
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
      exported_plugins: List of exported javac plugins
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
      flogger_plugin: File pointing to Flogger plugin. Optional
      parcelize_plugin_v2: File pointing to Parcelize Plugin. Optional
      compose_plugin: File pointing to Jetpack Compose Plugin. Optional
      rule_family: The family of the rule calling this function. Element of common.RULE_FAMILY.
        May be used to enable/disable some features.
      annotation_processor_additional_outputs: sequence of Files. A list of
        files produced by an annotation processor.
      annotation_processor_additional_inputs: sequence of Files. A list of
        files consumed by an annotation processor.
      coverage_srcs: Files to use as the basis when computing code coverage. These are typically
        handwritten files that were inputs to generated `srcs`. Should be disjoint with `srcs`.

    Returns:
      A struct that carries the following fields: java_info and validations.
    """
    if type(java_toolchain) != "JavaToolchainInfo":
        # Allow passing either a target or a provider until all callers are updated
        java_toolchain = java_toolchain[java_common.JavaToolchainInfo]

    java_infos = []
    use_compose = False
    use_flogger = False
    use_parcelize = False

    friend_jars = depset(transitive = [
        _select_friend_jars(dep)
        for dep in deps
        if _is_eligible_friend(ctx, dep)
    ])

    # Skip deps validation check for any android_library target with no kotlin sources: b/239721906
    has_kt_srcs = any([common.is_kt_src(src) for src in srcs])
    if rule_family != _RULE_FAMILY.ANDROID_LIBRARY or has_kt_srcs:
        kt_traverse_exports.expand_forbidden_deps(deps + runtime_deps + exports)

    java_plugin_infos = [plugin[JavaPluginInfo] for plugin in plugins]

    for dep in deps:
        # Collect JavaInfo providers and info about plugins (JavaPluginData).
        if JavaInfo in dep:
            java_infos.append(dep[JavaInfo])

            use_parcelize = use_parcelize or str(dep.label) == _PARCELIZE_V2_RUNTIME

        else:
            fail("Unexpected dependency (must provide JavaInfo): %s" % dep.label)

    java_infos.extend(kt_toolchain.kotlin_libs)

    # TODO: Create a rule for defining kotlinc plugins
    kt_plugin_configs = []

    if use_flogger:
        if not flogger_runtime or not flogger_plugin:
            fail("Dependency on flogger exists, but flogger_runtime/flogger_plugin not passed")
        java_infos.append(flogger_runtime)
        kt_plugin_configs.append(common.kt_plugin_config(jar = flogger_plugin))

    if use_parcelize:
        if not parcelize_plugin_v2:
            fail("Internal Error: Dependency on %s exists, but parcelize_plugin_v2 not passed" % (_PARCELIZE_V2_RUNTIME))
        kt_plugin_configs.append(common.kt_plugin_config(jar = parcelize_plugin_v2))

    if use_compose:
        if not compose_plugin:
            fail("Dependency on compose exists, but compose_plugin not passed")

        if "-Xuse-old-backend" in kotlincopts:
            fail("Jetpack Compose requires use of Kotlin IR backend but -Xuse-old-backend is set")

        if "1.3" in kotlincopts or "1.4" in kotlincopts:
            fail("Jetpack Compose requires Kotlin language version 1.5+")

        def write_opts_compose_plugin(args):
            args.add("-P", "plugin:androidx.compose.compiler.plugins.kotlin:suppressKotlinVersionCompatibilityCheck=true")

        # Disable compatibility check so we can use newer compatible compiler versions easily
        kt_plugin_configs.append(common.kt_plugin_config(
            jar = compose_plugin,
            write_opts = write_opts_compose_plugin,
        ))

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
        exported_plugins = [e[JavaPluginInfo] for e in exported_plugins],
        # Not all exported targets contain a JavaInfo (e.g. some only have CcInfo)
        exports = r_java_info + [e[JavaInfo] for e in exports if JavaInfo in e],
        kt_plugin_configs = kt_plugin_configs,
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
        plugins = java_plugin_infos,  # List of JavaPluginInfo
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

    if not (JavaInfo in friend):
        fail("Friend eligibility should only ever be checked on targets with JavaInfo: %s" % friend.label)

    if friend.label.package == ctx.label.package:
        # Allow friends on targets in the same package
        return True

    if "javatests/" in ctx.label.package and "java/" in friend.label.package:
        # Allow friends from javatests/ on the parallel java/ package
        rule_root = ctx.label.package.rsplit("javatests/", 1)[1]
        friend_root = friend.label.package.rsplit("java/", 1)[1]
        if rule_root == friend_root:
            return True

    if ("test/java/" in ctx.label.package and "main/java/" in friend.label.package and
        True):
        # Allow friends from test/java on the parallel main/java package
        rule_split = ctx.label.package.rsplit("test/java/", 1)
        friend_split = friend.label.package.rsplit("main/java/", 1)
        rule_base_dir = rule_split[0]
        rule_package_name = rule_split[1]
        friend_base_dir = friend_split[0]
        friend_package_name = friend_split[1]
        if rule_base_dir == friend_base_dir and rule_package_name == friend_package_name:
            return True

    return False

def _select_friend_jars(friend):
    # We can't simply use `JavaInfo.compile_jars` because we only want the JARs directly created by
    # `friend`, and not JARs from its `exports`
    return depset([output.compile_jar for output in friend[JavaInfo].java_outputs if output.compile_jar])
