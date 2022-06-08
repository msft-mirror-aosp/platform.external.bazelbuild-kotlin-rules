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

"""Some utils"""

# Mark targets that's aren't expected to build, but are needed for analysis test assertions.
ONLY_FOR_ANALYSIS_TEST_TAGS = ["manual", "nobuilder", "only_for_analysis_test"]

def create_file(name, content):
    native.genrule(
        name = "gen_" + name,
        outs = [name],
        cmd = """
cat > $@ <<EOF
%s
EOF
""" % content.split("\n", 1)[1],
    )

    return name

def get_action_arg(actions, mnemonic, arg_name):
    """Get a named arg from a specific action

    Args:
      actions: [List[Action]]
      mnemonic: [string] Identify the action whose args to search
      arg_name: [string]

    Returns:
      [Optional[string]] The arg value, or None if it couldn't be found
    """
    menmonic_actions = [a for a in actions if a.mnemonic == mnemonic]
    if len(menmonic_actions) == 0:
        return None
    elif len(menmonic_actions) > 1:
        fail("Expected a single '%s' action" % mnemonic)

    mnemonic_action = menmonic_actions[0]
    arg_values = [a for a in mnemonic_action.argv if a.startswith(arg_name)]
    if len(arg_values) == 0:
        return None
    elif len(arg_values) > 1:
        fail("Expected a single '%s' arg" % arg_name)

    return arg_values[0][len(arg_name):]
