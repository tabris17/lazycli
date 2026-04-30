const script* = """
lazycli_query() {
  local line="$READLINE_LINE"

  if [[ -z "${line//[[:space:]]/}" ]]; then
    return
  fi

  printf "\r\033[2KProcessing...\r"

  local result
  result=$(
    {{lazycli}} query \
      --config={{config}} \
      --shell="bash,$BASH_VERSION" \
      "$line" | xargs
  )

  if [[ -z "$result" ]]; then
    return
  fi

  READLINE_LINE="$result"
  READLINE_POINT=${#READLINE_LINE}
}

bind -x '"\eOP":lazycli_query'
"""
