#!/usr/bin/env bash
set -x
set -eo pipefail
[[ "${DEBUG:-}" ]] && set -x

success() {
  printf "\r\033[2K  [ \033[00;32mOK\033[0m ] Linting %s...\n" "$1"
}

fail() {
  printf "\r\033[2K  [\033[0;31mFAIL\033[0m] Linting %s...\n" "$1"
  exit 1
}

check() {
  local script="$1"
  shellcheck "$script" || fail "$script"
  success "$script"
}

find_prunes() {
  local prunes="! -path './.git/*'"
  if [ -f .gitmodules ]; then
    while read module; do
      prunes="$prunes ! -path './$module/*'"
    done < <(grep path .gitmodules | awk '{print $3}')
  fi
  echo "$prunes"
}

find_cmd() {
  echo "find . -type f -and -perm +111 -and -name '*.sh' $(find_prunes)"
}

check_all_executables() {
  echo "Linting all executables and .sh files, ignoring files inside git modules..."
  eval "$(find_cmd)" | while read script; do
  head=$(head -n1 "$script")
  [[ "$head" =~ .*ruby.* ]] && continue
  [[ "$head" =~ .*zsh.* ]] && continue
  [[ "$head" =~ ^#compdef.* ]] && continue
  check "$script"
done
}

check_commited_files() {
  echo "Checking *sh scripts in current commit"
  files_in_commit=($(git diff --cached --name-status --diff-filter=ACM | awk '{print $2}') )
  for file in "${files_in_commit[@]}"; do
    [ -f "$file" ] &&  
    head -n 1 "$file" | grep -q "sh" &&
    [ $? -eq 0 ] && 
    check "$file" || echo "$file is not *.sh script - commited" 
  done
}

[[ ! $1 ]] && check_all_executables && exit 0

while getopts ":c" OPT
do
  case $OPT in
    c ) check_commited_files ;;
    \? ) "Unrecognized operator -$OPTARG" >&2
      exit 1
      ;;
  esac
done
