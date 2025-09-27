#!/bin/bash
# DNS-style resolver for Ashley

# 1) exactly one argument required
if [ "$#" -ne 1 ]; then
  echo "Please provide exactly 1 argument!"
  exit 1
fi
code="$1"

# 2) find the unique marker <CODE>.addr exactly one level down
shopt -s nullglob
matches=(*/"$code.addr")
if [ "${#matches[@]}" -ne 1 ]; then
  echo "Confused..." >&2
  exit 2
fi
folder="${matches[0]%/$code.addr}"   # drop '/<code>.addr'
folder="${folder%/}"                 # drop trailing slash
folder="$(basename "$folder")"       # keep only subdir name: Luis|Ada|Wesker|Grace

# 3) follow referrals, stop on FOUND or after asking everyone / loop
asked=""           # comma-separated list to detect loops
asked_count=0

while :; do
  case ",$asked," in
    *,"$folder",*) ;;                          # already counted
    *) asked="${asked}${folder},"; asked_count=$((asked_count+1));;
  esac

  # lookup in table.tsv (first column is code, second is absolute path)
  addr="$(awk -v c="$code" '$1==c {print $2; exit}' "$folder/table.tsv" 2>/dev/null)"
  if [ -n "$addr" ]; then
    echo "FOUND $code from $folder -> $addr"
    exit 0
  fi

  # read next hop; trim potential CR
  if [ ! -f "$folder/next.txt" ]; then
    echo "NOTFOUND $code"
    exit 0
  fi
  read -r next < "$folder/next.txt"
  next="${next%$'\r'}"

  # stop if empty, already asked, or we've already asked all four
  if [ -z "$next" ] || [[ ",$asked," == *,"$next",* ]] || [ "$asked_count" -ge 4 ]; then
    echo "NOTFOUND $code"
    exit 0
  fi

  folder="$next"
done
