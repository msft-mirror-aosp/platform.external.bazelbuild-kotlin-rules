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

"""Aspect for exposing jdeps files from direct deps in a consistent way.

jdeps from exports are considered direct, and expost transitively. This includes
rules with deps-as-exports behaviours.
"""

_KtJdepsInfo = provider(
    doc = "Captures compile_jdeps files for a target including its exported deps.",
    fields = dict(
        compile_jdeps = "Depset of compile_jdeps files.",
    ),
)

# java_xxx_proto_library don't populate java_outputs but we can get them through
# required_aspect_providers from their proto_library deps.
_DEPS_AS_EXPORTS_RULES = [
    "java_proto_library",
    "java_lite_proto_library",
    "java_mutable_proto_library",
]

_NO_SRCS_DEPS_AS_EXPORTS_RULES = [
    "android_library",
    "proto_library",
]

def _aspect_impl(target, ctx):
    transitive_compile_jdeps = _collect_compile_jdeps(getattr(ctx.rule.attr, "exports", []))

    # It's ok if these lists are incomplete. Kotlin compilation will retry with all transitive
    # deps if incomplete jdeps are collected here.
    if ctx.rule.kind in _DEPS_AS_EXPORTS_RULES:
        transitive_compile_jdeps.extend(_collect_compile_jdeps(ctx.rule.attr.deps))
    elif ctx.rule.kind in _NO_SRCS_DEPS_AS_EXPORTS_RULES and not ctx.rule.attr.srcs:
        transitive_compile_jdeps.extend(_collect_compile_jdeps(ctx.rule.attr.deps))

    if JavaInfo in target:
        compile_jdeps = depset(
            direct = [out.compile_jdeps for out in target[JavaInfo].java_outputs if out.compile_jdeps],
            transitive = transitive_compile_jdeps,
        )
        return _KtJdepsInfo(compile_jdeps = compile_jdeps)
    elif transitive_compile_jdeps:
        return _KtJdepsInfo(compile_jdeps = depset(transitive = transitive_compile_jdeps))
    else:
        return []  # skip if empty in non-Java-like targets for efficiency

def _collect_compile_jdeps(targets):
    return [target[_KtJdepsInfo].compile_jdeps for target in targets if (_KtJdepsInfo in target)]

_aspect = aspect(
    implementation = _aspect_impl,
    # Transitively check exports, since they are effectively directly depended on.
    # "deps" needed for rules that treat deps as exports (usually absent srcs).
    attr_aspects = ["exports", "deps"],
    required_aspect_providers = [JavaInfo],  # to get at JavaXxxProtoAspects' JavaInfos
)

kt_jvm_dep_jdeps = struct(
    aspect = _aspect,
    collect_compile_jdeps_depsets = _collect_compile_jdeps,
)
