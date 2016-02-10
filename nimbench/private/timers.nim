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

type
  TimeMeasurement = distinct int64
  NanoSeconds = int64

when defined(windows):
  proc QueryPerformanceCounter(res: var TimeMeasurement): int
    {. importc: "QueryPerformanceCounter", stdcall, dynlib: "kernel32".}
  proc QueryPerformanceFrequency(res: var int64): int
    {. importc: "QueryPerformanceFrequency", stdcall, dynlib: "kernel32".}

  var countsPerSec: int64
  # The frequency of the performance counter is fixed at system boot, cache it
  if QueryPerformanceFrequency(countsPerSec) == 0:
    raise newException(OSError, "QueryPerformanceFrequency failed")

  proc getTimeMeasurement*(): TimeMeasurement {.inline.} =
    let success = QueryPerformanceCounter(result)
    if success == 0:
      raise newException(OSError, "QueryPerformanceCounter failed")

  proc `-`*(a, b: TimeMeasurement): NanoSeconds =
    let counts = int64(a) - int64(b)
    # first multiple to prevent loss of precision
    result = counts * 1_000_000_000 div countsPerSec

else:
  {.fatal: "time measurement for this platform is not implemented yet!".}