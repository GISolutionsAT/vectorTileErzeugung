FROM  mdillon/postgis:11
LABEL maintainer="juergen.hahn@gisolutions.at"

RUN mkdir -p /data

COPY ./geodata/covid19_austria.geojson /data/covid19_austria.geojson
COPY ./geodata/covid19_district.geojson /data/covid19_district.geojson
# folgendes s
COPY ./q_setup_import.sh /docker-entrypoint-initdb.d/

RUN apt-get update --fix-missing
RUN apt-get install -y wget \
	bzip2 \
	ca-certificates \
	build-essential \
	curl \
	git-core \
	pkg-config \
	python3-dev \
	python3-pip \
	python3-setuptools \
	python3-virtualenv \
	unzip \
	software-properties-common

RUN apt install -y gdal-bin python-gdal python3-gdal
# test ob ogr installiert ist
RUN ogrinfo --version