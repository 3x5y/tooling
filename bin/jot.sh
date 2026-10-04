#!/bin/bash

set -eu

dir=~/z/admin/jot
stamp=$(date +%Y%m%d)
file=$dir/$stamp.txt
time=$(date +%H:%M)
args=(-c 'norm o' -c "norm o$time" -c 'norm o')

if ! [ -d $dir ]
then
  mkdir -pv $dir
fi

if [ -f $file ]
then
	first='norm G'
else
	date=$(date +%Y-%m-%d)
	first="norm i$date"
fi

vim -c "$first" "${args[@]}" "$file"
git -C $dir add $stamp.txt
git -C $dir commit --allow-empty-message -m ''
