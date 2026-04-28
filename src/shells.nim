import std/[os, macros, strutils]


macro importShells*(register: untyped): untyped =
  result = newStmtList()
  
  var modules: seq[string] = @[]
  let dir = currentSourcePath().splitFile().name
  
  for kind, path in walkDir("src/" & dir):
    if kind != pcFile or not path.endsWith(".nim"):
      continue

    let module = path.splitFile().name
    let modFullName = dir & "/" & module
    let modScript = newDotExpr(ident(module), ident("script"))

    modules.add(module)

    result.add quote do:
      import `modFullName`
      static: echo "imported: ", `modFullName`

    result.add newCall(register, newLit(module), modScript)

  result.add newConstStmt(ident("importedShells"), newLit(modules))
