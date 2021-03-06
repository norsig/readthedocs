#
# Functions used by scripts
#

if [ -z "$loglevel" ]; then
  loglevel=4
fi

function urlencode() {
  echo "$@" | sed 's/ /%20/g;s/!/%21/g;s/"/%22/g;s/#/%23/g;s/\$/%24/g;s/\&/%26/g
;s/'\''/%27/g;s/(/%28/g;s/)/%29/g;s/:/%3A/g;s/\?/%3F/g'
}

function pushd() {
    command pushd "$@" > /dev/null
}

function popd() {
    command popd "$@" > /dev/null
}

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
  local in_file="$1"

  if [ ! -f "$in_file" ]; then
    err "File '$in_file' does not exist!"
    return
  fi
  
  local untracked=$(git status -s "$in_file" | grep '^??')
  local modified=$(git status -s "$in_file" | grep ' M')

  if [ -n "$untracked" ]; then
    debug "Deleting untracked (generated) file: $in_file"
    rm -f "$in_file"
  elif [ -n "$modified" ]; then
    debug "Reverting modified tracked file = $in_file"
    git checkout "$in_file"
  else
    debug "Skipping git tracked file: $in_file"
  fi
}

function gdocs_clean() {
  debug 'Deleting all gdocs (docx files), you will need to download again.'
  find . -type f -regex '.*\.docx$' | xargs rm
}

function dl_file() {
  local id="$1"

  gdrive 'export' --force --mime 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' $id
}

function dl_dir() {
  local parent_id="$1"
  local query="trashed = false and '""$parent_id""' in parents"
  local name=''
  local id=''
  local typ=''
  

  # i.e. gdrive list -m 100 -q "'1GcnXGM23mCaPHBkI7l9O1gn_AEquxgyq' in parents"
  while read line; do
    OIFS=$IFS
    IFS=' '
    read id name typ date1 date2 <<< "$line"
    IFS=$OIFS

    pushd .
    echo "[DEBUG] PWD = $PWD, id = $id, name = $name, typ = $typ"

    if [ "$typ" != "dir" ]; then
      dl_file "$id"
      echo "[DEBUG] Finished downloading file $name"
    else
      if [ ! -d "$name" ]; then
        mkdir -p "$name"
      fi

      echo "[DEBUG] Entering directory $name"
      cd $name
      dl_dir "$id" "$name"
      echo "[DEBUG] Done processing directory $name"
    fi
    popd

  done < <(gdrive list --no-header -m 1000 -q "$query")

}

function query() {
  local parent="$1"
  echo "trashed = false and 'me' in readers and '"$parent"' in parents"
}

resource_cfunc="convert_w2m_pandoc"
products_cfunc="convert_docx_pandoc_md_pandoc_rst"
projects_cfunc="convert_md_pandoc_rst"
toplevel_cfunc="convert_docx_pandoc_md_pandoc_rst"

function convert_md_pandoc_rst() {
  local mdfile="$1"
  local rstfile="$(echo $gdocfile | sed -e 's/\.docx$/\.rst/')"
  local title="$(fn_title $rstfile)"
  
  fn_header "$title" > $rstfile
  pandoc --from markdown --to rst "$mdfile" -o "$rstfile.tmp"
  cat "$rstfile.tmp" >> "$rstfile"
  rm "$rstfile.tmp"
  echo "$rstfile"
}

# 100 Warnings
# Best results: headings and links all render perfectly (About Page)
function convert_docx_pandoc_md_pandoc_rst() {
  local gdocfile="$1"
  local parent_dir="$(dirname "$1")"
  local mdfile="$(echo $gdocfile | sed -e 's/\.docx$/\.md/')"
  local rstfile="$(echo $gdocfile | sed -e 's/\.docx$/\.rst/')"
  local title="$(fn_title $rstfile)"
  
  fn_header "$title" > $rstfile
  debug "Parent of $gdocfile is $parent_dir"
  
  pushd . 
  cd $parent_dir
  pandoc -s --from docx --to markdown --extract-media="." "$gdocfile" -o "$mdfile"
  popd

  pandoc --from markdown --to rst "$mdfile" -o "$rstfile.tmp"
  cat "$rstfile.tmp" >> "$rstfile"
  rm "$rstfile.tmp"
  echo "$rstfile"
}

# 111 Warnings
# Headings function correctly (About Page)
function convert_docx_pandoc_rst() {
  local gdocfile="$1"
  local rstfile="$(echo $gdocfile | sed -e 's/\.docx$/\.rst/')"
  local title="$(fn_title $rstfile)"
  
  fn_header "$title" > $rstfile
  pandoc --from docx --to rst "$gdocfile" -o "$rstfile.tmp"
  cat "$rstfile.tmp" >> "$rstfile"
  rm "$rstfile.tmp"
  echo "$rstfile"
}


# 99 Warnings
# Some headings not showing up properly (About Page) 
function convert_docx_w2m_md_pandoc_rst() {
  local gdocfile="$1"
  local mdfile="$(echo $gdocfile | sed -e 's/\.docx$/\.md/')"
  local rstfile="$(echo $gdocfile | sed -e 's/\.docx$/\.rst/')"
  local title="$(fn_title $rstfile)"
  
  fn_header "$title" > "$rstfile"
  w2m "$gdocfile" > "$mdfile"
  pandoc --from markdown --to rst "$mdfile" -o "$rstfile.tmp"
  cat "$rstfile.tmp" >> "$rstfile"
  rm "$rstfile.tmp"
  echo "$rstfile"
}

