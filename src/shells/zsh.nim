const script* = """
lazycli_query() {
  emulate -L zsh

  local line="$BUFFER"

  local trimmed
  trimmed="${line#"${line%%[![:space:]]*}"}"
  trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"

  if [[ -z $trimmed ]]; then
    return 0
  fi

  zle -R "Processing..."

  local result
  result=$({{lazycli}} query \
    --config={{config}} \
    --shell="zsh,$ZSH_VERSION" \
    -- "$line")

  result="${result#"${result%%[![:space:]]*}"}"
  result="${result%"${result##*[![:space:]]}"}"

  if [[ -z $result ]]; then
    zle reset-prompt
    return 0
  fi

  BUFFER="$result"
  CURSOR=${#BUFFER}

  zle reset-prompt
}

zle -N lazycli_query

bindkey "${terminfo[kf1]}" lazycli_query
"""
