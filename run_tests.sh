#!/bin/bash

set -eu

for t in ./test/*.txt; do
  printf "%s" "$t"
  ./test.sh < "$t"
done
