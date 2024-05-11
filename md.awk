#!/usr/bin/awk -f

############################### HELPERS ###############################

function trim(s) {
  gsub(/^[[:blank:]]+|[[:blank:]]+$/, "", s)
  return s
}

function trim_line_feed(s) {
  gsub(/\n|\r\n|\r[^\n]/, "")
  return s
}

function escape_chrevron(s) {
  gsub(/</, "\\&lt;", s)
  gsub(/>/, "\\&gt;", s)
  return s
}

###################### HANDLERS FOR BLOCK & TEXT ######################

function pop_block() {
  if (block == "code") {
    # trim trailing blank lines
    sub(/\n+$/,"", text)

    # insert info string as language declaration
    if (info_string && match(info_string, /[^[:space:]]+[[:blank:]]*/)) {
      lang = substr(info_string, RSTART, RLENGTH)
      sub(/[[:blank:]]*$/, "", lang)
      printf "<pre><code class=\"language-%s\">%s%s</code></pre>\n",
             lang,
             text,
             text ? "\n" : "";
    } else printf "<pre><code>%s%s</code></pre>\n",
           text,
           text ? "\n" : "";
  } else {
    printf "<%s>%s</%s>\n", block, trim(text), block;
  }

  push_block("p")
  text = ""
}

function push_block(nblock) {
  block = nblock
}

function reset_block() {
  if (fence) {
    info_string = ""
    fence = ""
  }
  push_block("p")
}

function append_text(s, t) {

  if (fenced_space) {
    sub("^[[:blank:]]{1," fenced_space "}", "", s)
  } else {
    s = t && block != "code" ? trim(s) : s
  }

  s = !escape ? escape_chrevron(s) : s
  text = text ? text "\n" s : s

}

############################ BLOCK PARSERS ############################

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

function parse_fenced_block(s) {
  if (!fence) {
    # intercept paragraphs
    if (text) pop_block()

    # declare block
    block = "code"

    if (match(s, /^[[:blank:]]{1,3}/)) {
      fenced_space = RLENGTH
    }
    if (match(s, /[`]{3,}|[~]{3,}/)) {
      fence = substr(s, RSTART, RLENGTH)
      info_string = substr(s, RSTART + RLENGTH)
    }
    # info strings for backtick code blocks cannot contain backticks
    if (match(fence, /`/) && match(info_string, /`/)) {
      append_text(parse_code_span(s))
      reset_block()
    }

  } else {
    # make sure we found a valid closing fence
    match(s, /([`]{3,}|[~]{3,})$/)
    if (match(substr(s, RSTART, RLENGTH), fence)) {
      fence = ""
      pop_block()
    } else append_text(s)
  }
}

########################### INLINE PARSERS ############################

function parse_code_span(s) {

  bs = RLENGTH
  r = substr(s, RSTART + RLENGTH)
  p = substr(s, 0, RSTART - 1)

  # look if any matching backticks lie further down the current line
  while (bs > 0 && !match(r, "[^`][`]{" bs "}($|[^`]+.*$)")) {
    match(r, /`+/)

    bs = RLENGTH
    r = substr(r, RSTART + bs)
    p = substr(s, 0, RSTART)
  }

  # no matching backticks found -> not a valid code span
  if (bs < 1) return s

  # save rest of line
  tmp_r = r
  r = substr(r, 0, RSTART)
  t = substr(tmp_r, RSTART + bs + 1)

  # strip a single leading and trailing white sapce
  if (match(r, /^ .*[^[:space:]]+.* $/)) gsub(/^ | $/, "", r)

  # TODO: escaping still broken for links etc.
  escape = 1 

  return sprintf("%s<code>%s</code>%s", p, trim_line_feed(r), t)
}

function parse_line(s, t) {
  if (match(s, /`+/)) {
    s = parse_code_span(s)
  } 
  return s
}

############################ MAIN ROUTINE #############################

BEGIN {
  block = "p"
  span = ""
  escape = 0

  text = ""
  fence = ""
  fenced_space = 0
  info_string = ""
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
  if (block == "code" && !fence || text == "") {
    sub(/^[[:blank:]]{4}/, "")
    push_block("code")
    append_text($0)
    next
  }
}

# fenced code block
/^[[:blank:]]{0,3}([`]{3,}([[:blank:]]*[^`])?|[~]{3,}([[:blank:]]*[^~])?)/ {
  parse_fenced_block($0)
  next
}

# paragraphs
/^$/ {
  if (block == "code") append_text($0)
  else if (text) pop_block();
  next
}

# text
$0 {
  if (block == "code" && !fence) pop_block()

  s = parse_line($0)

  append_text(s, 1)

  next
}

END {
  if (text || block == "code") pop_block()
}
