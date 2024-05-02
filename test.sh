#!/bin/bash

set -eu

# see https://git.sr.ht/~knazarov/markdown.awk/tree/master/item/test.sh
main() {
  input="$(mktemp)"
  expected_output="$(mktemp)"
  output="$(mktemp)"

  current="input"

  while IFS=$'\n' read -r line; do
    if [[ "$line" == "---" ]]; then
      current="output"
    elif [[ "$current" == "input" ]]; then
      echo "$line" >> "$input"
    elif [[ "$line" == "" ]]; then
      awk -f md.awk "$input" >> "$output"

      result="success"

      if ! cmp -s "$output" "$expected_output"; then
        echo "FAIL"
        echo "--- input"
        cat "$input"
        echo
        echo "--- expected"
        cat "$expected_output"
        echo
        echo "--- got"
        cat "$output"
        echo
        echo "---"
        result="fail"
      else
        echo "SUCCESS"
      fi

      rm "$input"
      rm "$expected_output"
      rm "$output"

      if [[ "$result" == "fail" ]]; then
        exit 1
      fi

      current="input"
    else
      echo "$line" >> "$expected_output"
    fi
  done

}

main
