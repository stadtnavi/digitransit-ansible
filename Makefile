.PHONY: vagrant staging production tileserver infrastructure
.PRECIOUS: tileserver/%.osm.pbf

# ansible

PLAYBOOK_CMD:=ANSIBLE_PIPELINING=true ansible-playbook --vault-password-file vault-password

galaxy-install:
	ansible-galaxy collection install -r requirements.yml
	ansible-galaxy install -r requirements.yml

galaxy-install-force:
	ansible-galaxy collection install --force -r requirements.yml
	ansible-galaxy install --force -r requirements.yml

vagrant: galaxy-install
	vagrant up
	vagrant provision

staging: galaxy-install
	${PLAYBOOK_CMD} -i staging digitransit.yml

production: galaxy-install
	${PLAYBOOK_CMD} -i production digitransit.yml

productionnorth: galaxy-install
	${PLAYBOOK_CMD} -i productionnorth digitransit.yml

infrastructure: galaxy-install
	${PLAYBOOK_CMD} -i infrastructure infrastructure.yml

dev: galaxy-install
	${PLAYBOOK_CMD} -i dev digitransit.yml

beta: galaxy-install
	${PLAYBOOK_CMD} -i beta digitransit.yml

# tileserver

tileserver/stuttgart-regbez.osm.pbf:
	mkdir -p tileserver
	curl "http://download.geofabrik.de/europe/germany/baden-wuerttemberg/stuttgart-regbez-latest.osm.pbf" -o $@

tileserver/baden-wuerttemberg.osm.pbf:
	mkdir -p tileserver
	curl "http://download.geofabrik.de/europe/germany/baden-wuerttemberg-latest.osm.pbf" -o $@

tileserver/hungary.osm.pbf:
	mkdir -p tileserver
	curl "http://download.geofabrik.de/europe/hungary-latest.osm.pbf" -o $@

tileserver/%.osm.pbf: tileserver/baden-wuerttemberg.osm.pbf
	mkdir -p tileserver
	curl -s "https://raw.githubusercontent.com/leonardehrenfried/polygons/master/$*.geojson" -o tileserver/$*.geojson
	osmium extract --polygon tileserver/$*.geojson tileserver/baden-wuerttemberg.osm.pbf -o tileserver/$*.osm.pbf  --overwrite --set-bounds

tileserver/%.mbtiles: tileserver/%.osm.pbf
	cp roles/tilemaker/templates/*.json roles/tilemaker/templates/*.lua tileserver
	docker run -v $(PWD)/tileserver:/srv -i -t --rm stadtnavi/tilemaker /srv/$*.osm.pbf --output=/srv/$*.mbtiles --config=/srv/config-openmaptiles.json --process=/srv/process-openmaptiles.lua

tileserver-%: tileserver/%.mbtiles
	cp roles/tileserver/templates/*.json tileserver
	cp tileserver/$*.mbtiles tileserver/input.mbtiles
	echo "View map at http://localhost:8080/styles/streets/?raster#15/47.1500/9.5282"
	docker run --rm --name tileserver -v $(PWD)/tileserver:/data -p 8080:80 maptiler/tileserver-gl:latest --config tileserver-config.json

tileserver: tileserver-vaihingen

tileserver-szeged: tileserver/hungary.osm.pbf
	cp roles/tilemaker/templates/*.json roles/tilemaker/templates/*.lua tileserver
	cp roles/tileserver/templates/*.json tileserver
	curl -s "https://raw.githubusercontent.com/leonardehrenfried/polygons/master/szeged.geojson" -o tileserver/szeged.geojson
	osmium extract --polygon tileserver/szeged.geojson tileserver/hungary.osm.pbf -o tileserver/szeged.osm.pbf  --overwrite --set-bounds
	docker run -v $(PWD)/tileserver:/srv -i -t --rm stadtnavi/tilemaker /srv/szeged.osm.pbf --output=/srv/szeged.mbtiles --config=/srv/config-openmaptiles.json --process=/srv/process-openmaptiles.lua
	cp tileserver/szeged.mbtiles tileserver/input.mbtiles
	docker run --rm --name tileserver -v $(PWD)/tileserver:/data -p 8080:80 maptiler/tileserver-gl:latest --config tileserver-config.json

copy-upstream:
	cp roles/tilemaker/templates/process-openmaptiles.lua ../tilemaker/resources/

copy-cyclo:
	jq '. | .sources.openmaptiles.url="mbtiles://{v3}" | .glyphs="https://tiles.stadtnavi.eu/tiles/openmaptiles/fonts/{fontstack}/{range}.pbf" | .sprite="{style}"' ../../cyclo-bright-gl-style/style.json > roles/tileserver/templates/bicycle.json
	cp ../../cyclo-bright-gl-style/sprite* roles/tileserver/files/sprites/
	rename sprite bicycle roles/tileserver/files/sprites/* -v
	cp ../../cyclo-bright-gl-style/tilemaker/process-openmaptiles.lua roles/tilemaker/templates/process-openmaptiles.lua

photon-local:
	. venv/bin/activate
	ansible-playbook -i inventory-local.yml photon-playbook.yml

photon-remote:
	. venv/bin/activate
	ansible-playbook -i inventory-remote.yml photon-playbook.yml
