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

"""Kotlin toolchain."""

# Work around to toolchains in Google3.
KtJvmToolchainInfo = provider()

KT_VERSION = "v1_7_0"

KT_LANG_VERSION = "1.7"

# Only for testing kotlinc updates. Do not use in production.
_ALLOW_PRERELEASE_VERSIONS = False

# Kotlin JVM toolchain type label
_TYPE = Label("@//toolchains/kotlin_jvm:kt_jvm_toolchain_type")

def _common_kotlinc_flags(ctx):
    """Returns kotlinc flags to use in all compilations."""
    args = [
        # We're supplying JDK in bootclasspath explicitly instead
        "-no-jdk",

        # stdlib included in merged_deps
        "-no-stdlib",

        # Emit Java 8 bytecode with parameter names
        "-jvm-target",
        "1.8",
        "-java-parameters",

        # Allow default method declarations, akin to what javac emits (b/110378321).
        "-Xjvm-default=all",

        # Trust JSR305 nullness type qualifier nicknames the same as @Nonnull/@Nullable
        # (see https://kotlinlang.org/docs/reference/java-interop.html#jsr-305-support)
        "-Xjsr305=strict",

        # Trust go/JSpecify nullness annotations
        # (see https://kotlinlang.org/docs/whatsnew1520.html#support-for-jspecify-nullness-annotations)
        "-Xjspecify-annotations=strict",

        # Trust annotations on type arguments, etc.
        # (see https://kotlinlang.org/docs/java-interop.html#annotating-type-arguments-and-type-parameters)
        "-Xtype-enhancement-improvements-strict-mode",

        # TODO: Remove this as the default setting (probably Kotlin 1.7)
        "-Xenhance-type-parameter-types-to-def-not-null=true",

        # Explicitly set language version so we can update compiler separate from language version
        "-language-version",
        ctx.attr.kotlin_language_version,

        # Enable type annotations in the JVM bytecode (b/170647926)
        "-Xemit-jvm-type-annotations",

        # TODO: Temporarily disable 1.5's sam wrapper conversion
        "-Xsam-conversions=class",

        # We don't want people to use experimental APIs, but if they do, we want them to use @OptIn
        "-opt-in=kotlin.RequiresOptIn",
    ]

    if _ALLOW_PRERELEASE_VERSIONS:
        args.append("-Xskip-prerelease-check")

    # --define=extra_kt_jvm_opts is for overriding from command line.
    # (Last wins in repeated --define=foo= use, so use --define=bar= instead.)
    extra_kt_jvm_opts = ctx.var.get("extra_kt_jvm_opts", default = None)
    if extra_kt_jvm_opts:
        args.extend([o for o in extra_kt_jvm_opts.split(" ") if o])
    return args

def _kt_jvm_toolchain_impl(ctx):
    kt_jvm_toolchain = dict(
        build_marker = ctx.file.build_marker,
        genclass = ctx.file.genclass,
        java_runtime = ctx.attr.java_runtime,
        jvm_abi_gen_plugin = ctx.file.jvm_abi_gen_plugin,
        kotlin_annotation_processing = ctx.file.kotlin_annotation_processing,
        kotlin_compiler = ctx.attr.kotlin_compiler[DefaultInfo].files_to_run,
        kotlin_compiler_common_flags = _common_kotlinc_flags(ctx),
        kotlin_language_version = ctx.attr.kotlin_language_version,
        kotlin_libs = [JavaInfo(compile_jar = jar, output_jar = jar) for jar in ctx.files.kotlin_libs],
        kotlin_sdk_libraries = ctx.attr.kotlin_sdk_libraries,
        proguard_whitelister = ctx.attr.proguard_whitelister[DefaultInfo].files_to_run,
        turbine = ctx.file.turbine,
        turbine_direct = ctx.file.turbine_direct if ctx.attr.enable_turbine_direct else None,
        turbine_jsa = ctx.file.turbine_jsa,
        zipper = ctx.executable.zipper,
    )
    return [
        platform_common.ToolchainInfo(**kt_jvm_toolchain),
        KtJvmToolchainInfo(**kt_jvm_toolchain),
    ]

_kt_jvm_toolchain_internal = rule(
    name = "kt_jvm_toolchain",
    attrs = dict(
        build_marker = attr.label(
            default = "@//tools:build_marker",
            allow_single_file = [".jar"],
        ),
        enable_turbine_direct = attr.bool(
            # If disabled, the value of turbine_direct will be ignored.
            # Starlark doesn't allow None to override default-valued attributes:
            default = True,
        ),
        genclass = attr.label(
            default = "@bazel_tools//tools/jdk:GenClass_deploy.jar",
            cfg = "exec",
            allow_single_file = True,
        ),
        java_runtime = attr.label(
            default = "@bazel_tools//tools/jdk:current_java_runtime",
            cfg = "exec",
            allow_files = True,
        ),
        jvm_abi_gen_plugin = attr.label(
            default = "@kotlinc//:jvm_abi_gen_plugin",
            cfg = "exec",
            allow_single_file = [".jar"],
        ),
        kotlin_annotation_processing = attr.label(
            default = "@kotlinc//:kotlin_annotation_processing",
            cfg = "exec",
            allow_single_file = True,
        ),
        kotlin_compiler = attr.label(
            default = "@kotlinc//:kotlin_compiler",
            cfg = "exec",
            executable = True,
        ),
        kotlin_language_version = attr.string(
            default = KT_LANG_VERSION,
        ),
        kotlin_libs = attr.label_list(
            doc = "The libraries required during all Kotlin builds.",
            default = [
                "@kotlinc//:kotlin_stdlib",
                "@kotlinc//:annotations",
            ],
            allow_files = [".jar"],
            cfg = "target",
        ),
        kotlin_sdk_libraries = attr.label_list(
            doc = "The libraries required to resolve Kotlin code in an IDE.",
            default = [
                "@kotlinc//:kotlin_reflect",
                "@kotlinc//:kotlin_stdlib",
                "@kotlinc//:kotlin_stdlib_jdk7",
                "@kotlinc//:kotlin_stdlib_jdk8",
                "@kotlinc//:kotlin_test_not_testonly",
            ],
            cfg = "target",
        ),
        proguard_whitelister = attr.label(
            default = "@bazel_tools//tools/jdk:proguard_whitelister",
            cfg = "exec",
        ),
        runtime = attr.label_list(
            # This attribute has a "magic" name recognized by the native DexArchiveAspect
            # (b/78647825). Must list all implicit runtime deps here, this is not limited
            # to Kotlin runtime libs.
            default = [
                "@kotlinc//:kotlin_stdlib",
                "@kotlinc//:annotations",
            ],
            cfg = "target",
            doc = "The Kotlin runtime libraries grouped into one attribute.",
        ),
        turbine = attr.label(
            default = "@bazel_tools//tools/jdk:turbine_direct",
            cfg = "exec",
            allow_single_file = True,
        ),
        turbine_direct = attr.label(
            executable = True,
            cfg = "exec",
            allow_single_file = True,
        ),
        turbine_jsa = attr.label(
            cfg = "exec",
            allow_single_file = True,
        ),
        zipper = attr.label(
            default = "@bazel_tools//tools/zip:zipper",
            cfg = "exec",
            executable = True,
            allow_single_file = True,
        ),
    ),
    provides = [platform_common.ToolchainInfo],
    implementation = _kt_jvm_toolchain_impl,
)

def _kt_jvm_toolchain(**kwargs):
    _kt_jvm_toolchain_internal(
        **kwargs
    )

_ATTRS = dict(
    _toolchain = attr.label(
        # TODO: Delete this attr when fixed.
        doc = "Magic attribute name for DexArchiveAspect (b/78647825)",
        default = "@//toolchains/kotlin_jvm:kt_jvm_toolchain_impl",
    ),
)

kt_jvm_toolchains = struct(
    name = _TYPE.name,
    get = lambda ctx: ctx.toolchains[_TYPE],
    type = str(_TYPE),
    declare = _kt_jvm_toolchain,
    attrs = _ATTRS,
)
