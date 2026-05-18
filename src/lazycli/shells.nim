import std/[os, macros, strutils, tables]
import lazycli/keybinding


type
  BindKeyProc = proc (keyBinding: KeyBinding): string

  ShellDescriptor = object
    initScript*: string
    bindKey*: BindKeyProc


var shellRegistry* = initTable[string, ShellDescriptor]()


macro importShells(register: untyped): untyped =
  result = newStmtList()
  
  var modules: seq[string] = @[]
  let dir = currentSourcePath().splitFile().name
  
  for kind, path in walkDir("src/" & dir):
    if kind != pcFile or not path.endsWith(".nim"):
      continue

    let module = path.splitFile().name
    let modFullName = dir & "/" & module
    let modInitScript = newDotExpr(ident(module), ident("initScript"))
    let modBindKey = newDotExpr(ident(module), ident("bindKey"))

    modules.add(module)

    result.add quote do:
      import `modFullName`
      static: echo "imported: ", `modFullName`

    result.add newCall(register, newLit(module), modInitScript, modBindKey)

  result.add newConstStmt(
    nnkPostfix.newTree(ident("*"), ident("importedShells")), 
    newLit(modules)
  )


importShells do (name: string, initScript: string, bindKey: BindKeyProc):
  shellRegistry[name] = ShellDescriptor(
    initScript: initScript,
    bindKey: bindKey
  )
