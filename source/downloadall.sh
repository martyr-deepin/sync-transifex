#!/bin/bash
while read project_name
do
	echo "start download $project_name"
	PROJECT=$project_name bash -x sync_po.sh DownloadPo|| echo "$project_name download failed"
done < project.list
