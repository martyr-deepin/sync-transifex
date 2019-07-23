build:
	docker build --force-rm=true --no-cache -t hub.deepin.com/om/sync-transifex .

build_fast:
	# build with cache
	docker build --force-rm=true -t hub.deepin.com/om/sync-transifex .

downloadall:
	docker-compose run --rm sync-transifex-all
