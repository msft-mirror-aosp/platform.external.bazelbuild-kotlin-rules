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

load("//:visibility.bzl", "RULES_KOTLIN")
load("//kotlin/common/testing:analysis.bzl", "kt_analysis")
load("//kotlin/common/testing:testing_rules.bzl", "kt_testing_rules")

visibility(RULES_KOTLIN)

# Mark targets that's aren't expected to build, but are needed for analysis test assertions.
ONLY_FOR_ANALYSIS_TEST_TAGS = kt_testing_rules.ONLY_FOR_ANALYSIS_TAGS

create_file = kt_testing_rules.create_file

create_dir = kt_testing_rules.create_dir

get_arg = kt_analysis.get_arg

get_action = kt_analysis.get_action
