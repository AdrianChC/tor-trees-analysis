env:
	pixi init
	pixi install --locked
	pixi ls

del-env:
	pixi clean
	rm -r pixi.lock pixi.toml .pixi

set-kernel:
	ln -sfn .pixi/envs/default .venv
	mkdir -p .vscode
	printf '%s\n' \
	  '{"python.defaultInterpreterPath": "$${workspaceFolder}/.venv/bin/python"}' \
	  > .vscode/settings.json

set-docker:
	docker compose up -d
	docker compose ps

load-data:
	bash load_data.sh