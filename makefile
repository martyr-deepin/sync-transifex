build:
	docker build --force-rm=true -t sync-transifex .

run:
	docker-compose run --rm sync-transifex ${ACTION}
