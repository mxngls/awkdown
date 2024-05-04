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
  sub(/^[[:space:]]+|[[:space:]]+$/, "", s)
  return s
}

function parse_atx(s) {
  match(trim(s),/^#+/) 

  # Empty Heading | Start of Heading | End of Heading
  gsub(/(^#+ *#+$)|(^ {0,3}#{1,6}( +|$))|(( +#+)? *$)/,"", s)

  printf "<h%i>%s</h%i>\n", RLENGTH, s, RLENGTH
}

BEGIN {}

/^ {0,3}#{1,6}( +|$)/{
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
