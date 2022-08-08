#!/bin/bash -e
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

# DO NOT SET -x. It will leak any secret credentials into logs.

kokoro_scm_name="presubmit"
workspace_root="${KOKORO_ARTIFACTS_DIR}/git/${kokoro_scm_name}"

bazel="${KOKORO_GFILE_DIR}/bazel-${bazel_version}-linux-x86_64"
chmod +x "$bazel"

# Default JDK on GCP_UBUNTU is JDK8
sudo update-java-alternatives --set java-1.11.0-openjdk-amd64
# Bazel reads JAVA_HOME
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64/

# Create a tmpfs in the sandbox at "/tmp/hsperfdata_$USERNAME" to avoid the
# problems described in https://github.com/bazelbuild/bazel/issues/3236
# Basically, the JVM creates a file at /tmp/hsperfdata_$USERNAME/$PID, but
# processes all get a PID of 2 in the sandbox, so concurrent Java build actions
# could crash because they're trying to modify the same file. So, tell the
# sandbox to mount a tmpfs at /tmp/hsperfdata_$(whoami) so that each JVM gets
# its own version of that directory.
hsperfdata_dir="/tmp/hsperfdata_$(whoami)_rules_kotlin"
mkdir -p "$hsperfdata_dir"

cd "${workspace_root}"
"$bazel" test \
    --sandbox_tmpfs_path="$hsperfdata_dir" \
    --verbose_failures \
    --experimental_google_legacy_api \
    //tests/...

# Testing with code coverage
"$bazel" test \
    --sandbox_tmpfs_path="$hsperfdata_dir" \
    --verbose_failures \
    --experimental_google_legacy_api \
    --collect_code_coverage=1 \
    //tests/analysis:kt_jvm_compile_using_kt_jvm_compile_with_r_java_test \
    //tests/analysis:kt_jvm_compile_with_r_java_as_first_dep_test \
    //tests/analysis:kt_jvm_compile_without_srcs_and_with_exports_test