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

# This package tests importing extension functions.
load("@//kotlin:rules.bzl", "kt_jvm_import", "kt_jvm_library")

licenses(["notice"])  # Apache 2.0

kt_jvm_library(
    name = "car_demo_src_lib",
    srcs = ["CarDemo.kt"],
    deps = [
        "@//tests/jvm/java/functions/car:car_lib",
    ],
)

# This binary is built from source and shouldn't have any issues loading functions.
java_test(
    name = "car_src_demo",
    main_class = "functions.CarDemo",
    tags = ["darwin_x86_64_compatible"],
    runtime_deps = [
        ":car_demo_src_lib",
    ],
)

java_import(
    name = "car-jar",
    jars = ["@//tests/jvm/java/functions/car:car_lib-jar"],
)

kt_jvm_library(
    name = "car_demo_jar_lib",
    srcs = ["CarDemo.kt"],
    deps = [
        ":car-jar",
    ],
)

# This binary includes extension functions defined in an separate jar file, which
# may be problematic if the metadata is stripped by ijar.
java_test(
    name = "car_jar_demo",
    main_class = "functions.CarDemo",
    tags = ["darwin_x86_64_compatible"],
    runtime_deps = [
        ":car_demo_jar_lib",
        "@kotlinc//:kotlin_stdlib",
    ],
)

kt_jvm_import(
    name = "car-inline-jar",
    jars = [
        "@//tests/jvm/java/functions/car:car_inline_lib-jar",
        "@//tests/jvm/java/functions/car:car_extra_lib-jar",
    ],
    deps = [
        ":car-jar",
    ],
)

kt_jvm_library(
    name = "car_demo_inline_lib",
    srcs = ["CarInlineDemo.kt"],
    deps = [
        ":car-inline-jar",
        ":car-jar",
    ],
)

# This binary includes inline functions, imported from a jar file using kt_jvm_import.
# Inlined functions cannot be imported using java_import, since ijar strips out functionality.
java_test(
    name = "car_inline_demo",
    main_class = "functions.CarInlineDemo",
    tags = [
        "darwin_x86_64_compatible",
        "nozapfhahn",
    ],
    runtime_deps = [
        ":car_demo_inline_lib",
        "@kotlinc//:kotlin_stdlib",
    ],
)
