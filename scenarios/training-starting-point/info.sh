#!/usr/bin/env bash

# Colors
end="\033[0m"
greenb="\033[1;32m"

function print_info {
  echo -e "${greenb}${1}${end}"
}

print_info "the starting point is a running management plane, t1, plus two clusters (c1 and c2) which remain to be onboarded"
