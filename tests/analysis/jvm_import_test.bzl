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

"""Kotlin kt_jvm_import rule tests."""

load("//:visibility.bzl", "RULES_KOTLIN")
load("//kotlin/common/testing:testing_rules.bzl", "kt_testing_rules")
load("//kotlin/jvm/testing:for_analysis.bzl", ktfa = "kt_for_analysis")
load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

visibility(RULES_KOTLIN)

def _impl(ctx):
    env = analysistest.begin(ctx)
    asserts.true(
        env,
        JavaInfo in ctx.attr.target_under_test,
        "kt_jvm_import did not produce JavaInfo provider.",
    )
    asserts.true(
        env,
        ProguardSpecProvider in ctx.attr.target_under_test,
        "kt_jvm_import did not produce ProguardSpecProvider provider.",
    )
    return analysistest.end(env)

_test = analysistest.make(_impl)

def _test_kt_jvm_import():
    test_name = "kt_jvm_import_test"
    native.java_library(
        name = "jar1",
        srcs = [],
    )
    ktfa.kt_jvm_import(
        name = test_name + "_tut",
        jars = [
            "libjar1.jar",
        ],
        srcjar = "libjar1-src.jar",
    )
    _test(
        name = test_name,
        target_under_test = test_name + "_tut",
    )
    return test_name

def _test_kt_jvm_import_no_srcjar():
    test_name = "kt_jvm_import_no_srcjar_test"
    native.java_library(
        name = "jar3",
        srcs = [],
    )
    ktfa.kt_jvm_import(
        name = test_name + "_tut",
        jars = [
            "libjar3.jar",
        ],
            )
    _test(
        name = test_name,
        target_under_test = test_name + "_tut",
    )
    return test_name

def _test_kt_jvm_import_with_srcjar_ext():
    test_name = "kt_jvm_import_test_with_srcjar_ext"
    native.java_library(
        name = "jar2",
        srcs = [],
    )
    native.genrule(
        name = "gen_jar2_srcjar",
        cmd = "touch $@",
        outs = ["libjar2.srcjar"],
    )
    ktfa.kt_jvm_import(
        name = test_name + "_tut",
        jars = [
            "libjar2.jar",
        ],
        srcjar = ":libjar2.srcjar",
    )
    _test(
        name = test_name,
        target_under_test = test_name + "_tut",
    )
    return test_name

def _test_kt_jvm_import_with_runtime_deps():
    test_name = "kt_jvm_import_with_runtime_deps"
    native.java_library(
        name = test_name + "_dep",
        srcs = [],
    )
    ktfa.kt_jvm_import(
        name = test_name + "_tut",
        jars = [
            "lib%s_dep.jar" % test_name,
        ],
        runtime_deps = [
            test_name + "_dep",
        ],
    )
    _test(
        name = test_name,
        target_under_test = test_name + "_tut",
    )
    return test_name

def _test_kt_jvm_import_with_proguard_specs():
    test_name = "kt_jvm_import_with_proguard_specs"
    native.java_library(
        name = test_name + "_jar",
        srcs = [],
    )

    ktfa.kt_jvm_import(
        name = test_name + "_tut",
        jars = [
            "lib%s_jar.jar" % test_name,
        ],
        proguard_specs = [
            kt_testing_rules.create_file(
                name = test_name + "/salutations.pgcfg",
                content = """
-keep class * {
  *** greeting();
}
""",
            ),
        ],
    )
    _test(
        name = test_name,
        target_under_test = test_name + "_tut",
    )
    return test_name

def _mock_jar(test_name, i):
    """Creates a Jar named after the given inputs and returns its name."""
    native.java_library(
        name = "%s_mock%s" % (test_name, i),
        srcs = [],
    )
    return "lib%s_mock%s.jar" % (test_name, i)

def test_suite(name = None):
    native.test_suite(
        name = name,
        tests = [
            _test_kt_jvm_import(),
            _test_kt_jvm_import_with_srcjar_ext(),
            _test_kt_jvm_import_no_srcjar(),
            _test_kt_jvm_import_with_runtime_deps(),
            _test_kt_jvm_import_with_proguard_specs(),
        ],
    )
