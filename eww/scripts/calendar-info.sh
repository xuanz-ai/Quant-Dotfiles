#!/bin/bash
# EWW calendar popup data provider
# Outputs pango-marked-up calendar for the current month

month=$(date +'%-m')
year=$(date +'%Y')
today=$(date +'%-d')

first_dow=$(date -d "$year-$month-01" +%u)
dim=$(date -d "$year-$month-01 +1 month -1 day" +%d)

echo "Mo Tu We Th Fr Sa Su"

line=""
for ((i=1; i<first_dow; i++)); do
    line+="    "
done

for ((d=1; d<=dim; d++)); do
    if [ $d -eq $today ]; then
        printf -v cell ' <span foreground="#89b4fa" weight="bold">%2d</span> ' $d
    else
        printf -v cell ' %2d ' $d
    fi
    line+="$cell"

    dow=$(( (first_dow + d - 2) % 7 + 1 ))
    if [ $dow -eq 7 ] || [ $d -eq $dim ]; then
        echo "$line"
        line=""
    fi
done

[ -n "$line" ] && echo "$line"
exit 0
