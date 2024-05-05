#!/usr/bin/awk -f

function l_trim(s) {
  sub(/^[[:blank:]]+/, "", s)
  return s
}

function r_trim(s) {
  sub(/[[:blank:]]+$/, "", s)
  return s
}

function trim(s) {
  gsub(/^[[:blank:]]+|[[:blank:]]+$/, "", s)
  return s
}

function parse_atx(s) {
  s = trim(s)
  match(s,/^#+/) 

  # start of heading
  # end of heading
  sub(/^#+[[:blank:]]+/, "", s)
  sub(/(([[:blank:]]+#+)?[[:blank:]]*$)/, "", s)

  text = s
  push_block("h" RLENGTH)
  pop_block()
}

function parse_setext(s) {
  if(match($0, /=+/)) level = 1;
  else level = 2;
  
  push_block("h" level)
}

function pop_block() {
  printf "<%s>%s</%s>\n", block, trim(text), block;
  block = "p"
  text = ""
}

function push_block(nblock) {
  block = nblock
}

BEGIN {
  text = ""
  block = "p"
}

# atx headings
/^ {0,3}#{1,6}([[:blank:]]+|$)/{
  if (text) pop_block()

  parse_atx($0)
  next
}

# setext headings
text && /^[[:blank:]]{0,3}(-[-[:blank:]]+)|(=[=[:blank:]]+)/ {
  parse_setext($0)
  next
}

# thematic breaks
/^[[:blank:]]{0,3}((\*[*[:blank:]]{2,})|(-[-[:blank:]]{2,})|(_[_[:blank:]]{2,}))$/ {
  if (text) pop_block()

  print "<hr />"
  next
}

# paragraphs
$0 {
  if (!text) text = text trim($0);
  else text = text "\n" trim($0);
  next
}

/^$/ {
  if (text) pop_block()
}

END {
  if (text) pop_block()
}

# TODO
#
# 0. write a small test utility [ ]
#
# 1. parse headers [x]
#   - remove escape backslashes [ ]
#   - parse empty headings correctly [x]
