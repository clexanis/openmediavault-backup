#!/bin/bash
for i in {1..15}; do 
	time bash ./loop.sh $i
	ls -l /srv/tmpfs
	rm -rf /srv/tmpfs/*
done
	