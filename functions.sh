#
# Functions used by scripts
#


if [ -z "$loglevel" ]; then
  loglevel=4
fi

function upper () {
  echo "$1" | tr '[:lower:]' '[:upper:]'
}

function lower () {
  echo "$1" | tr '[:upper:]' '[:lower:]'
}

function trim () {
    echo "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

function err () {
   if [ $loglevel -gt 0 ]; then
     echo "[ERROR] $@" >&2
   fi
}

function warn () {
   if [ $loglevel -gt 1 ]; then
     echo "[WARNING] $@" >&2
   fi
}

function info () {
   if [ $loglevel -gt 2 ]; then
     echo "[INFO] $@" >&2
   fi
}

function debug () {
   if [ $loglevel -gt 3 ]; then
     echo "[DEBUG] $@" >&2
   fi
}

# ARG $1: a word or a string of whitespace separated words
# OUTPUT: Converts any string of words to captitalize first letter of each word
function fn_camel() {
  echo "$1" | awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1'
}

# ARG $1: takes a file with or without a path and generates a title
# OUTPUT: the title with camel hump notation
function fn_title() {
  local file=$(basename "$1")
  local no_ext_no_prefix=$(echo "$file" | sed -e 's/\.[^.]*$//' -e 's/^[0-9]*_//')
  local w_spaces=$(echo "$no_ext_no_prefix" | sed 's/-\|_/ /g')
  local camel=$(fn_camel "$w_spaces")
  echo "$camel"
}

# ARG $1: the title to generate the h1 header for
# OUTPUT: the two lined md/rst compat h1 header for the title:
#
# 'Test Header for Title'
# '====================='
#
function fn_header() {
  local title="$1"
  local num="$(echo ${#title})"
  v=$(printf "%-${num}s" "=")
  echo "$title"
  echo "${v// /=}"
}

# ARG $1: path to a file
# OUTPUT: status_enum[untracked|tracked|modified]
# SIDE-EFFECTS: removes untracked files, reverts modified files 
# .gitignore settings will impact results
function git_clean() {
  if [ -n "$(git status -s $1 | grep '^??')" ]; then
    debug "Deleting untracked (generated) file: $1"
    rm "$1"
  elif [ -n "$(git status -s $1 | grep ' M')" ]; then
    debug "Reverting modified tracked file = $1"
    git checkout "$1"
  else
    debug "Skipping git tracked file: $1"
  fi
}

function gdocs_clean() {
  debug 'Deleting all gdocs (docx files), you will need to download again.'
  find . -type f -regex '.*\.docx$' | xargs rm
}


