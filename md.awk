#!/usr/bin/awk -f

function l_trim(s) {
  sub(/^[[:space:]]+/, "", s)
  return s
}

function r_trim(s) {
  sub(/[[:space:]]+$/, "", s)
  return s
}

function trim(s) {
  s = l_trim(s)
  s = r_trim(s)
  return s
}

function parse_atx(s) {
  s = trim(s)
  match(s,/^#+/) 

  # start of heading
  # end of heading
  sub(/^#+[[:space:]]+/, "", s)
  sub(/(([[:space:]]+#+)?[[:space:]]*$)/, "", s)

  printf "<h%i>%s</h%i>\n", RLENGTH, s, RLENGTH
}

function pop_block() {
  printf "<p>%s</p>\n", block;
  block = ""
}

BEGIN {
  block = ""
}

# atx headings
/^ {0,3}#{1,6}([[:blank:]]+|$)/{
  if (block) pop_block()

  parse_atx($0)
  next
}

# thematic breaks
/^[[:blank:]]{0,3}((\*[*[:blank:]]{2,})|(-[-[:blank:]]{2,})|(_[_[:blank:]]{2,}))$/ {
  if (block) pop_block()

  print "<hr />"
  next
}

# paragraphs
$0 {
  if (!block) block = block trim($0);
  else block = block "\n" trim($0);
}

/^$/ {
  pop_block()
  next
}


END {
  if (block) pop_block()
}

# TODO
#
# 0. write a small test utility [ ]
#
# 1. parse headers [x]
#   - remove escape backslashes [ ]
#   - parse empty headings correctly [x]
