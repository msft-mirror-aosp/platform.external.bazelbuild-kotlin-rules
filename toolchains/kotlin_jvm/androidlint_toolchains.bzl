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

"""Android Lint toolchain for Kotlin."""

load("//bazel:stubs.bzl", "lint_actions")
load("//bazel:stubs.bzl", "LINT_REGISTRY")
load("//bazel:stubs.bzl", "registry_checks_for_package")

_ATTRS = dict(
    _android_lint_baseline_file = attr.label(
        allow_single_file = True,
        cfg = "exec",
    ),
    _android_lint_plugins = attr.label_list(
        providers = [
            [JavaInfo],
        ],
        cfg = "exec",
    ),
    _android_lint_wrapper = attr.label(
        executable = True,
        cfg = "exec",
    ),
)

def _set_baselines():
    return {
        # `$foo` is used to set `_foo`
        "$android_lint_baseline_file": lint_actions.get_android_lint_baseline_file(native.package_name()),
    }

def _set_plugins():
    return {
        # `$foo` is used to set `_foo`
        "$android_lint_plugins": registry_checks_for_package(LINT_REGISTRY, native.package_name()),
    }

androidlint_toolchains = struct(
    attrs = _ATTRS,
    get_baseline = lambda ctx: getattr(ctx.file, "_android_lint_baseline_file", None),
    get_plugins = lambda ctx: getattr(ctx.attr, "_android_lint_plugins", None),
    get_wrapper = lambda ctx: getattr(ctx.attr, "_android_lint_wrapper", None),
    set_baselines = _set_baselines,
    set_plugins = _set_plugins,
)
