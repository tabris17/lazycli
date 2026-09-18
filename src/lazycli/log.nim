import std/[strutils, terminal]


proc error*(msg: string) {.inline.} =
  setForegroundColor(fgRed)
  stderr.write "Error: "
  resetAttributes()
  stderr.writeLine msg


proc debug*(msg: string, context: string = "") {.inline.} =
  setForegroundColor(fgGreen)
  stderr.write "Debug: "
  resetAttributes()
  stderr.writeLine msg
  setForegroundColor(fgCyan)
  if context.len > 0:
    for line in context.splitLines():
      stderr.writeLine "  ", line
  resetAttributes()
