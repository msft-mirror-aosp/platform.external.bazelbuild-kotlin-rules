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

"""Stubs"""

load("@bazel_skylib//lib:sets.bzl", "sets")

def register_extension_info(**_kwargs):
    pass

FORBIDDEN_DEP_PACKAGES = sets.make([])

EXEMPT_DEPS = sets.make([])

DEFAULT_BUILTIN_PROCESSORS = [
    "com.google.android.apps.play.store.plugins.injectionentrypoint.InjectionEntryPointProcessor",
    "com.google.android.apps.play.store.plugins.interfaceaggregator.InterfaceAggregationProcessor",
    "com.google.auto.factory.processor.AutoFactoryProcessor",
    "dagger.android.processor.AndroidProcessor",
    "dagger.internal.codegen.ComponentProcessor",
]

BASE_JVMOPTS = []

def select_java_language_version(**_kwargs):
    return "11"

def select_java_language_level(**_kwargs):
    return "11"
