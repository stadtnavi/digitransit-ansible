.PHONY: vagrant staging production tileserver infrastructure
.PRECIOUS: tileserver/%.osm.pbf

# ansible

PLAYBOOK_CMD:=ansible-playbook --vault-password-file vault-password

galaxy-install:
	ansible-galaxy install -r requirements.yml

vagrant: galaxy-install
	vagrant up
	vagrant provision

staging: galaxy-install
	${PLAYBOOK_CMD} -i staging digitransit.yml

production: galaxy-install
	${PLAYBOOK_CMD} -i production digitransit.yml

ludwigsburg: galaxy-install
	${PLAYBOOK_CMD} -i ludwigsburg digitransit.yml

infrastructure: galaxy-install
	${PLAYBOOK_CMD} -i infrastructure infrastructure.yml

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
