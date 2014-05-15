#!/bin/bash
ls test_input_* > tmp3
while read line
do
./test.sh $line
done < tmp3
