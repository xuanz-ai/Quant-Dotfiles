#!/bin/bash
# EWW calendar popup data provider
# Outputs plain text calendar for the current month

month=$(date +'%-m')
year=$(date +'%Y')
today=$(date +'%-d')

first_dow=$(date -d "$year-$month-01" +%u)
dim=$(date -d "$year-$month-01 +1 month -1 day" +%d)

# Use 2 spaces between day names
# Header moved to static label in yuck

line=""
for ((i=1; i<first_dow; i++)); do
    line+="    "
done

for ((d=1; d<=dim; d++)); do
    dow=$(( (first_dow + d - 2) % 7 + 1 ))
    
    printf -v cell "%2d" $d
    line+="$cell"

    if [ $dow -eq 7 ] || [ $d -eq $dim ]; then
        echo "$line"
        line=""
    else
        line+="  "
    fi
done
exit 0
