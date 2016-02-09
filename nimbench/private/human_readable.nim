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

import math

import strfmt

type ScaleInfo = tuple[boundary: float64, suffix: string]

const scaleTime: array[0..9, ScaleInfo] = [
  ( 365.25 * 24.0 * 3600.0, "years" ),
  ( 24.0 * 3600.0, "days" ),
  ( 3600.0, "hr" ),
  ( 60.0, "min" ),
  ( 1.0, "s" ),
  ( 1E-3, "ms" ),
  ( 1E-6, "us" ),
  ( 1E-9, "ns" ),
  ( 1E-12, "ps" ),
  ( 1E-15, "fs" )]


const scaleMetric: array[0..16, ScaleInfo] = [
  ( 1E24, "Y" ),  # yotta
  ( 1E21, "Z" ),  # zetta
  ( 1E18, "X" ),  # "exa" written with suffix 'X' so as to not create
                  #   confusion with scientific notation
  ( 1E15, "P" ),  # peta
  ( 1E12, "T" ),  # terra
  ( 1E9, "G" ),   # giga
  ( 1E6, "M" ),   # mega
  ( 1E3, "K" ),   # kilo
  ( 1.0, "" ),
  ( 1E-3, "m" ),  # milli
  ( 1E-6, "u" ),  # micro
  ( 1E-9, "n" ),  # nano
  ( 1E-12, "p" ), # pico
  ( 1E-15, "f" ), # femto
  ( 1E-18, "a" ), # atto
  ( 1E-21, "z" ), # zepto
  ( 1E-24, "y" )] # yocto

proc humanReadable(number: float, decimals: Natural,
                   scale: openArray[ScaleInfo]): string =
  case classify(number):
  of fcNan, fcInf, fcNegInf:
    return $number
  else: discard

  let absoluteValue = abs(number)
  var i = 0
  while absoluteValue < scale[i].boundary and i < high(scale):
    inc(i)
  let scaledValue = number / scale[i].boundary
  result = "{:.{}f}{}".fmt(scaledValue, decimals, scale[i].suffix)


proc readableTime*(seconds: float, decimals: Natural): string =
  humanReadable(seconds, decimals, scaleTime)

proc readableMetric*(number: float, decimals: Natural): string =
  humanReadable(number, decimals, scaleMetric)
