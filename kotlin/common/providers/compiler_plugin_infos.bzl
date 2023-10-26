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

"""kt_compiler_plugin_infos"""

load("//:visibility.bzl", "RULES_KOTLIN")

visibility(RULES_KOTLIN)

_KtCompilerPluginInfo, _private_ctor = provider(
    doc = "Info for running a plugin that directly registers itself to kotlinc extension points",
    fields = dict(
        plugin_id = "string",
        jar = "File",
        args = "list[string]",
    ),
    init = fail,
)

kt_compiler_plugin_infos = struct(
    Info = _KtCompilerPluginInfo,
    private_ctor = _private_ctor,
)
