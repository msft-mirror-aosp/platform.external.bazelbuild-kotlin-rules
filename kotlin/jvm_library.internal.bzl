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

load("@//kotlin:compiler_opt.bzl", "kotlincopts_attrs", "merge_kotlincopts")
load("@//toolchains/kotlin_jvm:kt_jvm_toolchains.bzl", "kt_jvm_toolchains")
load("@bazel_skylib//lib:dicts.bzl", "dicts")
load(":common.bzl", "common")
load(":forbidden_deps.bzl", "kt_forbidden_deps")
load(":jvm_compile.bzl", "compile")
load(":kt_jvm_deps.bzl", "kt_jvm_dep_jdeps")

# TODO: Use this function in all Kotlin rules
def _make_default_info(ctx, direct_files, propagated_attrs):
    # Collect runfiles from deps
    transitive_runfiles = []
    for p in common.collect_providers(DefaultInfo, propagated_attrs):
        transitive_runfiles.append(p.data_runfiles.files)
        transitive_runfiles.append(p.default_runfiles.files)
    runfiles = ctx.runfiles(
        files = direct_files,
        transitive_files = depset(transitive = transitive_runfiles),
        collect_default = True,  # handles data attribute
    )

    return DefaultInfo(
        files = depset(direct_files),
        runfiles = runfiles,
    )

def _jvm_library_impl(ctx):
    kt_jvm_toolchain = kt_jvm_toolchains.get(ctx)

    for target in ctx.attr.runtime_deps:
        if JavaInfo in target:
            pass
        elif CcInfo not in target:
            fail("Unexpected runtime dependency (must provide JavaInfo or CcInfo): " + str(target.label))

    if not ctx.files.srcs and not ctx.files.common_srcs:
        fail("srcs attribute or common_srcs attribute of rule %s must be non empty" % ctx.label)

    compile_result = compile(
        ctx,
        output = ctx.outputs.jar,
        srcs = ctx.files.srcs,
        common_srcs = ctx.files.common_srcs,
        deps = ctx.attr.deps,
        plugins = ctx.attr.plugins,
        exported_plugins = ctx.attr.exported_plugins,
        runtime_deps = ctx.attr.runtime_deps,
        exports = ctx.attr.exports,
        javacopts = ctx.attr.javacopts,
        kotlincopts = merge_kotlincopts(ctx),
        neverlink = False,
        testonly = ctx.attr.testonly,
                android_lint_plugins = [p[JavaInfo] for p in ctx.attr._android_lint_plugins],
        manifest = None,
        merged_manifest = None,
        resource_files = [],
        classpath_resources = ctx.files.resources,
        kt_toolchain = kt_jvm_toolchain,
        java_toolchain = ctx.attr._java_toolchain,
        disable_lint_checks = ctx.attr.disable_lint_checks,
        is_kt_jvm_library = True,
    )

    java_info = compile_result.java_info

    # Collect and validate proguard_specs
    # TODO should also propagate IDL proguard_specs when there's idl_srcs
    transitive_proguard_configs = common.collect_proguard_specs(
        ctx,
        ctx.files.proguard_specs,
        ctx.attr.deps + ctx.attr.exports,
        kt_jvm_toolchain.proguard_whitelister,
    )

    # Create OutputGroupInfo
    output_groups = dict(
        _validation = depset(compile_result.validations),
        _source_jars = depset(
            java_info.source_jars,
            transitive = [java_info.transitive_source_jars],
        ),
        _direct_source_jars = depset(java_info.source_jars),
        _hidden_top_level_INTERNAL_ = depset(
            transitive = [
                info._hidden_top_level_INTERNAL_
                for info in common.collect_providers(
                    OutputGroupInfo,
                    ctx.attr.deps + ctx.attr.exports,
                )
            ] + [transitive_proguard_configs],
        ),
    )

    return [
        java_info,
        ProguardSpecProvider(transitive_proguard_configs),
        _make_default_info(
            ctx,
            [ctx.outputs.jar],
            propagated_attrs = ctx.attr.deps + ctx.attr.runtime_deps + ctx.attr.exports,
        ),
        OutputGroupInfo(**output_groups),
        coverage_common.instrumented_files_info(
            ctx,
            source_attributes = ["srcs", "common_srcs"],
            dependency_attributes = ["data", "deps", "resources", "runtime_deps"],
        ),
    ]

_KT_JVM_LIBRARY_ATTRS = dicts.add(
    kotlincopts_attrs(),
    kt_jvm_toolchains.attrs,
    common_srcs = attr.label_list(
        allow_files = common.KT_FILE_TYPES,
        allow_empty = True,
        doc = """The list of common multi-platform source files that are processed to create
                 the target.""",
    ),
    data = attr.label_list(
        allow_files = True,
    ),
    deps = attr.label_list(
        allow_rules = common.ALLOWED_JVM_RULES,
        providers = [
            # Each provider-set expands on allow_rules
        ],
        aspects = [
            kt_forbidden_deps.aspect,
            kt_jvm_dep_jdeps.aspect,
        ],
        doc = """The list of libraries this library directly depends on at compile-time. For Java
                     and Kotlin libraries listed, the Jars they build as well as the transitive closure
                     of their `deps` and `exports` will be on the compile-time classpath for this rule;
                     also, the transitive closure of their `deps`, `runtime_deps`, and `exports` will be
                     on the runtime classpath (excluding dependencies only depended on as `neverlink`).

                     Note on strict_deps: any Java type explicitly or implicitly referred to in `srcs`
                     must be included here. This is a stronger requirement than what is enforced for
                     `java_library`. Any build failures resulting from this requirement will include the
                     missing dependencies and a command to fix the rule.""",
    ),
    disable_lint_checks = attr.string_list(
        doc = """A list of lint checks to be skipped for this target.""",
    ),
    exported_plugins = attr.label_list(
        providers = [
            [JavaPluginInfo],
        ],
        cfg = "exec",
        doc = """The list of [java_plugin](https://docs.bazel.build/versions/main/be/java.html#java_plugin)s
                    (e.g. annotation processors) to export to libraries that directly depend on this library.
                    The specified list of `java_plugin`s will be applied to any library which directly depends on
                    this library, just as if that library had explicitly declared these labels in
                    [plugins].""",
    ),
    exports = attr.label_list(
        allow_rules = common.ALLOWED_JVM_RULES,
        providers = [
            # Each provider-set expands on allow_rules
        ],
        aspects = [
            kt_forbidden_deps.aspect,
        ],
        doc = """List of libraries treated as if they were part of this library by upstream
                     Java/Kotlin dependencies, see go/be-java#java_library.exports. These libraries
                     are **not** automatically also dependencies of this library.""",
    ),
    javacopts = attr.string_list(
        doc = """Additional flags to pass to javac if used as part of this rule, which is the case
                     if `.java` `srcs` are provided or annotation processors generate sources for this
                     rule.""",
    ),
    plugins = attr.label_list(
        providers = [JavaPluginInfo],
        cfg = "exec",
        doc = """Java annotation processors to run at compile-time. Every `java_plugin` specified in
                     the `plugins` attribute will be run whenever this library is built. A library may
                     also inherit plugins from dependencies that use `exported_plugins`. Resources
                     generated by the plugin will be included in the output Jar.""",
    ),
    proguard_specs = attr.label_list(
        allow_files = True,
        doc = """Proguard specifications to go along with this library.""",
    ),
    resources = attr.label_list(
        allow_files = True,
        doc = """A list of data files to include in the Jar, see
                         go/be#java_library.resources.""",
    ),
    runtime_deps = attr.label_list(
        allow_rules = common.ALLOWED_JVM_RULES,
        providers = [
            # Each provider-set expands on allow_rules
            [CcInfo],  # for JNI / native dependencies
        ],
        aspects = [
            kt_forbidden_deps.aspect,
        ],
        doc = """Runtime-only dependencies.""",
    ),
    srcs = attr.label_list(
        allow_files = common.KT_JVM_FILE_TYPES,
        allow_empty = True,
        doc = """The list of source files that are processed to create the target.
                 To support circular dependencies, this can include `.kt` and `.java` files.""",
    ),
    _android_lint_plugins = attr.label_list(
        providers = [
            [JavaInfo],
        ],
        cfg = "exec",
        doc = """Additional Android Lint checks to run at compile-time.  Checks must use
                     //java/com/google/android/tools/lint/registration to work.""",
    ),
    _java_toolchain = attr.label(
        default = "@bazel_tools//tools/jdk:current_java_toolchain",
    ),
)

kt_jvm_library_helper = rule(
    attrs = _KT_JVM_LIBRARY_ATTRS,
    fragments = ["java"],
    outputs = dict(
        jar = "lib%{name}.jar",
        srcjar = "lib%{name}-src.jar",  # implicit declared output for consistency with java_library
    ),
    provides = [JavaInfo],
    implementation = _jvm_library_impl,
    toolchains = [kt_jvm_toolchains.type],
    doc = """This rule compiles Kotlin (and Java) sources into a Jar file. Most Java-like libraries
             and binaries can depend on this rule, and this rule can in turn depend on Kotlin and
             Java libraries. This rule supports a subset of attributes supported by `java_library`.
             In addition to documentation provided as part of this rule, please also refer to their
             documentation as part of `java_library`.""",
)
