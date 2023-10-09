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

def _get_action(actions, mnemonic):
    """Get a specific action

    Args:
      actions: [List[Action]]
      mnemonic: [string] Identify the action whose args to search

    Returns:
      [Optional[action]] The arg value, or None if it couldn't be found
    """
    menmonic_actions = [a for a in actions if a.mnemonic == mnemonic]
    if len(menmonic_actions) == 0:
        return None
    elif len(menmonic_actions) > 1:
        fail("Expected a single '%s' action" % mnemonic)

    return menmonic_actions[0]

def _get_arg(action, arg_name, style = "trim"):
    """Get a named arg from a specific action

    Args:
      action: [Optional[Action]]
      arg_name: [string]
      style: ["trim"|"next"|"list"] The style of commandline arg

    Returns:
      [Optional[string]] The arg value, or None if it couldn't be found
    """
    if not action:
        return None

    args = action.argv
    matches = [(i, a) for (i, a) in enumerate(args) if a.startswith(arg_name)]
    if len(matches) == 0:
        return None
    elif len(matches) > 1:
        fail("Expected a single '%s' arg" % arg_name)
    (index, arg) = matches[0]

    if style == "trim":
        return arg[len(arg_name):]
    elif style == "next":
        return args[index + 1]
    elif style == "list":
        result = []
        for i in range(index + 1, len(args)):
            if args[i].startswith("--"):
                break
            result.append(args[i])
        return result

    else:
        fail("Unrecognized arg style '%s" % style)

kt_analysis = struct(
    # go/keep-sorted start
    get_action = _get_action,
    get_arg = _get_arg,
    # go/keep-sorted end
)
