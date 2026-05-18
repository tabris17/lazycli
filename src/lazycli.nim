import std/[cmdline, macros, rdstdin, strformat, strutils, tables, terminal]
import argparse
import lazycli/[backend, config, env, keybinding, shells, utils, version]


const
  helpText = "print this help"
  shellHelp = "choices: " & importedShells.join(", ")
  configHelp = "specify the config file"
  posixPathHelp = "use posix path separators in the generated script"
  proxyHelp = "specify the proxy url (overrides config and environment variables)"
  mainHelp = fmt"""Natural Language to Shell Commands
Name:     {appName}
Version:  {buildVersion}
Homepage: {homepage}"""


proc error(msg: string) {.inline.} = 
  setForegroundColor(fgRed)
  stderr.write "Error: "
  resetAttributes()
  stderr.writeLine msg


macro printTable(alignWidth: int, content: untyped): untyped =
  result = newStmtList()
  for kv in content:
    let key = kv[0]
    let val = kv[1]

    result.add quote do:
      setForegroundColor(fgCyan)
      stdout.write `key` & ":".alignLeft(`alignWidth` - `key`.len)
      resetAttributes()
      stdout.writeLine `val`


template tryReadLineFromStdin(prompt: string, default = ""): string =
  try: readLineFromStdin(prompt) except: default


let argParser = newParser(appName):
    help(mainHelp)
    nohelpflag()
    flag("-h", "--help", help=helpText, shortcircuit=true)
    flag("-v", "--version", help="print version and exit", shortcircuit=true)
    command("init"):
      help("Generate the shell init script")
      nohelpflag()
      flag("-h", "--help", help=helpText, shortcircuit=true, hidden = true)
      flag("", "--posix-path", help=posixPathHelp)
      option("-c", "--config", help=configHelp)
      option("-p", "--proxy", help=proxyHelp)
      arg("shell", help=shellHelp)
    command("query"):
      help("Query command")
      nohelpflag()
      flag("-h", "--help", help=helpText, shortcircuit=true, hidden = true)
      option("-c", "--config", help=configHelp)
      option("-p", "--proxy", help=proxyHelp)
      option("-s", "--shell", help="specify the shell name and version", required=true)
      flag("", "--posix-path", help=posixPathHelp)
      arg("text", help="Text to query")
    command("config"):
      help("Manage config")
      nohelpflag()
      flag("-h", "--help", help=helpText, shortcircuit=true, hidden = true)
      option("-c", "--config", help=configHelp)
      command("init"):
        help("Initialize config file")
        nohelpflag()
        flag("-h", "--help", help=helpText, shortcircuit=true, hidden = true)
        flag("", "--force", help="force overwrite existing config file")
      command("show"):
        help("Show all config values")
        nohelpflag()
        flag("-h", "--help", help=helpText, shortcircuit=true, hidden = true)


proc main() =
  let opts =
    try:
      argParser.parse(commandLineParams())
    except ShortCircuit as exc:
      case exc.flag:
        of "help", "argparse_help":
          echo exc.help
        of "version":
          echo buildVersion
        else:
          raise
      return

  case opts.command:
    of "init":
      let opts = opts.init.get
      let shell = opts.shell
      let usePosixPath = opts.posix_path
      if shell in importedShells:
        let shellDescriptor = shellRegistry[shell]
        loadConfig(opts.config)
        let (binPath, configPath, posixPath) =
          if usePosixPath:
            (getAppFilename().replace("\\", "/"), opts.config.replace("\\", "/"), "yes")
          else:
            (getAppFilename(), opts.config, "")
        echo shellDescriptor.initScript.render({
            "lazycli": binPath,
            "config": configPath,
            "proxy": opts.proxy,
            "posix_path": posixPath,
            "key": shellDescriptor.bindKey(getConfig(keyBinding)),
          }.toTable)
      else:
        raise newException(ValueError, "Unsupported shell: " & shell)
    of "query":
      let opts = opts.query.get
      loadConfig(opts.config)
      detectEnv()
      if opts.proxy_opt.isSome:
        setEnv(proxy, opts.proxy)
      let shellInfo = opts.shell.split(",", 2)
      if shellInfo.len < 2:
        raise newException(ValueError, "Parameter 'shell' must be in the format 'name,version'")
      setEnv(shell, Shell(name: shellInfo[0], version: shellInfo[1]))
      if opts.posix_path:
        setEnv(dirSep, '/')
      echo backend.query(opts.text)
    of "config":
      let opts = opts.config.get
      case opts.command:
        of "init":
          echo "Please enter LLM provider details"
          let provider = Provider(
            name: readLineFromStdin("name: "),
            baseUrl: readLineFromStdin("base url: "),
            apiKey: readLineFromStdin("api key: "),
            model: readLineFromStdin("model: ")
          )
          initConfig(opts.config, provider, opts.init.get.force)
          echo "Config file initialized at: " & getConfig(file)
        of "show":
          loadConfig(opts.config)
          printTable(20):
            "file": getConfig(file)
            "version": getConfig(version)
            "prompt": getConfig(prompt)
            "proxy": getConfig(proxy)
            "key_binding": $getConfig(keyBinding)
            "tools": getConfig(tools).join(", ")
            "provider.name": getConfig(provider).name
            "provider.base_url": getConfig(provider).baseUrl
            "provider.api_key": getConfig(provider).apiKey
            "provider.model": getConfig(provider).model
        else:
          echo findConfigFile(opts.config)
    else:
      echo argParser.help
      echo "Environments:"
      echo "  os\t\t" & getPlatform()
      echo "  user\t\t" & getUsername()
      echo "  pwd\t\t" & getCurrentDir()


when isMainModule:
  try:
    main()
  except CatchableError:
    error(getCurrentExceptionMsg())
    quit(QuitFailure)

  quit(QuitSuccess)
