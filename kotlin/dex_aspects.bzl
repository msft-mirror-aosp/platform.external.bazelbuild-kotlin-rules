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

"""kt_dex_aspects"""

# (b/259111128) Magic provider to get DexArchiveAspect to traverse into this rule
_TraverseMeInfo = platform_common.ToolchainInfo

_EXTRA_DEPS_ATTRS = dict(
    _build_stamp_deps = attr.label_list(
        doc = """
            (b/259111128) Magic attr to get DexArchiveAspect to traverse into this rule
        """,
    ),
)

def _set_extra_deps_attrs(deps):
    return {"$build_stamp_deps": deps}

kt_dex_aspects = struct(
    TraverseMeInfo = _TraverseMeInfo,
    TRAVERSE_ME_INFO = _TraverseMeInfo(),
    extra_deps_attrs = _EXTRA_DEPS_ATTRS,
    set_extra_deps_attrs = _set_extra_deps_attrs,
)
