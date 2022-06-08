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

"""Identifies and reports forbidden deps of Kotlin rules.

Currently this system recognizes:
  - nano protos
  - targets in forbidden packages
  - targets exporting other forbidden targets
"""

load("@bazel_skylib//lib:new_sets.bzl", "sets")
load("@//bazel:stubs.bzl", "EXEMPT_DEPS", "FORBIDDEN_DEP_PACKAGES")

_KtForbiddenDepInfo = provider(
    doc = "Info about forbiddenness as a Kotlin dep.",
    fields = dict(
        cause = "Optional[string|dict]: Why is this target forbidden as a dep. None means not forbidden.",
    ),
)

def _aspect_impl(_unused_target, ctx):
    if _is_exempt(str(ctx.label)):
        return _KtForbiddenDepInfo(cause = None)

    if sets.contains(FORBIDDEN_DEP_PACKAGES, ctx.label.package):
        return _KtForbiddenDepInfo(cause = "Forbidden package")

    # Identify nano protos using tag (b/122083175)
    for tag in ctx.rule.attr.tags:
        if "nano_proto_library" == tag:
            return _KtForbiddenDepInfo(cause = "nano_proto_library")

    # Check exports if the visited rule isn't itself a problem
    export_errors = _merge_errors(getattr(ctx.rule.attr, "exports", []))
    if len(export_errors) > 0:
        return _KtForbiddenDepInfo(cause = export_errors)

    return _KtForbiddenDepInfo(cause = None)

_aspect = aspect(
    implementation = _aspect_impl,
    # Transitively check exports, since they are effectively directly depended on
    attr_aspects = ["exports"],
)

def _validate_deps(deps):
    errors = _merge_errors(deps)
    if len(errors) > 0:
        fail("Forbidden deps, see go/kotlin/build-rules#restrictions:\n" + "\n".join(
            [
                "  " + k + " : " + v
                for k, v in errors.items()
            ],
        ))

def _merge_errors(targets):
    errors = {}
    for target in targets:
        label_str = str(target.label)
        if _KtForbiddenDepInfo in target:
            cause = target[_KtForbiddenDepInfo].cause
            if not cause:
                continue
            elif type(cause) == "dict":
                errors.update(cause)
            else:
                errors[label_str] = cause
        elif not _is_exempt(label_str):
            errors[label_str] = "It was not checked for forbiddenness"

    return errors

def _is_exempt(label_str):
    return sets.contains(EXEMPT_DEPS, label_str)

kt_forbidden_deps = struct(
    aspect = _aspect,
    validate_deps = _validate_deps,
)
