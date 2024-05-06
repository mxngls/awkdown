#!/bin/bash

set -eu

# see https://git.sr.ht/~knazarov/markdown.awk/tree/master/item/test.sh
main() {
  input="$(mktemp)"
  expected_output="$(mktemp)"
  output="$(mktemp)"

  current="input"

  while IFS=$'\n' read -r line; do
    if [[ "$line" == "[END]"  ]]; then
      awk -f md.awk "$input" >> "$output"

      result="success"

      if ! cmp -s "$output" "$expected_output"; then
        printf "\n%s -> %s\n" "FAIL" "$description"
        echo "--- input"
        cat "$input"
        echo "--- expected"
        cat "$expected_output"
        echo "--- got"
        cat "$output"
        echo "---"
        result="fail"
      fi

      rm "$input"
      rm "$expected_output"
      rm "$output"

      if [[ "$result" == "fail" ]]; then
        exit 1
      fi

      current="input"
    elif [[ "$line" =~ ^\[.*\]$ ]]; then
      description="${line//[[\]]/}"
    elif [[ "$line" == "---" ]]; then
      current="output"
    elif [[ "$current" == "input" ]]; then
      echo "$line" >> "$input"
    elif [[ "$current" == "input" && "$line" == "" ]]; then
      continue
    else
      echo "$line" >> "$expected_output"
    fi
  done

  printf -- " -> All tests run sucessfull!\n"

}

main
