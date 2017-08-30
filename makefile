build:
	docker build --force-rm=true --no-cache -t hub.deepin.io/deepin/sync-transifex .

build_fast:
	# build with cache
	docker build --force-rm=true -t hub.deepin.io/deepin/sync-transifex .

run:
	./run.sh ${ACTION}

downloadall:
	docker-compose run --rm sync-transifex-all
