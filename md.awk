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

BEGIN { 
  ATX_REGEX_START = "(^[[:space:]]{0,3}#{1,6}([[:space:]]+|$))"
  ATX_REGEX_END   = "(([[:space:]]+#+)?[[:space:]]*$)"
  ATX_REGEX_EMPTY = "(^#+[[:space:]]*#+$)"
}

{
  s = $0;
  if(match(s, ATX_REGEX_START)) {

    s = trim(s)

    match(s,/^#+/) 

    gsub(ATX_REGEX_EMPTY "|" ATX_REGEX_START "|" ATX_REGEX_END, "", s)

    printf "<h%i>%s</h%i>\n", RLENGTH, s, RLENGTH
  } else {
    print $0
  }
}

END {}

# TODO
#
# 0. write a small test utility [ ]
#
# 1. parse headers [x]
#   - remove escape backslashes [ ]
#   - parse empty headings correctly [x]
