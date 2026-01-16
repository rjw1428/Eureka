#!/bin/bash
N=1
SIMPLE_FORMAT=false
REVERSE=false
while getopts "n:sr" opt; do
  case $opt in
    n)
      N=$OPTARG
      ;;
    s)
      SIMPLE_FORMAT=true
      ;;
    r)
      REVERSE=true
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

start="Suburban Station"
end="Somerton"

if [ "$REVERSE" = "true" ]; then
  temp=$start
  start=$end
  end=$temp
fi

safe_start="${start// /%20}"
safe_end="${end// /%20}"
url="http://www3.septa.org/api/NextToArrive/index.php?req1=${safe_start}&req2=${safe_end}"

echo "$start => $end"

sched=$(curl -X 'GET' $url -H 'accept: application/json' -s)
count=$(echo "$sched" | jq --argjson n "$N" '.[0:$n] | length')
i=0
echo "$sched" | jq -r --argjson n "$N" '.[0:$n] | .[] | "\(.orig_line)\t\(.orig_train)\t\(.orig_departure_time)\t\(.orig_arrival_time)\t\(.orig_delay)"' |

while IFS=$'\t' read -r line id dep arr late; do
  i=$((i+1))
  upper_line=$(echo "$line" | tr '[:lower:]' '[:upper:]')
  expected_arrival=$(date -j -f "%I:%M%p" $dep +"%I:%M%p")
  status=$late

  if [ "$late" != "On time" ]; then
    minutes=$(echo "$late" | cut -d' ' -f1)
    expected_arrival=$(date -j -f "%I:%M%p" -v+"$minutes"M "$dep" +"%I:%M%p")
    status=$(echo $late late)
  fi

  if [ "$SIMPLE_FORMAT" = "true" ]; then
    echo "Train: $expected_arrival ($status)"
  else
    echo "$upper_line Train ($id): $dep-$arr"
    echo "STATUS: $status"
    echo "EXPECTED: $expected_arrival"
    if [ "$i" -lt $count ]; then
      echo
    fi
  fi
done