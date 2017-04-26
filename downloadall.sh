#!/bin/bash
while read project
do
	echo "start download $project"
	PROJECT=$project bash -e sync_po.sh DownloadPo|| echo "$project download failed"
done < project.list
