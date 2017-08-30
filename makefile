build:
	docker build --force-rm=true -t sync-transifex .

run:
	./run.sh ${ACTION}

downloadall:
	docker-compose run --rm sync-transifex-all
