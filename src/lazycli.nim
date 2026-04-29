import std/[cmdline, strformat, strutils, tables, terminal]
import argparse
import ./backend
import ./config
import ./shells
import ./version


var shellScripts = initTable[string, string]()


importShells do (name: string, script: string):
  shellScripts[name] = script


const
  helpText = "print this help"
  shellHelp = "choices: " & importedShells.join("\n")
  configHelp = "specify the config file"
  mainHelp = fmt"""Natural Language to Shell Commands
Name:     {appName}
Version:  {buildVersion}
Homepage: {homepage}"""


proc prompt(msg: string, default = ""): string {.inline.} =
  if default.len > 0:
    stdout.write(msg & " [" & default & "]: ")
  else:
    stdout.write(msg)
  stdout.flushFile()

  let input = stdin.readLine().strip()
  result = if input.len > 0: input else: default


proc error(msg: string) {.inline.} = 
  setForegroundColor(fgRed)
  stderr.write "Error: "
  resetAttributes()
  stderr.writeLine msg


let argParser = newParser(appName):
    help(mainHelp)
    nohelpflag()
    flag("-h", "--help", help=helpText, shortcircuit=true)
    flag("-v", "--version", help="print version and exit", shortcircuit=true)
    command("init"):
      help("Generate the shell init script")
      nohelpflag()
      flag("-h", "--help", help=helpText, shortcircuit=true, hidden = true)
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
      let shell = opts.init.get.shell
      if shell in importedShells:
        echo shellScripts[shell]
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
            name: prompt("name: "),
            baseUrl: prompt("base url: "),
            apiKey: prompt("api key: "),
            model: prompt("model: ")
          )
          initConfig(opts.config, provider, opts.init.get.force)
          echo "Config file initialized at: " & config.get(file)
        of "show":
          loadConfig(opts.config)
          echo "Config file: ", config.get(file)
          echo "version: " & config.get(version)
          echo "proxy: " & config.get(proxy)
          echo "provider.name: " & config.get(provider).name
          echo "provider.base_url: " & config.get(provider).baseUrl
          echo "provider.api_key: " & config.get(provider).apiKey
          echo "provider.model: " & config.get(provider).model
        else:
          echo config.findFile(opts.config)
    else:
      echo argParser.help


when isMainModule:
  try:
    main()
  except CatchableError:
    error(getCurrentExceptionMsg())
    quit(QuitFailure)

  quit(QuitSuccess)
