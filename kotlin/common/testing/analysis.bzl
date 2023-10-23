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

"""kt_analysis"""

load("//:visibility.bzl", "RULES_KOTLIN")
load("@bazel_skylib//lib:unittest.bzl", "analysistest")

visibility(RULES_KOTLIN)

def _get_action(actions, mnemonic):
    """Get a specific action

    Args:
        actions: [List[Action]]
        mnemonic: [string] Identify the action whose args to search

    Returns:
        [Action|None] The arg value, or None if it couldn't be found
    """
    menmonic_actions = [a for a in actions if a.mnemonic == mnemonic]
    if len(menmonic_actions) == 0:
        return None
    elif len(menmonic_actions) > 1:
        fail("Expected a single '%s' action" % mnemonic)

    return menmonic_actions[0]

def _get_all_args(action, arg_name, style = "trim"):
    """Gets values for all instances of an arg name from a specific action.

    Args:
        action: [Action|None]
        arg_name: [string]
        style: ["trim"|"next"|"list"] The style of commandline arg

    Returns:
        [list[string]|list[list[string]]|None] The list of matching arg values
    """
    if not action:
        return []

    args = action.argv
    matches = [(i, a) for (i, a) in enumerate(args) if a.startswith(arg_name)]

    result = []
    for index, arg in matches:
        if style == "trim":
            result.append(arg[len(arg_name):])
        elif style == "next":
            result.append(args[index + 1])
        elif style == "list":
            sub_result = []
            for i in range(index + 1, len(args)):
                if args[i].startswith("--"):
                    break
                sub_result.append(args[i])
            result.append(sub_result)
        else:
            fail("Unrecognized arg style '%s" % style)

    return result

def _get_arg(action, arg_name, style = "trim"):
    """Gets values for exactly one instance of an arg name from a specific action.

    Args:
        action: [Action|None]
        arg_name: [string]
        style: ["trim"|"next"|"list"] The style of commandline arg

    Returns:
        [string|list[string]|None] The arg value, or None if it couldn't be found
    """
    results = _get_all_args(action, arg_name, style)

    if len(results) == 0:
        return None
    elif len(results) == 1:
        return results[0]
    else:
        fail("Expected a single '%s' arg" % arg_name)

def _begin_with_checks(ctx):
    """Begin an analysis test and run some rules_kotlin-specific checks.

    Args:
        ctx: [ctx]

    Returns:
        [analysistests.env]
    """

    env = analysistest.begin(ctx)

    tut_name = analysistest.target_under_test(env).label.name
    if ctx.label.name != tut_name + "_test":
        fail("Analysis test name was '%s', expected '%s_test'" % (ctx.label.name, tut_name))

    return env

kt_analysis = struct(
    # go/keep-sorted start
    DEFAULT_LIST = ["__default__"],
    begin_with_checks = _begin_with_checks,
    get_action = _get_action,
    get_all_args = _get_all_args,
    get_arg = _get_arg,
    # go/keep-sorted end
)
