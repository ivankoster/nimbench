# Copyright 2016 Ivan Koster
#
# This file is based on Folly: Facebook Open-source Library
# Copyright 2015 Facebook, Inc.
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

## Introduction
## ============
## .. include:: doc/introduction.txt
##
## A quick example
## ===============
## .. include:: doc/quick_example.txt
##
## Platform support
## ================
## .. include:: doc/platform_support.txt

import strutils

import strfmt

import nimbench/private/utils
import nimbench/private/human_readable
import nimbench/private/timers

type
  BenchmarkSample = tuple[timeInNs: int64, iterations: Natural]
  BenchmarkFunction = proc(times: Natural): BenchmarkSample
  Benchmark = tuple[fileName, name: string, relative: bool,
                    function: BenchmarkFunction]

var benchmarks: seq[Benchmark]
benchmarks = @[]

proc addBenchmarkImpl(fileName, name: string, relative: bool,
                      function: BenchmarkFunction) =
  benchmarks.add((fileName: fileName, name: name, relative: relative,
                  function: function))

template benchImpl(relative: bool,
                   fileName, benchmarkName, cycles, body: untyped): untyped =
  proc execute(times: Natural): BenchmarkSample {.gensym.} =
    let numIterations = times
    result.iterations = numIterations
    let cycles = numIterations
    let startTicks = getTimeMeasurement()
    body
    result.timeInNs = getTimeMeasurement() - startTicks
  addBenchmarkImpl(fileName, benchmarkName, relative, execute)

template bench*(name, cycles, body: untyped): untyped =
  ## This template is used to create a benchmark. `name` is the name of the
  ## benchmark. `cycles` is a counter that must be used inside the code
  ## snippet. The framework uses this counter to indicate the number of
  ## iterations the code snippet must perform. For examples check `A quick
  ## example`_.
  let fileName = instantiationInfo(-1).filename
  let benchmarkName = stringifyIdentifier(name)
  benchImpl(false, fileName, benchmarkName, cycles, body)

template benchRelative*(name, cycles, body: untyped): untyped =
  ## The same as ``bench()``, except the previous ``bench()`` is taken as a
  ## baseline. Besides the time, the speedup of this benchmark, relative to the
  ## baseline, is also printed. This can be used to check how much faster your
  ## new implementation is. For example: 100% means just as fast, 200% means
  ## twice as fast. A value below 100% means your code got slower. A new
  ## baseline is created with every ``bench()``.
  let fileName = instantiationInfo(-1).filename
  let benchmarkName = stringifyIdentifier(name)
  benchImpl(true, fileName, benchmarkName, cycles, body)

template bench*(name, body: untyped): untyped =
  ## This template is used to create a benchmark. `name` is the name of the
  ## benchmark. For example:
  ##
  ## .. code-block:: nim
  ##  bench(fpOps4):
  ##    var d = 1.0
  ##    var x = float(5)
  ##    d = d + x
  ##    d = d - x
  ##    d = d * x
  ##    d = d / x
  ##    doNotOptimizeAway(d)
  ## It is advised if you have a loop in your benchmark, to use the other
  ## `bench()<#bench.t,untyped,untyped,untyped>`_ template, with the `cycles`
  ## parameter. This gives the module more control over the iterating and might
  ## produce better results.
  let fileName = instantiationInfo(-1).filename
  let benchmarkName = stringifyIdentifier(name)
  benchImpl(false, fileName, benchmarkName, m):
    var i = m
    while i > 0:
      dec(i)
      body

template benchRelative*(name, body: untyped): untyped =
  ## See `benchRelative()<#benchRelative.t,untyped,untyped,untyped>`_.
  let fileName = instantiationInfo(-1).filename
  let benchmarkName = stringifyIdentifier(name)
  benchImpl(true, fileName, benchmarkName, m):
    var i = m
    while i > 0:
      dec(i)
      body

{.compile: "nimbench/private/no_optimize.c".}
proc doNotOptimizeAway*[T](x: var T) {.importc, noDecl.} ## Use this proc on
  ## variables that are only used for the benchmark. The compiler will otherwise
  ## see that the variable is unused and optimize the code away.

template memoryClobber*() =
  ## Like ``doNotOptimizeAway()`` this template could come in handy when the
  ## compiler optimized too much code away. In general this template is not
  ## needed. If you think you might be in need, it is best to analyze assembly
  ## code with and without the call.
  when defined(vcc):
    proc memoryClobber() {.importc: "_ReadWriteBarrier", header: "intrin.h".}
    memoryClobber();
  else:
    {.emit: """
      asm volatile("" ::: "memory");
    """.}

proc runBenchmarkGetNsPerIteration(function: BenchmarkFunction,
                                   globalBaseline: float64): float64 =
  const
    minNanoseconds = 100_000
    maxEpochs = 1_000
    timeBudgetInNs = 1_000_000_000

  var epochSamples: seq[float64] = @[]

  let startTicks = getTimeMeasurement()
  for epochIndex in 0..<maxEpochs:
    for iterations in geometricSequence(1, 1 shl 30, 2):
      # We double the number of iterations 30 times as long as we don't get a
      # long enough measurement
      let benchSample = function(iterations)
      if benchSample.timeInNs < minNanoseconds:
        continue # we need a longer measurement to reduce noise
      let nsPerIteration = float64(benchSample.timeInNs) /
                           float64(benchSample.iterations) - globalBaseline
      epochSamples.add(max(0.0, nsPerIteration))
      break # We have a result for this epoch, continue on
    if(getTimeMeasurement() - startTicks) >= timeBudgetInNs:
      break # time budget exhausted for this benchmark
  # return the minimum, because it has the least amount of noise
  result = if len(epochSamples) == 0: 0.0 else: min(epochSamples)

bench(GlobalBenchmarkBaselineWithSillyObfuscatingTail):
  memoryClobber()

proc getGlobalBenchmarkBaselineIndex(): auto =
  let fileName = currentSourcePathShort()
  for i, b in benchmarks:
    if b.fileName == fileName and
       b.name == "GlobalBenchmarkBaselineWithSillyObfuscatingTail":
      return i
  raise newException(KeyError, "Could not find GlobalBenchmarkBaseline " &
                               "in the benchmark list!")

type BenchmarkResult = tuple[fileName, name: string, relative: bool,
                             timeInNs: float64]

proc printBenchmarkResults(data: openArray[BenchmarkResult])

proc runBenchmarks*() =
  ## Call this proc to run all the created benchmarks and print their results
  ## to stdout.
  var results: seq[BenchmarkResult] = @[]

  let
    baselineIndex = getGlobalBenchmarkBaselineIndex()
    globalBaseline = runBenchmarkGetNsPerIteration(
                      benchmarks[baselineIndex].function, 0.0)
  results.add(("GlobalBenchmark", "GlobalBenchmark", false, globalBaseline))
  # the globalBaseline measures how expensive iterating is, so we can subtract
  # it from the real benchmarks

  for i, b in benchmarks:
    if i == baselineIndex: continue
    let nsPerIteration = runBenchmarkGetNsPerIteration(b.function,
                                                       globalBaseline)
    results.add((b.fileName, b.name, b.relative, nsPerIteration))

  printBenchmarkResults(results)

proc printBenchmarkResults(data: openArray[BenchmarkResult]) =
  let width = 76
  let tail = "relative  time/iter  iters/s"

  proc separatingLine(padChar: char) =
    stdout.writeLine(padChar.repeat(width))

  proc header(fileName: string) =
    separatingLine('=')

    stdout.writeLine("{:<{}}{}".fmt(fileName, width-len(tail), tail))
    separatingLine('=')

  var
    lastFile = ""
    baselineNsPerIteration: float64 = Inf

  for record in data:
    let file = record.fileName
    if file != lastFile:
      header(file)
      lastFile = file
    let
      nsPerIteration = record.timeInNs
      secPerIteration = nsPerIteration / 1e9
      itersPerSec = if secPerIteration == 0.0: Inf else: (1.0 / secPerIteration)

    if record.relative:
      let relative = baselineNsPerIteration / nsPerIteration
      #printf("%*s %7.2f%%  %9s  %7s\n",
      stdout.writeLine("{0:<{1}.{1}} {2:>8.2%}  {3:>9.9}  {4:>7.7}".fmt(
        record.name, width-len(tail)-1, relative,
        readableTime(secPerIteration, 2), readableMetric(itersPerSec, 2)))
    else:
      baselineNsPerIteration = nsPerIteration
      stdout.writeLine("{0:<{1}.{1}}           {2:>9.9}  {3:>7.7}".fmt(
        record.name, width-len(tail)-1, readableTime(secPerIteration, 2),
        readableMetric(itersPerSec, 2)))
