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

"""FileFactory"""

def FileFactory(ctx, base, suffix = None):
    """Creates files with names derived from some base file

    Including the name of a rule is not always enough to guarantee unique filenames. For example,
    helper functions that declare their own output files may be called multiple times in the same
    rule impl.

    Args:
        ctx: ctx
        base: [File] The file to derive other filenames from
        suffix: [Optional[string]] An additional suffix to differentiate declared files

    Returns:
        FileFactory
    """

    base_name = base.basename.rsplit(".", 1)[0] + (suffix or "")

    def declare_directory(suffix):
        return ctx.actions.declare_directory(base_name + suffix, sibling = base)

    def declare_file(suffix):
        return ctx.actions.declare_file(base_name + suffix, sibling = base)

    def derive(suffix):
        return FileFactory(ctx, base, suffix)

    return struct(
        declare_directory = declare_directory,
        declare_file = declare_file,
        derive = derive,
    )
