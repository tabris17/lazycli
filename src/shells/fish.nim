const script* = """
function lazycli_query
  set line (commandline)
  if test -z (string trim -- $line)
    return
  end

  printf "\r\e[2KProcessing..."

  set result (
    {{lazycli}} query \
      --config={{config}} \
      --shell="fish,$FISH_VERSION" \
      $line | string trim
  )

  if test -z "$result"
    return
  end

  commandline -f repaint
  commandline -r "$result"
end

bind -k f1 lazycli_query
"""
