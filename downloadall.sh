#!/bin/bash
while read project
do
	PROJECT=$project make run|| echo "$project download failed"
done < project.list
