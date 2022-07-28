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

"""Common Kotlin definitions."""

load("@bazel_skylib//lib:sets.bzl", "sets")
load("@bazel_skylib//lib:structs.bzl", "structs")
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@//bazel:stubs.bzl", "BASE_JVMOPTS")
load("@//bazel:stubs.bzl", "DEFAULT_BUILTIN_PROCESSORS")

# TODO: Remove the _ALLOWED_*_RULES lists to determine which rules
# are accepted dependencies to Kotlin rules as the approach does not scale
# because it will require a cl + release for every new rule.

_ALLOWED_ANDROID_RULES = [
    "aar_import",
    "android_library",
    "kt_android_library_helper",
]

_ALLOWED_JVM_RULES = [
    "_java_grpc_library",
    "_java_lite_grpc_library",
    "af_internal_guice_module",  # b/142743220
    "af_internal_jbcsrc_library",  # added with b/143872075
    "af_internal_soyinfo_generator",  # b/143872075
    "java_import",
    "java_library",
    "java_lite_proto_library",
    "java_mutable_proto_library",
    "java_proto_library",
    "java_wrap_cc",  # b/152799927
    "jvm_import",
    "kt_grpc_library_helper",
    "kt_jvm_library_helper",
    "kt_jvm_import",
    "kt_proto_library_helper",
    "_j2kt_jvm_library_rule",  # b/233055549
]

_EXT = struct(
    KT = ".kt",
    JAVA = ".java",
    JAR = ".jar",
    SRCJAR = ".srcjar",
)

_KT_FILE_TYPES = [_EXT.KT]

_KT_JVM_FILE_TYPES = [
    _EXT.JAVA,
    _EXT.KT,
    _EXT.SRCJAR,
]

_JAR_FILE_TYPE = [_EXT.JAR]

_SRCJAR_FILE_TYPES = [_EXT.JAR, _EXT.SRCJAR]

_RULE_FAMILY = struct(
    UNKNOWN = 0,
    JVM_LIBRARY = 1,
    ANDROID_LIBRARY = 2,
)

def _is_dir(file, basename):
    return file.is_directory and file.basename == basename

def _is_kt_src(src):
    """Decides if `src` Kotlin code.

    Either:
      -  a Kotlin source file
      -  a tree-artifact expected to contain only Kotlin source files
    """

    return src.path.endswith(_EXT.KT) or _is_dir(src, "kotlin")

# Compute module name based on target (b/139403883), similar to Swift
def _derive_module_name(ctx):
    label = _get_original_kt_target_label(ctx)
    package_part = label.package.replace("/", ".")  # .package has no leading //
    name_part = label.name
    if package_part:
        return package_part + "_" + name_part
    return name_part

def _common_kapt_and_kotlinc_args(ctx, toolchain):
    return toolchain.kotlin_compiler_common_flags + [
        # Set module name so module-level metadata is preserved when merging Jars (b/139403883)
        "-module-name",
        _derive_module_name(ctx),
    ]

# Runs KAPT in two separate actions so annotation processors only rerun when Kotlin stubs changed.
def _kapt(
        ctx,
        kt_srcs = [],
        common_srcs = [],
        java_srcs = [],
        kotlincopts = [],
        plugin_processors = [],
        plugin_classpaths = None,
        plugin_data = None,
        javacopts = [],
        toolchain = None,
        classpath = []):
    """Runs annotation processors, returns directory containing generated sources."""
    if not plugin_processors:  # shouldn't get here
        fail("Kapt cannot work without processors")

    # Kapt fails with "no source files" if only given Java sources (b/110473479), so skip ahead to
    # just run turbine if there are no .kt sources.
    stub_srcjars = []
    if kt_srcs or common_srcs:
        stubs_dir = ctx.actions.declare_directory(ctx.label.name + "/kapt/gen/stubs")
        _kapt_stubs(
            ctx,
            stubs_dir,
            kt_srcs,
            common_srcs,
            java_srcs,
            kotlincopts,
            plugin_processors,
            plugin_classpaths,
            toolchain,
            classpath,
        )

        # Create a srcjar for the .java stubs generated by kapt,
        # mostly to filter out non-.java stub outputs, e.g. .kapt_metadata.
        stub_srcjars.append(_create_zip(
            ctx,
            toolchain.zipper,
            ctx.actions.declare_file("stubs-srcjar.jar", sibling = stubs_dir),
            [stubs_dir],
            file_extensions = ["java"],
        ))

    output_jar = ctx.actions.declare_file(ctx.label.name + "-kapt.jar")
    output_srcjar = ctx.actions.declare_file(ctx.label.name + "-kapt.srcjar")
    output_manifest = ctx.actions.declare_file(ctx.label.name + "-kapt.jar_manifest_proto")
    _run_turbine(
        ctx,
        toolchain,
        plugin_processors,
        plugin_classpaths,
        plugin_data,
        classpath,
        javacopts,
        java_srcs,
        output_jar,
        output_srcjar,
        output_manifest,
        stub_srcjars,
    )

    return struct(
        jar = output_jar,
        manifest = output_manifest,
        srcjar = output_srcjar,
    )

def _kapt_stubs(
        ctx,
        stubs_dir,
        kt_srcs = [],
        common_srcs = [],
        java_srcs = [],
        kotlincopts = [],
        plugin_processors = [],
        plugin_classpaths = None,
        toolchain = None,
        classpath = []):
    """Runs kapt3's "stubs" mode to generate .java stubs from given .kt sources."""

    # Use params file to handle long classpaths (b/76185759).
    kaptargs = ctx.actions.args()
    kaptargs.use_param_file("@%s", use_always = True)
    kaptargs.set_param_file_format("multiline")  # avoid shell-quoting which breaks workers

    kaptargs.add(toolchain.kotlin_annotation_processing, format = "-Xplugin=%s")
    kaptargs.add("-P", "plugin:org.jetbrains.kotlin.kapt3:aptMode=stubs")

    # List processor classes one by one (comma-separated list doesn't work even though documentation
    # seems to say that it should: http://kotlinlang.org/docs/reference/kapt.html#using-in-cli)
    kaptargs.add_all(
        plugin_processors,
        before_each = "-P",
        format_each = "plugin:org.jetbrains.kotlin.kapt3:processors=%s",
        uniquify = True,  # multiple plugins can define the same processor, theoretically
    )
    kaptargs.add_all(
        plugin_classpaths,  # no need to uniquify depsets
        before_each = "-P",
        format_each = "plugin:org.jetbrains.kotlin.kapt3:apclasspath=%s",
    )
    kaptargs.add("-P", "plugin:org.jetbrains.kotlin.kapt3:sources=/tmp")
    kaptargs.add("-P", "plugin:org.jetbrains.kotlin.kapt3:classes=/tmp")
    kaptargs.add("-P", stubs_dir.path, format = "plugin:org.jetbrains.kotlin.kapt3:stubs=%s")
    kaptargs.add("-P", "plugin:org.jetbrains.kotlin.kapt3:correctErrorTypes=true")

    # kapt requires javac options to be base64-encoded,
    # see: http://kotlinlang.org/docs/reference/kapt.html#apjavac-options-encoding
    # The string below is the encoding of "-source 8 -target 8".
    # TODO: use the full google3 defaults instead of hard-coding.
    kaptargs.add("-P", "plugin:org.jetbrains.kotlin.kapt3:javacArguments=rO0ABXccAAAAAgAHLXNvdXJjZQABOAAHLXRhcmdldAABOA")
    kaptargs.add_all(_common_kapt_and_kotlinc_args(ctx, toolchain))
    kaptargs.add_joined("-cp", classpath, join_with = ":")
    kaptargs.add_all(kotlincopts)

    kaptargs.add_all(kt_srcs)
    kaptargs.add_all(common_srcs)
    if java_srcs:
        kaptargs.add_all(java_srcs)

    tool_inputs = [toolchain.kotlin_annotation_processing]

    ctx.actions.run(
        executable = toolchain.kotlin_compiler,
        arguments = [kaptargs],
        inputs = depset(
            direct = (
                kt_srcs +
                common_srcs +
                java_srcs +
                tool_inputs
            ),
            transitive = [
                classpath,
                plugin_classpaths,
            ],
        ),
        outputs = [stubs_dir],
        mnemonic = "KtKaptStubs",
        progress_message = "Kapt stubs generation: %s" % _get_original_kt_target_label(ctx),
        execution_requirements = {
            "worker-key-mnemonic": "Kt2JavaCompile",  # share workers with Kt2JavaCompile (b/179578322)
        },
    )

def _run_turbine(
        ctx,
        toolchain,
        plugin_processors,
        plugin_classpaths,
        plugin_data,
        classpath,
        javacopts,
        java_srcs,
        output_jar,
        output_srcjar,
        output_manifest,
        stub_srcjar = []):
    turbineargs = ctx.actions.args()
    turbineargs.use_param_file("@%s")
    turbineargs.add_all("--processors", plugin_processors)
    turbineargs.add_all("--processorpath", plugin_classpaths)

    # --define=header_compiler_builtin_processors_setting=false should disable built-in processors,
    # see: http://google3/tools/jdk/BUILD?l=338&rcl=269833772
    enable_builtin_processors = ctx.var.get("header_compiler_builtin_processors_setting", default = "true") != "false"
    if enable_builtin_processors:
        turbineargs.add_all("--builtin_processors", DEFAULT_BUILTIN_PROCESSORS)

    turbineargs.add_all("--javacopts", javacopts)
    turbineargs.add("--")

    turbineargs.add_all("--classpath", classpath)

    turbineargs.add("--gensrc_output", output_srcjar)
    turbineargs.add("--resource_output", output_jar)
    turbineargs.add("--output_manifest_proto", output_manifest)

    turbineargs.add_all("--source_jars", stub_srcjar)

    if java_srcs:
        turbineargs.add("--sources")
        turbineargs.add_all(java_srcs)

    outputs = [output_srcjar, output_jar, output_manifest]
    progress_message = "Kotlin annotation processing: %s %s" % (_get_original_kt_target_label(ctx), ", ".join(plugin_processors))
    inputs = depset(direct = java_srcs + stub_srcjar, transitive = [classpath, plugin_classpaths, plugin_data])

    if enable_builtin_processors and toolchain.turbine_direct and all([p in DEFAULT_BUILTIN_PROCESSORS for p in plugin_processors]):
        ctx.actions.run(
            executable = toolchain.turbine_direct,
            arguments = [turbineargs],
            inputs = inputs,
            outputs = outputs,
            mnemonic = "KtKaptAptDirect",
            progress_message = progress_message,
        )
    else:
        _actions_run_deploy_jar(
            ctx = ctx,
            java_runtime = toolchain.java_runtime,
            deploy_jar = toolchain.turbine,
            deploy_jsa = toolchain.turbine_jsa,
            inputs = inputs,
            outputs = outputs,
            args = [turbineargs],
            mnemonic = "KtKaptApt",
            progress_message = progress_message,
        )

def _derive_gen_class_jar(
        ctx,
        toolchain,
        manifest_proto,
        javac_jar,
        java_srcs = []):
    """Returns the annotation processor-generated classes contained in given Jar."""
    if not manifest_proto:
        return None
    if not javac_jar:
        fail("There must be a javac Jar if there was annotation processing")
    if not java_srcs:
        # If there weren't any hand-written .java srcs, just use Javac's output
        return javac_jar

    # Run GenClass tool to derive gen_class_jar by filtering hand-written sources.
    # cf. Bazel's JavaCompilationHelper#createGenJarAction
    result = ctx.actions.declare_file(ctx.label.name + "-gen.jar")

    genclass_args = ctx.actions.args()
    genclass_args.add("--manifest_proto", manifest_proto)
    genclass_args.add("--class_jar", javac_jar)
    genclass_args.add("--output_jar", result)

    _actions_run_deploy_jar(
        ctx = ctx,
        java_runtime = toolchain.java_runtime,
        deploy_jar = toolchain.genclass,
        inputs = [manifest_proto, javac_jar],
        outputs = [result],
        args = [genclass_args],
        mnemonic = "KtGenClassJar",
        progress_message = "Deriving %{output}",
    )

    return result

def _run_kotlinc(
        ctx,
        output,
        kt_srcs = [],
        common_srcs = [],
        java_srcs_and_dirs = [],
        kotlincopts = [],
        compile_jdeps = depset(),
        toolchain = None,
        classpath = [],
        directdep_jars = depset(),
        kt_plugin_configs = [],
        friend_jars = depset(),
        enforce_strict_deps = False,
        enforce_complete_jdeps = False):
    if output.extension != "jar":
        fail("Expect to output a Jar but got %s" % output)

    kt_plugin_configs = list(kt_plugin_configs)

    kt_ijar = ctx.actions.declare_file(output.basename[:-4] + "-ijar.jar", sibling = output)
    kt_plugin_configs.append(
        _kt_plugin_config(
            jar = toolchain.jvm_abi_gen_plugin,
            outputs = [kt_ijar],
            write_opts = lambda args: (
                args.add("-P", kt_ijar, format = "plugin:org.jetbrains.kotlin.jvm.abi:outputDir=%s"),
            ),
        ),
    )

    inputs = depset(
        direct = (
            kt_srcs +
            common_srcs +
            java_srcs_and_dirs +
            [config.jar for config in kt_plugin_configs]
        ),
        transitive = [
            # friend_jars # These are always a subset of the classpath
            # directdep_jars # These are always a subset of the classpath
            classpath,
            compile_jdeps,
        ],
    )
    outputs = [output]
    for config in kt_plugin_configs:
        outputs.extend(config.outputs)

    # Args to kotlinc.
    #
    # These go at the end of the commandline. They should be passed through all wrapper
    # layers without post-processing, except to unpack param files.
    kotlinc_args = ctx.actions.args()
    kotlinc_args.use_param_file("@%s", use_always = True)  # Use params file to handle long classpaths (b/76185759)
    kotlinc_args.set_param_file_format("multiline")  # kotlinc only supports double-quotes ("): https://youtrack.jetbrains.com/issue/KT-24472

    kotlinc_args.add_all(_common_kapt_and_kotlinc_args(ctx, toolchain))
    kotlinc_args.add_joined("-cp", classpath, join_with = ":")
    kotlinc_args.add_all(kotlincopts)
    for config in kt_plugin_configs:
        kotlinc_args.add(config.jar, format = "-Xplugin=%s")
        config.write_opts(kotlinc_args)

    # Common sources must also be specified as -Xcommon-sources= in addition to appearing in the
    # source list.
    if common_srcs:
        kotlinc_args.add("-Xmulti-platform=true")
        kotlinc_args.add_all(common_srcs, format_each = "-Xcommon-sources=%s")

    kotlinc_args.add("-d", output)
    kotlinc_args.add_all(kt_srcs)
    kotlinc_args.add_all(common_srcs)

    if java_srcs_and_dirs:
        # This expands any directories into their contained files
        kotlinc_args.add_all(java_srcs_and_dirs)

    kotlinc_args.add_joined(friend_jars, format_joined = "-Xfriend-paths=%s", join_with = ",")

    # Do not change the "shape" or mnemonic of this action without consulting Kythe team
    # (kythe-eng@), to avoid breaking the Kotlin Kythe extractor which "shadows" this action.  In
    # particular, the extractor expects this to be a vanilla "spawn" (ctx.actions.run) so don't
    # change this to ctx.actions.run_shell or something else without considering Kythe implications
    # (b/112439843).
    ctx.actions.run(
        executable = toolchain.kotlin_compiler,
        arguments = [kotlinc_args],
        inputs = inputs,
        outputs = outputs,
        mnemonic = "Kt2JavaCompile",
        progress_message = "Compiling Kotlin For Java Runtime: %s" % _get_original_kt_target_label(ctx),
        execution_requirements = {
            "worker-key-mnemonic": "Kt2JavaCompile",
        },
    )

    # TODO: Normalize paths to match package declarations in source files.
    srcjar = _create_zip(
        ctx,
        toolchain.zipper,
        ctx.actions.declare_file(ctx.label.name + "-kt-src.jar"),
        kt_srcs + common_srcs,
    )

    return struct(
        output_jar = output,
        compile_jar = kt_ijar,
        source_jar = srcjar,
    )

def _get_original_kt_target_label(ctx):
    label = ctx.label
    if label.name.find("_DO_NOT_DEPEND") > 0:
        # Remove rule suffix added by kt_android_library
        label = label.relative(":%s" % label.name[0:label.name.find("_DO_NOT_DEPEND")])

    return label

def _empty_fn(*_, **__):
    return None

def _kt_plugin_config(
        jar,
        outputs = [],
        write_opts = _empty_fn):
    """A struct representing a kotlinc plugin.

    Args:
      jar: [File] The JAR that contains/declares the plugin
      outputs: [List<File>] The files the plugin outputs
      write_opts: [function(Args): None] A function that writes plugin options to an Args
          object. Using a function allows efficiently setting/storing/reusing options.
    """
    return struct(
        _type = "kt_plugin_config",
        jar = jar,
        outputs = outputs,
        write_opts = write_opts,
    )

def _check_deps(
        ctx,
        jars_to_check = [],
        merged_deps = None,
        enforce_strict_deps = True,
        jdeps_output = None,
        deps_checker = None,
        java_toolchain = None):
    # Direct compile_jars before transitive not to confuse strict_deps (b/149107867)
    full_classpath = depset(
        order = "preorder",
        transitive = [merged_deps.compile_jars, merged_deps.transitive_compile_time_jars],
    )
    label = _get_original_kt_target_label(ctx)
    bootclasspath = java_toolchain.bootclasspath

    args = ctx.actions.args()
    args.add("--jdeps_output", jdeps_output)
    args.add_all(jars_to_check, before_each = "--input")
    args.add_all(bootclasspath, before_each = "--bootclasspath_entry")
    args.add_all(full_classpath, before_each = "--classpath_entry")
    if enforce_strict_deps:
        args.add_all(merged_deps.compile_jars, before_each = "--directdep")
    args.add("--checking_mode=%s" % ("error" if enforce_strict_deps else "silence"))
    args.add("--nocheck_missing_members")  # compiler was happy so no need
    args.add("--rule_label")
    args.add(label)

    ctx.actions.run(
        executable = deps_checker,
        arguments = [args],
        inputs = depset(
            jars_to_check,
            transitive = [bootclasspath, full_classpath],
        ),
        outputs = [jdeps_output],
        mnemonic = "KtCheckStrictDeps" if enforce_strict_deps else "KtJdeps",
        progress_message = "%s deps for %s" % (
            "Checking strict" if enforce_strict_deps else "Computing",
            label,
        ),
    )

def _singlejar(
        ctx,
        inputs,
        output,
        singlejar,
        mnemonic = "KtMergeJar",
        content = "final Jar",
        preserve_compression = False,
        pseudo_inputs = []):
    label = _get_original_kt_target_label(ctx)
    args = ctx.actions.args()
    args.add("--normalize")
    args.add("--add_missing_directories")  # make output more similar to jar tool (b/114414678)
    args.add("--exclude_build_data")
    if not _enable_complete_jdeps_extra_run(ctx):
        args.add("--no_duplicates")  # No Kt/Java classname collisions (b/216841985)
    args.add("--output")
    args.add(output)
    args.add("--sources")
    args.add_all(inputs)
    args.add("--deploy_manifest_lines")
    args.add("Target-Label: %s" % label)
    if preserve_compression:
        args.add("--dont_change_compression")

    ctx.actions.run(
        executable = singlejar,
        arguments = [args],
        inputs = inputs + pseudo_inputs,
        outputs = [output],
        mnemonic = mnemonic,
        progress_message = "Merging %s: %s" % (content, label),
    )

def _merge_jdeps(ctx, kt_jvm_toolchain, jdeps_files, output_suffix = ""):
    merged_jdeps_file = ctx.actions.declare_file(ctx.label.name + output_suffix + ".jdeps")

    args = ctx.actions.args()
    args.add("--kind=jdeps")
    args.add(merged_jdeps_file, format = "--output=%s")
    args.add(_get_original_kt_target_label(ctx), format = "--rule_label=%s")
    args.add_all(jdeps_files)

    ctx.actions.run(
        executable = kt_jvm_toolchain.jdeps_merger,
        inputs = jdeps_files,
        outputs = [merged_jdeps_file],
        arguments = [args],
        mnemonic = "KtMergeJdeps",
        progress_message = "Merging jdeps files %{output}",
    )

    return merged_jdeps_file

def _expand_zip(ctx, dir, input, extra_args = []):
    ctx.actions.run_shell(
        outputs = [dir],
        inputs = [input],
        command = "unzip -q {input} -d {dir} {args} 2> /dev/null || mkdir -p {dir}".format(
            input = input.path,
            dir = dir.path,
            args = " ".join(extra_args),
        ),
    )
    return dir

def _create_zip(ctx, zipper, out_zip, inputs, file_extensions = None):
    def file_filter(file):
        return file.path if (
            file_extensions == None or (file.extension in file_extensions)
        ) else None

    args = ctx.actions.args()
    args.add("cC", out_zip)
    args.add_all(inputs, map_each = file_filter, allow_closure = True)

    ctx.actions.run(
        executable = zipper,
        inputs = inputs,
        outputs = [out_zip],
        arguments = [args],
        mnemonic = "KtJar",
        progress_message = "Create Jar %{output}",
    )

    return out_zip

def _DirSrcjarSyncer(ctx, kt_toolchain, name):
    _dirs = []
    _srcjars = []

    def add_dirs(dirs):
        if not dirs:
            return

        _dirs.extend(dirs)
        _srcjars.append(
            _create_zip(
                ctx,
                kt_toolchain.zipper,
                ctx.actions.declare_file(
                    "%s/%s%s.srcjar" % (ctx.label.name, name, len(_srcjars)),
                ),
                dirs,
            ),
        )

    def add_srcjars(srcjars):
        if not srcjars:
            return

        for srcjar in srcjars:
            _dirs.append(
                _expand_zip(
                    ctx,
                    ctx.actions.declare_directory(
                        "%s/%s%s.expand" % (ctx.label.name, name, len(_dirs)),
                    ),
                    srcjar,
                    extra_args = ["*.java", "*.kt"],
                ),
            )
        _srcjars.extend(srcjars)

    return struct(
        add_dirs = add_dirs,
        add_srcjars = add_srcjars,
        dirs = _dirs,
        srcjars = _srcjars,
    )

def _actions_run_deploy_jar(
        ctx,
        java_runtime,
        deploy_jar,
        inputs,
        args = [],
        deploy_jsa = None,
        **kwargs):
    java_args = ctx.actions.args()
    java_inputs = []
    if deploy_jsa:
        java_args.add("-Xshare:auto")
        java_args.add(deploy_jsa, format = "-XX:SharedArchiveFile=%s")
        java_args.add("-XX:-VerifySharedSpaces")
        java_args.add("-XX:-ValidateSharedClassPaths")
        java_inputs.append(deploy_jsa)
    java_args.add("-jar", deploy_jar)
    java_inputs.append(deploy_jar)

    java_depset = depset(direct = java_inputs, transitive = [java_runtime[DefaultInfo].files])
    if type(inputs) == "depset":
        all_inputs = depset(transitive = [java_depset, inputs])
    else:
        all_inputs = depset(direct = inputs, transitive = [java_depset])

    ctx.actions.run(
        executable = str(java_runtime[java_common.JavaRuntimeInfo].java_executable_exec_path),
        inputs = all_inputs,
        arguments = BASE_JVMOPTS + [java_args] + args,
        **kwargs
    )

def _check_srcs_package(target_package, srcs, attr_name):
    """Makes sure the given srcs live in the given package."""

    # Analogous to RuleContext.checkSrcsSamePackage
    for src in srcs:
        if target_package != src.owner.package:
            fail(("Please do not depend on %s directly in %s.  Either move it to this package or " +
                  "depend on an appropriate rule in its package.") % (src.owner, attr_name))

# TODO: Streamline API to generate less actions.
def _kt_jvm_library(
        ctx,
        kt_toolchain,
        srcs = [],
        common_srcs = [],
        coverage_srcs = [],
        manifest = None,  # set for Android libs, otherwise None.
        merged_manifest = None,  # set for Android libs, otherwise None.
        resource_files = [],  # set for Android libs, otherwise empty.
        classpath_resources = [],  # set for kt_jvm_library, otherwise empty.
        output = None,
        output_srcjar = None,  # Will derive default filename if not set.
        deps = [],
        exports = [],  # passthrough for JavaInfo constructor
        runtime_deps = [],  # passthrough for JavaInfo constructor
        native_libraries = [],  # passthrough of CcInfo for JavaInfo constructor
        plugins = [],  # list of JavaPluginInfo
        exported_plugins = [],
        android_lint_plugins = [],
        android_lint_rules_jars = depset(),  # Depset with standalone Android Lint rules Jars
        javacopts = [],
        kotlincopts = [],
        compile_jdeps = depset(),
        disable_lint_checks = [],
        neverlink = False,
        testonly = False,  # used by Android Lint
        enforce_strict_deps = True,
        rule_family = _RULE_FAMILY.UNKNOWN,
        enforce_complete_jdeps = False,
        java_toolchain = None,
        kt_plugin_configs = [],
        friend_jars = depset(),
                annotation_processor_additional_outputs = [],
        annotation_processor_additional_inputs = []):
    if not java_toolchain:
        fail("Missing or invalid java_toolchain")
    if not kt_toolchain:
        fail("Missing or invalid kt_toolchain")

    merged_deps = java_common.merge(deps)

    # Split sources, as java requires a separate compile step.
    kt_srcs = [s for s in srcs if _is_kt_src(s)]
    java_srcs = [s for s in srcs if s.path.endswith(_EXT.JAVA)]
    java_syncer = _DirSrcjarSyncer(ctx, kt_toolchain, "java")
    java_syncer.add_dirs([s for s in srcs if _is_dir(s, "java")])
    java_syncer.add_srcjars([s for s in srcs if s.path.endswith(_EXT.SRCJAR)])

    expected_srcs = sets.make(kt_srcs + java_srcs + java_syncer.dirs + java_syncer.srcjars)
    unexpected_srcs = sets.difference(sets.make(srcs), expected_srcs)
    if sets.length(unexpected_srcs) != 0:
        fail("Unexpected srcs: %s" % sets.to_list(unexpected_srcs))

    # Skip srcs package check for android_library targets with no kotlin sources: b/239725424
    if rule_family != _RULE_FAMILY.ANDROID_LIBRARY or kt_srcs:
        _check_srcs_package(ctx.label.package, srcs, "srcs")
        _check_srcs_package(ctx.label.package, common_srcs, "common_srcs")
        _check_srcs_package(ctx.label.package, coverage_srcs, "coverage_srcs")

    # Complete classpath including bootclasspath. Like for Javac, explicitly place direct
    # compile_jars before transitive not to confuse strict_deps (b/149107867).
    full_classpath = depset(
        order = "preorder",
        transitive = [
            java_toolchain.bootclasspath,
            merged_deps.compile_jars,
            merged_deps.transitive_compile_time_jars,
        ],
    )

    # Collect all plugin data
    java_plugin_data = [plugin.plugins for plugin in plugins] + [dep.plugins for dep in deps]

    # Collect processors to run ...
    plugin_processors = [cls for p in java_plugin_data for cls in p.processor_classes.to_list()]

    # ... and all plugin classpaths, whether they have processors or not (b/120995492).
    # This may include go/errorprone plugin classpaths that kapt will ignore.
    plugin_classpaths = depset(
        order = "preorder",
        transitive = [p.processor_jars for p in java_plugin_data],
    )

    out_jars = []
    out_srcjars = []
    out_compilejars = []
    kapt_outputs = struct(jar = None, manifest = None, srcjar = None)

    # Kotlin compilation requires two passes when annotation processing is
    # required. The initial pass processes the annotations and generates
    # additional sources and the following pass compiles the Kotlin code.
    # Skip kapt if no plugins have processors (can happen with only
    # go/errorprone plugins, # b/110540324)
    if kt_srcs and plugin_processors:
        kapt_outputs = _kapt(
            ctx,
            kt_srcs = kt_srcs,
            common_srcs = common_srcs,
            java_srcs = java_srcs,
            plugin_processors = plugin_processors,
            plugin_classpaths = plugin_classpaths,
            plugin_data = depset(transitive = [p.processor_data for p in java_plugin_data]),
            # Put contents of Bazel flag --javacopt before given javacopts as is Java rules.
            # This still ignores package configurations, which aren't exposed to Starlark.
            javacopts = (java_common.default_javac_opts(java_toolchain = java_toolchain) +
                         ctx.fragments.java.default_javac_flags +
                         javacopts),
            kotlincopts = kotlincopts,  # don't need strict_deps flags for kapt
            toolchain = kt_toolchain,
            classpath = full_classpath,
        )

        out_jars.append(kapt_outputs.jar)
        java_syncer.add_srcjars([kapt_outputs.srcjar])

        merged_deps = java_common.merge([merged_deps, JavaInfo(
            output_jar = kapt_outputs.jar,
            compile_jar = kapt_outputs.jar,
        )])

    kotlinc_result = None
    if kt_srcs or common_srcs:
        kotlinc_result = _run_kotlinc(
            ctx,
            kt_srcs = kt_srcs,
            common_srcs = common_srcs,
            java_srcs_and_dirs = java_srcs + java_syncer.dirs,
            output = ctx.actions.declare_file(ctx.label.name + "-kt.jar"),
            kotlincopts = kotlincopts,
            compile_jdeps = compile_jdeps,
            toolchain = kt_toolchain,
            classpath = full_classpath,
            kt_plugin_configs = kt_plugin_configs,
            friend_jars = friend_jars,
            enforce_strict_deps = enforce_strict_deps,
            enforce_complete_jdeps = enforce_complete_jdeps,
        )

        # Use un-instrumented Jar at compile-time to avoid double-instrumenting inline functions
        # (see b/110763361 for the comparable Gradle issue)
        out_compilejars.append(kotlinc_result.compile_jar)
        out_srcjars.append(kotlinc_result.source_jar)

        # Apply coverage instrumentation if requested, and add dep on JaCoCo runtime to merged_deps.
        # The latter helps jdeps computation (b/130747644) but could be runtime-only if we computed
        # compile-time Jdeps based using the compile Jar (which doesn't contain instrumentation).
        # See b/117897097 for why it's still useful to make the (runtime) dep explicit.
        if ctx.coverage_instrumented():
            pass
        else:
            out_jars.append(kotlinc_result.output_jar)

    javac_java_info = None
    java_native_headers_jar = None
    java_gensrcjar = None
    java_genjar = None
    if java_srcs or java_syncer.srcjars or classpath_resources:
        javac_out = ctx.actions.declare_file(ctx.label.name + "-java.jar")
        javac_java_info = java_common.compile(
            ctx,
            source_files = java_srcs,
            source_jars = java_syncer.srcjars,
            resources = classpath_resources,
            output = javac_out,
            deps = ([JavaInfo(**structs.to_dict(kotlinc_result))] if kotlinc_result else []) + [merged_deps],
            # Include default_javac_flags, which reflect Blaze's --javacopt flag, so they win over
            # all sources of default flags (for Ellipsis builds, see b/125452475).
            # TODO: remove default_javac_flags here once java_common.compile is fixed.
            javac_opts = ctx.fragments.java.default_javac_flags + javacopts,
            plugins = plugins,
            strict_deps = "DEFAULT",
            java_toolchain = java_toolchain,
            neverlink = neverlink,
            # Enable annotation processing for java-only sources to enable data binding
            enable_annotation_processing = not kt_srcs,
            annotation_processor_additional_outputs = annotation_processor_additional_outputs,
            annotation_processor_additional_inputs = annotation_processor_additional_inputs,
        )
        out_jars.append(javac_out)
        out_srcjars.extend(javac_java_info.source_jars)
        out_compilejars.extend(javac_java_info.compile_jars.to_list())  # unpack singleton depset
        java_native_headers_jar = javac_java_info.outputs.native_headers

        if kt_srcs:
            java_gensrcjar = kapt_outputs.srcjar
            java_genjar = _derive_gen_class_jar(ctx, kt_toolchain, kapt_outputs.manifest, javac_out, java_srcs)
        else:
            java_gensrcjar = javac_java_info.annotation_processing.source_jar
            java_genjar = javac_java_info.annotation_processing.class_jar
            if java_gensrcjar:
                java_syncer.add_srcjars([java_gensrcjar])

    jdeps_output = None
    compile_jdeps_output = None

    # TODO: Move severity overrides to config file when possible again
    blocking_action_outs = []

    if output_srcjar == None:
        output_srcjar = ctx.actions.declare_file("lib%s-src.jar" % ctx.label.name)
    compile_jar = ctx.actions.declare_file(ctx.label.name + "-compile.jar")
    single_jar = java_toolchain.single_jar
    _singlejar(ctx, out_srcjars, output_srcjar, single_jar, mnemonic = "KtMergeSrcjar", content = "srcjar", preserve_compression = True)

    # Don't block compile-time Jar on Android Lint and other validations (b/117991324).
    _singlejar(ctx, out_compilejars, compile_jar, single_jar, mnemonic = "KtMergeCompileJar", content = "compile-time Jar")

    # Disable validation for Guitar BUILD targets (b/144326858).
    # TODO Remove use of RUN_ANALYSIS_TIME_VALIDATION once Guitar disables validations
    use_validation = ctx.var.get("RUN_ANALYSIS_TIME_VALIDATION", "true")  # will be "0" if set by Guitar
    use_validation = ctx.var.get("kt_use_validations", use_validation)

    # Include marker file in runtime Jar so we can reliably identify 1P Kotlin code
    # TODO: consider only doing this for kt_android_library
    _singlejar(
        ctx,
        out_jars + ([kt_toolchain.build_marker] if kt_srcs and ctx.label.package.startswith("java/") else []),
        output,
        single_jar,
        preserve_compression = True,
        pseudo_inputs = ([] if use_validation == "true" else blocking_action_outs),
    )
    result_java_info = JavaInfo(
        output_jar = output,
        compile_jar = compile_jar,
        source_jar = output_srcjar,
        deps = deps,
        exports = exports,
        exported_plugins = exported_plugins,
        runtime_deps = runtime_deps,
        neverlink = neverlink,
        jdeps = jdeps_output,
        compile_jdeps = compile_jdeps_output,
        native_libraries = native_libraries,
        native_headers_jar = java_native_headers_jar,
        generated_source_jar = java_gensrcjar,
        generated_class_jar = java_genjar,
    )

    return struct(
        java_info = result_java_info,
        validations = (blocking_action_outs if use_validation == "true" else []),
    )

def _kt_jvm_import(
        ctx,
        jars = [],
        srcjar = None,
        deps = [],
        runtime_deps = [],
        neverlink = False,
        java_toolchain = None,
        deps_checker = None):
    if not java_toolchain:
        fail("Missing or invalid java_toolchain")
    merged_deps = java_common.merge(deps)

    # Check that any needed deps are declared unless neverlink, in which case Jars won't be used
    # at runtime so we skip the check, though we'll populate jdeps either way.
    jdeps_output = ctx.actions.declare_file(ctx.label.name + ".jdeps")
    _check_deps(
        ctx,
        jars_to_check = jars,
        merged_deps = merged_deps,
        enforce_strict_deps = not neverlink,
        jdeps_output = jdeps_output,
        deps_checker = deps_checker,
        java_toolchain = java_toolchain,
    )

    if not jars:
        fail("Must provide a Jar to use kt_jvm_import")

    java_info = java_common.merge([
        JavaInfo(
            output_jar = jar,
            compile_jar = jar,
            source_jar = srcjar,
            deps = deps,
            runtime_deps = runtime_deps,
            neverlink = neverlink,
            # TODO: Set compile-time jdeps to help reduce Javac classpaths downstream
            jdeps = jdeps_output,  # not clear this is useful but let's populate since we have it
        )
        for jar in jars
    ])

    # TODO Remove use of RUN_ANALYSIS_TIME_VALIDATION once Guitar disables validations
    use_validation = ctx.var.get("RUN_ANALYSIS_TIME_VALIDATION", "true")  # will be "0" if set by Guitar

    return struct(
        java_info = java_info,
        validations = [jdeps_output] if use_validation == "true" and not neverlink else [],
    )

def _validate_proguard_specs(
        ctx,
        proguard_specs,
        proguard_allowlister):
    validated_proguard_specs = []
    for proguard_spec in proguard_specs:
        validated_proguard_spec = ctx.actions.declare_file(
            "validated_proguard/%s/%s_valid" % (ctx.label.name, proguard_spec.path),
        )
        validated_proguard_specs.append(validated_proguard_spec)

        args = ctx.actions.args()
        args.add("--path", proguard_spec)
        args.add("--output", validated_proguard_spec)

        ctx.actions.run(
            executable = proguard_allowlister,
            arguments = [args],
            inputs = [proguard_spec],
            outputs = [validated_proguard_spec],
            mnemonic = "ValidateProguard",
            progress_message = (
                "Validating proguard configuration %s" % proguard_spec
            ),
        )
    return validated_proguard_specs

def _collect_proguard_specs(
        ctx,
        proguard_specs,
        propagated_deps,
        proguard_allowlister):
    validated_proguard_specs = _validate_proguard_specs(
        ctx,
        proguard_specs,
        proguard_allowlister,
    )

    return depset(
        validated_proguard_specs,
        transitive = [p.specs for p in _collect_providers(ProguardSpecProvider, propagated_deps)],
        order = "preorder",
    )

def _collect_providers(provider, deps):
    """Collects the requested provider from the given list of deps."""
    return [dep[provider] for dep in deps if provider in dep]

def _enable_complete_jdeps_extra_run(ctx):
    if hasattr(ctx.attr, "_enable_complete_jdeps_extra_run"):
        return ctx.attr._enable_complete_jdeps_extra_run[BuildSettingInfo].value
    return False

common = struct(
    ALLOWED_ANDROID_RULES = _ALLOWED_ANDROID_RULES,
    ALLOWED_JVM_RULES = _ALLOWED_JVM_RULES,
    JAR_FILE_TYPE = _JAR_FILE_TYPE,
    JVM_FLAGS = BASE_JVMOPTS,
    KT_FILE_TYPES = _KT_FILE_TYPES,
    KT_JVM_FILE_TYPES = _KT_JVM_FILE_TYPES,
    RULE_FAMILY = _RULE_FAMILY,
    SRCJAR_FILE_TYPES = _SRCJAR_FILE_TYPES,
    collect_proguard_specs = _collect_proguard_specs,
    collect_providers = _collect_providers,
    is_kt_src = _is_kt_src,
    kt_jvm_import = _kt_jvm_import,
    kt_jvm_library = _kt_jvm_library,
    kt_plugin_config = _kt_plugin_config,
)
