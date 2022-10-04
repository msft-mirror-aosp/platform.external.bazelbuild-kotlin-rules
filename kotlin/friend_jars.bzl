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

"""TODO: Write module docstring."""

def _is_eligible_friend(target, friend):
    """
    Determines if `target` is allowed to call `friend` a friend (and use its `internal` members).

    To be eligible, `target` must be one of:
      - in the parallel `java/` package from a `javatests/` package
      - in the parallel `main/java` package from a `test/java` package
      - another target in the same `BUILD` file

    Args:
      target: (target) The current target
      friend: (Target) A potential friend of `target`
    """

    target_pkg = target.label.package + "/"
    friend_pkg = friend.label.package + "/"

    if target_pkg == friend_pkg:
        # Allow friends on targets in the same package
        return True

    if "javatests/" in target_pkg and "java/" in friend_pkg:
        # Allow friends from javatests/ on the parallel java/ package
        target_java_pkg = target_pkg.rsplit("javatests/", 1)[1]
        friend_java_pkg = friend_pkg.rsplit("java/", 1)[1]
        if target_java_pkg == friend_java_pkg:
            return True

    if ("test/java/" in target_pkg and "main/java/" in friend_pkg and
        True):
        # Allow friends from test/java on the parallel main/java package
        target_split = target_pkg.rsplit("test/java/", 1)
        friend_split = friend_pkg.rsplit("main/java/", 1)
        if target_split == friend_split:
            return True

    return False

def _get_output_jars(target, _ctx_rule):
    # We can't simply use `JavaInfo.compile_jars` because we only want the JARs directly created by
    # `target`, and not JARs from its `exports`
    return [output.compile_jar for output in target[JavaInfo].java_outputs if output.compile_jar]

kt_friend_jars_visitor = struct(
    name = "friend_jars",
    visit_target = _get_output_jars,
    filter_edge = _is_eligible_friend,
    finish_expansion = None,
    process_unvisited_target = None,
)

def _get_output_labels(target, _):
    return [target.label]

kt_friend_labels_visitor = struct(
    name = "friend_labels",
    visit_target = _get_output_labels,
    filter_edge = _is_eligible_friend,
    finish_expansion = None,
    process_unvisited_target = None,
)
