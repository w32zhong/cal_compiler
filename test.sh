#!/bin/bash
./cal < $1
gcc output.c
while read line
do
	let "${line}"
done < $1

./a.out > tmp
> tmp2
while read line
do
	var=`echo "${line}" | awk '{ print tolower($1) }'`
	eval echo \"$var = \${$var}\" >> tmp2
done < tmp

echo "diff for $1:" >> diff
diff tmp tmp2 >> diff
rm -f tmp* a.out
