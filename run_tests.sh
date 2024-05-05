#!/bin/bash

set -eu

for t in ./test/*.txt; do
  echo "$t"
  ./test.sh < "$t"
  echo
done
