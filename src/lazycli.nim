import std/[cmdline, macros, rdstdin, strformat, strutils, tables, terminal]
import argparse
import ./backend
import ./config
import ./shells
import ./utils
import ./version


var shellScripts = initTable[string, string]()


importShells do (name: string, script: string):
  shellScripts[name] = script


const
  helpText = "print this help"
  shellHelp = "choices: " & importedShells.join(", ")
  configHelp = "specify the config file"
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
      flag("", "--posix-path", help="use posix path separators in the generated script")
      option("-c", "--config", help=configHelp)
      arg("shell", help=shellHelp)
    command("query"):
      help("Query command")
      nohelpflag()
      flag("-h", "--help", help=helpText, shortcircuit=true, hidden = true)
      option("-c", "--config", help=configHelp)
      option("-p", "--proxy", help="specify the proxy url (overrides config and environment variables)")
      option("-s", "--shell", help="specify the shell name and version", required=true)
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
        echo shellScripts[shell].render({
          "lazycli": if usePosixPath: getAppFilename().replace("\\", "/") else: getAppFilename(),
          "config": opts.config
        }.toTable)
      else:
        raise newException(ValueError, "Unsupported shell: " & shell)
    of "query":
      let opts = opts.query.get
      loadConfig(opts.config)
      if opts.proxy_opt.isSome:
        proxyUrl = opts.proxy
      let shellInfo = opts.shell.split(",", 2)
      if shellInfo.len < 2:
        raise newException(ValueError, "Parameter 'shell' must be in the format 'name,version'")
      config.set(shell, Shell(name: shellInfo[0], version: shellInfo[1]))
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
          echo "Config file initialized at: " & config.get(file)
        of "show":
          loadConfig(opts.config)
          printTable(20):
            "file": config.get(file)
            "version": config.get(version)
            "prompt": config.get(prompt)
            "proxy": config.get(proxy)
            "provider.name": config.get(provider).name
            "provider.base_url": config.get(provider).baseUrl
            "provider.api_key": config.get(provider).apiKey
            "provider.model": config.get(provider).model
        else:
          echo config.findFile(opts.config)
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
