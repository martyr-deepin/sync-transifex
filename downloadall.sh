#!/bin/bash
while read project_name
do
	echo "start download $project_name"
	PROJECT=$project_name docker-compose run --rm sync-transifex DownloadPo|| echo "$project_name download failed"
	docker stop sync-transifex||echo sync-transifex not running
	docker rm sync-transifex|| echo sync-transifex is not a container name
done < project.list
