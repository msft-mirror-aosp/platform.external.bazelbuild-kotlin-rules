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

"""An assertion for analysis failure."""

load("//:visibility.bzl", "RULES_KOTLIN")
load("//kotlin/common/testing:testing_rules.bzl", "kt_testing_rules")

visibility(RULES_KOTLIN)

assert_failure_test = kt_testing_rules.assert_failure_test
