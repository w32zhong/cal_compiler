#!/bin/bash
./cal < test_input_general > tmp
echo 1
cat tmp | grep -m 1 mem
echo 2
cat tmp | grep -m 1 lucky
echo 3
cat tmp | grep -m 1 "no luck"
echo 4
cat tmp | grep cycle\(s\)
echo 5
cat tmp | grep -m 1 Copy 
echo 6
cat tmp | grep -m 1 Common
rm tmp
