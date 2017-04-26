#!/bin/bash
while read project
do
	PROJECT=$project docker-compose run --rm sync-transifex DownloadPo|| echo "$project download failed"
done < project.list
