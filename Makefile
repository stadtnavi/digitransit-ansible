.PHONY: vagrant staging production tileserver

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

tileserver/liechtenstein.osm.pbf:
	mkdir -p tileserver
	curl "http://download.geofabrik.de/europe/liechtenstein-latest.osm.pbf" -o $@

tileserver/kreis-boeblingen.osm.pbf: tileserver/stuttgart-regbez.osm.pbf
	mkdir -p tileserver
	curl "https://gist.githubusercontent.com/leonardehrenfried/5f984d809889e4289a407facfc93cbd1/raw/088aa303e7b0e4b8288d1f2cc9538cf75e2aec25/map.geojson" -o tileserver/kreis-boeblingen.geojson
	osmium extract --polygon tileserver/kreis-boeblingen.geojson tileserver/stuttgart-regbez.osm.pbf -o tileserver/kreis-boeblingen.osm.pbf --overwrite

tileserver/herrenberg.osm.pbf: tileserver/stuttgart-regbez.osm.pbf
	mkdir -p tileserver
	curl "https://gist.githubusercontent.com/leonardehrenfried/c91b4375918ac18da90367fe070bdce8/raw/ffa972c3336f77b8b82b8ab74703e2a28b496045/map.geojson" -o tileserver/herrenberg.geojson
	osmium extract --polygon tileserver/herrenberg.geojson tileserver/stuttgart-regbez.osm.pbf -o tileserver/herrenberg.osm.pbf  --strategy=smart --overwrite

tileserver/input.mbtiles: tileserver/liechtenstein.osm.pbf
	cp roles/tilemaker/templates/* tileserver
	docker run -v $(PWD)/tileserver:/srv -i -t --rm lehrenfried/tilemaker /srv/liechtenstein.osm.pbf --output=/srv/input.mbtiles --config=/srv/config-openmaptiles.json --process=/srv/process-openmaptiles.lua

tileserver: tileserver/input.mbtiles
	cp roles/tileserver/templates/* tileserver
	echo "View map at http://localhost:8080/styles/streets/?raster#15/47.1500/9.5282"
	docker run --rm --name tileserver -v $(PWD)/tileserver:/data -p 8080:80 maptiler/tileserver-gl:latest --config tileserver-config.json

clean-mbtiles:
	rm -f tileserver/*.mbtiles


