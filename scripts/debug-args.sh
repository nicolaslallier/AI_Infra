#!/bin/bash

echo "Number of arguments: $#"
echo ""
echo "All arguments as one string: $@"
echo ""
echo "Individual arguments:"
i=1
for arg in "$@"; do
  echo "  Arg $i: [$arg] (length: ${#arg})"
  echo "  Hex dump:"
  echo -n "  "
  echo "$arg" | od -An -tx1
  i=$((i+1))
done

