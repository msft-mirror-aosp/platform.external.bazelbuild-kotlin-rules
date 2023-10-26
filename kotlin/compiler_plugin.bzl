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

"""A rule for declaring and passing kotlinc plugins."""

load("//:visibility.bzl", "RULES_KOTLIN")
load("//kotlin/common/providers:compiler_plugin_infos.bzl", "kt_compiler_plugin_infos")

visibility(RULES_KOTLIN)

kt_compiler_plugin = rule(
    implementation = lambda ctx: _kt_compiler_plugin_impl(ctx),
    attrs = dict(
        plugin_id = attr.string(
            doc = "ID used to register this plugin with kotlinc",
            mandatory = True,
        ),
        jar = attr.label(
            doc = "JAR that provides the plugin implementation",
            mandatory = True,
            allow_single_file = [".jar"],
            cfg = "exec",
        ),
        args = attr.string_dict(
            doc = """Args to pass to the plugin

            The rule impl will format key-value pairs for the koltinc
            CLI. All plugin invocations will receive the same args.
            """,
            default = {},
        ),
    ),
    provides = [
        JavaPluginInfo,  # Allow this rule to be passed to java rules
        kt_compiler_plugin_infos.Info,
    ],
)

def _kt_compiler_plugin_impl(ctx):

    return [
        JavaPluginInfo(
            runtime_deps = [],
            processor_class = None,
        ),
        kt_compiler_plugin_infos.private_ctor(
            plugin_id = ctx.attr.plugin_id,
            jar = ctx.file.jar or ctx.attr.jar[JavaInfo].output_jar,
            args = [
                "plugin:%s:%s=%s" % (ctx.attr.plugin_id, k, v)
                for (k, v) in ctx.attr.args.items()
            ],
        ),
    ]
