import strformat

# Package

version       = "0.1.0"
author        = "fournoas"
description   = "Natural Language to Shell Commands"
license       = "MIT"
srcDir        = "src"
bin           = @["lazycli"]
binDir        = "bin"

# Dependencies

requires "nim >= 2.2.8"
requires "parsetoml >= 0.7.2"
requires "argparse >= 4.0.2"

# Tasks

task release, "Build release version":
  for b in bin:
    exec fmt"nim c -d:release -d:NimblePkgVersion:{version} -o:{binDir}/{b} {srcDir}/{b}.nim"
