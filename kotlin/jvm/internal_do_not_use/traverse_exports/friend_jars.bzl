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

"""kt_friend_jars_visitor"""

# go/keep-sorted start
load("//kotlin/common:is_eligible_friend.bzl", "is_eligible_friend")
load("//:visibility.bzl", "RULES_KOTLIN")
# go/keep-sorted end

def _get_output_jars(target, _ctx_rule):
    # We can't simply use `JavaInfo.compile_jars` because we only want the JARs directly created by
    # `target`, and not JARs from its `exports`
    return [output.compile_jar for output in target[JavaInfo].java_outputs if output.compile_jar]

kt_friend_jars_visitor = struct(
    name = "friend_jars",
    visit_target = _get_output_jars,
    filter_edge = is_eligible_friend,
    finish_expansion = None,
    process_unvisited_target = None,
)
