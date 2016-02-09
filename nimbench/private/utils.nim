# Copyright 2016 Ivan Koster
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import macros

macro stringifyIdentifier*(n: untyped): string =
  result = newNimNode(nnkStmtList, n)
  result.add(toStrLit(n))

template currentSourcePathShort*: string = instantiationInfo(-1, false).filename

iterator geometricSequence*(start, stop, ratio: int): int =
  var result = start
  while result <= stop:
    yield result
    try:
      result = result * ratio
    except OverflowError:
      break