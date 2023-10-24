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

"""kt_java_infos"""

load("//:visibility.bzl", "RULES_KOTLIN")

visibility(RULES_KOTLIN)

def _get_own_compile_jars(info):
    """Return the compile JARs specific to 'info', excluding exports, etc.

    Args:
        info: [JavaInfo]

    Returns:
        [list[JavaInfo]]
    """

    return [output.compile_jar for output in info.java_outputs if output.compile_jar]

kt_java_infos = struct(
    get_own_compile_jars = _get_own_compile_jars,
)
