const script* = """
def query_lazycli [] {
  let ver = (version).version
  let line = (commandline)
  if ($line | str trim | is-empty) {
    return
  }
  print -n "\r\e[2KProcessing..."

  let result = (
    {{lazycli}} query --config={{config}} --shell=$'nushell,($ver)' $line |
    str trim
  )
  if ($result | is-empty) {
    return
  }

  commandline edit --replace $result
}

$env.config.keybindings ++= [
  {
    name: lazycli
    modifier: none
    keycode: f1
    mode: emacs
    event: {
      send: executehostcommand
      cmd: "query_lazycli"
    }
  }
]
"""
