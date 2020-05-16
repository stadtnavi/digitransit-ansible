.PHONY: vagrant staging production tileserver
.PRECIOUS: tileserver/%.osm.pbf

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

tileserver/stuttgart-regbez.osm.pbf:
	mkdir -p tileserver
	curl "http://download.geofabrik.de/europe/germany/baden-wuerttemberg/stuttgart-regbez-latest.osm.pbf" -o $@

tileserver/%.osm.pbf: tileserver/stuttgart-regbez.osm.pbf
	mkdir -p tileserver
	curl -s "https://raw.githubusercontent.com/leonardehrenfried/polygons/master/$*.geojson" -o tileserver/$*.geojson
	osmium extract --polygon tileserver/$*.geojson tileserver/stuttgart-regbez.osm.pbf -o tileserver/$*.osm.pbf  --overwrite --set-bounds

tileserver/%.mbtiles: tileserver/%.osm.pbf
	cp roles/tilemaker/templates/*.json roles/tilemaker/templates/*.lua tileserver
	docker run -v $(PWD)/tileserver:/srv -i -t --rm lehrenfried/tilemaker /srv/$*.osm.pbf --output=/srv/$*.mbtiles --config=/srv/config-openmaptiles.json --process=/srv/process-openmaptiles.lua

tileserver-%: tileserver/%.mbtiles
	cp roles/tileserver/templates/*.json tileserver
	cp tileserver/$*.mbtiles tileserver/input.mbtiles
	echo "View map at http://localhost:8080/styles/streets/?raster#15/47.1500/9.5282"
	docker run --rm --name tileserver -v $(PWD)/tileserver:/data -p 8080:80 maptiler/tileserver-gl:latest --config tileserver-config.json

tileserver: tileserver-vaihingen


