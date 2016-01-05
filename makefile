build:
	docker build --force-rm=true -t sync-transifex .
	docker tag -f sync-transifex:latest sync-transifex:20160105-01

run:
	docker-compose run --rm sync-transifex ${ACTION}
