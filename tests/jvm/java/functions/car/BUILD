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

load("//kotlin:rules.bzl", "kt_jvm_library")

package(default_visibility = ["//tests/jvm/java/functions:__subpackages__"])

licenses(["notice"])

# Make Jar files produced by helper targets visible to tests in parent package
filegroup(
    name = "car_lib-jar",
    srcs = ["libcar_lib.jar"],
)

filegroup(
    name = "car_inline_lib-jar",
    srcs = ["libcar_inline_lib.jar"],
)

filegroup(
    name = "car_extra_lib-jar",
    srcs = ["libcar_extra_lib.jar"],
)

kt_jvm_library(
    name = "car_lib",
    srcs = [
        "Car.kt",
        "CarUtils.kt",
    ],
    deps = [
    ],
)

kt_jvm_library(
    name = "car_inline_lib",
    srcs = [
        "CarInlineUtils.kt",
    ],
    deps = [
        ":car_lib",
    ],
)

kt_jvm_library(
    name = "car_extra_lib",
    srcs = [
        "CarExtraUtils.kt",
    ],
    deps = [
        ":car_lib",
    ],
)
