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

function escape_quotes(s) {
  gsub(/"/, "\\&quot;", s)
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
  s = escape_quotes(s)
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

function push_delim(d, can_open, can_close, pos) {

    delims[delims_count] = d
    delims[delims_count, "can_open"] = can_open
    delims[delims_count, "can_close"] = can_close
    delims[delims_count, "pos"] = pos

    delims_count++

}

function pop_delim() {

  delete delims[delims_count]
  delete delims[delims_count, "can_open"]
  delete delims[delims_count, "can_close"]
  delete delims[delims_count, "pos"]

  delims_count--

}

function parse_emphasis(s, i, \
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

  # extract delimiters
  match(str, /^(\*|_)+/)
  del = substr(str, RSTART, RLENGTH)

  # retrieve value of previous and next character
  prev_char = i == 1 ? "\n" : substr(s, RSTART + RLENGTH - 1, 1)
  next_char = i == (length(s)) ? "\n" : substr(s, RSTART + RLENGTH + 1, 1)

  next_is_whitespace = match(next_char, /^[[:space:]]/);
  next_is_punctuation = match(next_char, /^[[:punct:]]/);
  prev_is_whitespace = match(prev_char, /^[[:space:]]/);
  prev_is_punctuation = match(prev_char, /^[[:punct:]]/);

  left_flanking = !next_is_whitespace && \
    (!next_is_punctuation || \
      prev_is_whitespace || \
      prev_is_punctuation);

  right_flanking = !prev_is_whitespace && \
    (!prev_is_punctuation || \
      next_is_whitespace || \
      next_is_punctuation);

  # determine if it is left- or right-flanking (or both)
  if (match(del, /^_+/)) {
    can_open = left_flanking && (!right_flanking || prev_is_punctuation);
    can_close = right_flanking && (!left_flanking || next_is_punctuation);
  } else {
      can_open = left_flanking;
      can_close = right_flanking;
  }

  match(str, /^(\*|_)+/)

  # if the delimiter stack is not empty we retrieve it's last element
  if (delims[delims_count - 1] && can_close) {
    if (length(delims[delims_count - 1]) % 2 != 0 || length(del) % 2 != 0) {


      pos = delims[delims_count - 1, "pos"]

      print i - pos - length(delims[delims_count - 1])

      inner = substr(s, pos + length(delims[delims_count - 1]), \
            i - pos - length(delims[delims_count - 1]))
      escape = 1

      print "inner: " inner
      print "pos: " pos

      # remove last element
      if (length(delims[delims_count - 1]) == 1) pop_delim()
      # or trim it by one 
      else {
        delims[delims_count - 1] = \
          substr(delims[delims_count - 1], 0, length(delims[delims_count - 1]) - 1)
      }

      del = length(del) > 1 ? substr(del, 0, 1) : ""

      print "del:", del

      if (del) {
        push_delim(del, can_open, can_close, i)
      }

      print "trail:", substr(s, i + length(del) + 1)

      return substr(s, 0, pos + length(delims[delims_count - 1]) - 1) "<em>" inner "</em>" parse_line(substr(s, i + length(del)))
    } else {
      pos = delims[delims_count - 1, "pos"]
      inner = substr(s, pos + length(delims[delims_count - 1]), \
            i - pos - length(delims[delims_count - 1]))
      escape = 1

      print "inner: " inner
      
      # remove last element
      if (length(delims[delims_count - 1]) == 2) pop_delim()
      # or trim it by one 
      else {
        delims[delims_count - 1] = \
          substr(delims[delims_count - 1], 0, length(delims[delims_count - 1]) - 2)
      }

      del = length(del) > 2 ? substr(del, 0, 2) : ""
      
      if (del) {
        push_delim(del, can_open, can_close, i)
      }

      return substr(s, 0, pos + length(delims[delims_count - 1]) - 3) "<strong>" inner "</strong>" parse_line(substr(s, i + length(del)))
    }
  }

  if (del) {
    push_delim(del, can_open, can_close, i)
  }

  # return everything including the delimiter run
  return substr(s, 0, i + length(del) - 1)
}

function parse_line(s,    res, i, t, p, em) {

  res = ""

  for (i = 1; i <= length(s); i++) {
    print "i: " i
    c = substr(s, i, 1);      # current char
    p = substr(s, 0, i-1);    # part of s until c
    t = substr(s, i);         # part of s from c on

    # parse inline code span
    if (c == "`") {
      res = res parse_code_span(t)

      i = length(res)
    } else if (c == "*" || c == "_") {

      res = parse_emphasis(res t, i)

      print "res:", res

      i = length(res)

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
  delims_count = 0
  delims[delims_count] = ""
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
