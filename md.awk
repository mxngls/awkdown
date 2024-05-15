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
  level = RLENGTH

  # start of heading
  # end of heading
  # empty heading
  sub(/^#+[[:blank:]]+/, "", s)
  sub(/(([[:blank:]]+#+)?[[:blank:]]*$)/, "", s)
  sub(/^#+$/, "", s)

  text = parse_line(s)
  push_block("h" level)
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

function parse_code_span(s,	  bs, r, t, tmp_r) {
  match(s, /^`+/)

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

  if (p) p = parse_line(p)
  if (t) t = parse_line(t)

  return sprintf("%s<code>%s</code>%s", p, trim_line_feed(r), t)
}

function push_delim(d, can_open, can_close, count, \
                    idx) {
  if (length(delims) == 1 && delims[0] == "") {
    delims[0] = d
    delims[0, "can_open"] = can_open
    delims[0, "can_close"] = can_close
    delims[0, "count"] = count
  } else {
    idx = length(delims)
    delims[idx] = d
    delims[idx, "can_open"] = can_open
    delims[idx, "can_close"] = can_close
    delims[idx, "count"] = count
  }
}

function pop_delim(idx) {
  idx = length(delims) - 1
  delete delims[idx]
  delete delims[idx, "can_open"]
  delete delims[idx, "can_close"]
  delete delims[idx, "count"]
}

function parse_emphasis(s, c, i, \
          curr_char, \
          prev_char, \
          next_char, \
          del, \
          after_is_whitespace, \
          after_is_punctuation, \
          before_is_whitespace, \
          before_is_punctuation, \
          left_flanking, \
          right_flanking, \
          can_open, \
          can_close) {

  # create substring
  str = substr(s, i)

  # extract delimiters and trailing text
  match(str, /^(\*|_)+/)
  del = substr(str, RSTART, RLENGTH)
  after = substr(str, RSTART + RLENGTH)

  curr_char = c
  prev_char = i == 1 ? "\n" : substr(s, i-1, 1)
  next_char = i == (length(s)) ? "\n" : substr(s, i+1, 1)

  next_is_whitespace = match(next_char, /^[[:space:]]/);
  next_is_punctuation = match(next_char, /^[[:punct:]]/);
  prev_is_whitespace = match(prev_char, /^[[:space:]]/);
  prev_is_punctuation = match(prev_char, /^[[:punct:]]/);

  # print "s          " s
  # print "length(s)  " length(s)
  # print "i          " i
  # print "c          " c
  # print "prev_char" prev_char
  # print "next_char " next_char
  # print "prev_char " prev_char "prev_is_whitespace  " prev_is_whitespace
  # print "prev_char " prev_char "prev_is_punctuation " prev_is_punctuation
  # print "next_char " next_char "next_is_whitespace   " next_is_whitespace
  # print "next_char " next_char "next_is_punctuation  " next_is_punctuation

  left_flanking = !next_is_whitespace && \
    (!next_is_punctuation || \
      prev_is_whitespace || \
      prev_is_punctuation);

  right_flanking = !prev_is_whitespace && \
    (!prev_is_punctuation || \
      next_is_whitespace || \
      next_is_punctuation);

  if (match(del, /^_+/)) {
    can_open = left_flanking && (!right_flanking || prev_is_punctuation);
    can_close = right_flanking && (!left_flanking || next_is_punctuation);
  } else {
      can_open = left_flanking;
      can_close = right_flanking;
  }

  if (length(delims) > 0 && can_close) {
  } else if (can_close && can_open || \
      can_close && !can_open || \
      !can_close && can_open) {
    push_delim(del, can_open, can_close, length(del))
  } else return parse_line(after)
}

function parse_line(s,    res, i, t, p) {
  
  res = ""

  for (i = 1; i <= length(s); i++) {
    c = substr(s, i, 1);      # current char
    p = substr(s, 0, i-1);    # part of s until c
    t = substr(s, i);         # part of s from c on

    # parse inline code span
    if (c == "`") {
      res = res parse_code_span(t)
      i = length(res)
    } else if (c == "*" || c == "_") {
      em = parse_emphasis(s, c, i)
      s = p em
      res = s
      i = i + length(em)

    } else {
      res = res c
    }

  }
  
  return res
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
  delims[0] = ""
}

1

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
