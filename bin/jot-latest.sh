#!/bin/bash

dir=~/z/admin/jot
file=$(find "$dir"/*.txt -type f | sort | tail -1)

if [ "$file" ]
then
	echo "$file"
	echo
	cat "$file"
	echo
fi
