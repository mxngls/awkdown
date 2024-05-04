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

BEGIN {}

# atx headings
/^ {0,3}#{1,6}([[:space:]]+|$)/{
  parse_atx($0)
  next
}

{
  print $0
}


END {}

# TODO
#
# 0. write a small test utility [ ]
#
# 1. parse headers [x]
#   - remove escape backslashes [ ]
#   - parse empty headings correctly [x]
