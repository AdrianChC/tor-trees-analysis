env:
	pixi init
	pixi install
	pixi ls

del-env:
	pixi clean
	rm -r pixi.lock pixi.toml .pixi

set-docker:
	docker compose up -d
	docker compose ps

load-data:
	bash load_data.sh