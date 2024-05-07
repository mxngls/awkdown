#!/usr/bin/awk -f

function trim(s) {
  gsub(/^[[:blank:]]+|[[:blank:]]+$/, "", s)
  return s
}

function parse_atx(s) {
  s = trim(s)
  match(s,/^#+/) 

  # start of heading
  # end of heading
  # empty heading
  sub(/^#+[[:blank:]]+/, "", s)
  sub(/(([[:blank:]]+#+)?[[:blank:]]*$)/, "", s)
  sub(/^#+$/, "", s)

  text = s
  push_block("h" RLENGTH)
  pop_block()
}

function parse_setext(s) {
  if (match(s, /=+/)) level = 1;
  else level = 2;
  
  push_block("h" level)
}

function pop_block() {
  if (block == "code") {
    # trim trailing blank lines
    sub(/\n+$/,"", text)
    printf "<pre><code>%s\n</code></pre>\n", text;
  } else {
    printf "<%s>%s</%s>\n", block, trim(text), block;
  }

  push_block("p")
  text = ""
}

function push_block(nblock) {
  block = nblock
}

function append_text(s, t) {
  s = t ? trim(s) : s
  text = text ? text "\n" s : s 
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
/^[[:blank:]]{0,3}(-[-[:blank:]]+)|(=[=[:blank:]]+)/ {
  # setext headings require text
  if (!text);
  else if (block != "code") {
    parse_setext($0)
    pop_block()
    next
  } else {
    pop_block()
  }
}

# thematic breaks
/^[[:blank:]]{0,3}((\*[*[:blank:]]{2,})|(-[-[:blank:]]{2,})|(_[_[:blank:]]{2,}))$/ {
  if (text) pop_block()
  print "<hr />"
  next
}

# indented code block
/^[[:blank:]]{4,}/ {
  if (block == "code" || text == "") {
    sub(/^[[:blank:]]{4}/, "")
    push_block("code")
    append_text($0)
    next
  }
}

# blank lines
/^$/ {
  if (block == "code") append_text($0)
  else if (text) pop_block();
  next
}

# paragraphs
$0 {
  if (block == "code") pop_block()
  append_text($0, 1)
  next
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
