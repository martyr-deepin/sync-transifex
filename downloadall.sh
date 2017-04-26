#!/bin/bash
while read project
do
	echo "start download $project"
	PROJECT=$project docker-compose run --rm sync-transifex DownloadPo|| echo "$project download failed"
done < project.list
