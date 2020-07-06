# Warum Vector Tiles?
[Vector Tiles](https://en.wikipedia.org/wiki/Vector_tiles) sind Geodaten zugeschnitten nach einem vordefinierten Gitter und verpackt zum Transport über das Internet um am Client in einer Webkarte dargestellt zu werden. Laut Google Trends besteht gleich bleibendes Interesse an der Technologie, siehe folgende Darstellung:

![Vector Tiles Google Trens](/images/vectorTilesGoogleTrends.png)

Der Einsatz von Vector Tiles hat unter anderem folgende Vorteile im Vergleich zu Raster Tiles (Bilder):

- kleinere Datenmengen
- weniger Datenverwendung über die Leitung
- Geodatenrendering am Client
- Interaktion am Client durch JavaScript Methoden

# Voraussetzungen für die folgende Beschreibung

In diesem Dokument wird Wissen über die folgenden Technologien, Datenbanken, Programme und Bibliotheken vorausgesetzt.

## Docker und docker-compose

Die Applikationen werden in Dockerumgebungen ausgeführt. Eine Einführung zu docker ist unter folgendem [Link](https://docker-curriculum.com) erreichbar. Auf docker aufbauend wird [docker-compose](https://docs.docker.com/compose/)

## PostGIS

[PostGIS](https://postgis.net) ist die Erweiterung um geografische Algorithmen und Datenstukturen der [PostgreSQL](https://www.postgresql.org) Datenbank.

## Kommandozeile

Die Applikationen werden auf der [Kommandozeile](https://de.wikipedia.org/wiki/Kommandozeile) ausgeführt.

## WebTechnologien

Die Webkarte am Client wird mittels OpenLayers erstellt. Die Konfiguration wird mittels JavaScript durchgeführt. Eingebunden ist die Webkarte in einer [HTML](https://html.spec.whatwg.org/multipage/) Seite, die mit [CSS](https://www.w3.org/Style/CSS/) Technologie gestylt wird.

## Webkarten

Für die Darstellung von Karten auf einer Webseite wird zumeist die Architektur von folgender Darstellung gewählt. ACHTUNG die Architektur ist stark abstrahiert.
![Architektur von Webkarten](/images/WebkartenArchitektur.png)

In diesem Dokument wird als JavaScript Bibliothek zur Erzeugung von Webkarten  [OpenLayers](https://openlayers.org) verwendet.

# Erzeugung von Vector Tiles

Folgend werden zwei Methoden beschrieben, um Vector Tiles zu erzeugen. Die **erste Methode** erzeugt Vector Tiles in Echtzeit von Geodaten die in einer PostGIS Datenbank gespeichert sind. Die **zweite Methode** erzeugt Vector Tiles aus vorprozessierten Daten die am Dateisystem gespeichert sind.

Beide Methoden haben Vorteile und Nachteile und es ist je Anwendungsfall zu entscheiden, welche Methode besser geeignet ist. Entscheidungskriterien sind am Ende dieses Textes zu finden.

# Methode 1: Tegola und PostGIS

Der abstrakte Aufbau der Applikationen ist in folgender Darstellung gezeigt. Der Datenfluss läuft von links nach rechts. Die Objekte in der ersten Spalte mit Bezeichnung **Daten in Tabellen** stellen die Geodaten abgelegt in separaten Tabellen in einer PostGIS Datenbank an. Diese Datenbank läuft in einem Docker Container. Die zweite Spalte **HTTP Interface** zeigt die Tegola Anwendung, die auf die PostGIS Datenbank und die Tabellen zugreift und die Vector Tiles mittels HTTP Interface erreichbar macht. Die dritte Spalte **Kartenerstellung** zeigt den Kartenaufbau am Client in einem Browser mit OpenLayers (oder ähnlichen JavaScript Bibliotheken). In der vierten Spalte **Onlinekarte** steht für die Webkarte, die der Benutzer sieht und die sich der Client zusammenbauen und stylen kann.
![Architektur](/images/TegolaArchitektur.png)

Zum schnelleren Start sind die Konfigurationsschritte und Datenimportschritte in dockerfiles und Konfigurationsdatein ausgelagert und in der docker-compose.yaml zusammengeführt. Das komplette Setup kann mittels folgendem Befehl gestartet werden, aus dem Verzeichnis _tegola_:

`docker-compose run `

## Konfiguration

### PostGIS

Das verwendete PostGIS docker image wird durch die Datei _/tegola/postgis/Dockerfile_ konfiguriert. Die Konfiguration der PostGIS Datenbank und das Importieren der Daten wird im eigenen Dockerfile durchgeführt. Dabei wird das image von [mdillon/postgis](https://hub.docker.com/r/mdillon/postgis) erweitert. Für den Import der Daten (_/tegola/postgis/geodata/_) wird das Werkzeug [ogr2ogr](https://gdal.org/programs/ogr2ogr.html#ogr2ogr) verwendet. Weiters wird ein Datenbankbenutzer _tegola_ angelegt, der Leserechte auf die importierten Datentabellen erhält.

### Tegola

Laut [Homepage](https://tegola.io) definert sich Tegola als:

> „Tegola is a vector tile server delivering Mapbox Vector Tiles with support for PostGIS and GeoPackage data providers.“

Der Sourcecode ist auf [github](https://github.com/go-spatial/tegola) verfügbar und ist lizenziert unter der ([MIT Licence](https://github.com/go-spatial/tegola/blob/v0.12.x/LICENSE.md). Zur Konfiguration nutzt Tegola toml Dateien, um zum Beispiel den PostGIS Zugriff zu konfigurieren.

Das tegola docker image wird vom image [gospatial/tegola](https://hub.docker.com/r/gospatial/tegola) erweitert.

**Tegola Konfiguration**

Die Konfigurationsdatei für tegola, für die PostGIS und die zuvor erstellten Tabellen sieht wie folgt aus:

```toml
[webserver]
port = ":8080"

# register data providers
[[providers]]
name = "borders"      # provider name is referenced from map layers
type = "postgis"      # the type of data provider. currently only supports postgis
host = "postgis"      # postgis database host
port = 5432           # postgis database port
database = "borders"  # postgis database name
user = "tegola"       # postgis database user
password = "password" # postgis database password
srid = 4326           # The default srid for this provider. If not provided it will be WebMercator (3857)

 [[providers.layers]]
  name = "austriaborder"
  geometry_fieldname = "wkb_geometry"
  id_fieldname = "id"
  sql = "SELECT ST_AsBinary(wkb_geometry) AS wkb_geometry, austria, id FROM austriaborder WHERE wkb_geometry && !BBOX!"

  [[providers.layers]]
  name = "districtsborder"
  geometry_fieldname = "wkb_geometry"
  id_fieldname = "id"
  sql = "SELECT ST_AsBinary(wkb_geometry) AS wkb_geometry, name, ogc_fid FROM districtsborder WHERE wkb_geometry && !BBOX!"

[[maps]]
name = "borders"

[[maps.layers]]
  provider_layer = "borders.austriaborder"
  min_zoom = 1
  max_zoom = 10

 [[maps.layers]]
  provider_layer = "borders.districtsborder"
  min_zoom = 10
  max_zoom = 20
```

Diese Konfigurationsdatei muss beim Start von tegola mit dem folgenden Kommando angegeben werden und ist in der _docker-compose.yaml_ Datei enthalten.

```bash
serve --config /opt/tegola_config/config.toml
```

## Anzeige der Vector Tiles in einer Webkarte

Die Vector Tiles die von tegola erzeugt werden, können im mitgelieferten Webserver auf einer Webkarte unter der URL [`http://localhost:8081/`](http://localhost:8081/) betrachtet werden und sehen exemplarisch wie folgt aus:

![Tegola Preview](/images/TegolaPreview.png)



Unter dem REST-API Endpunkt [http://localhost:8081/maps/borders/{z}/{x}/{y}.pbf](http://localhost:8081/maps/borders/{z}/{x}/{y}.pbf) können die Daten in einer eigens erstellten Webkarte zur weiteren Verarbeitung genutzt werden. Ein komplettes Beispiel ist in der Datei _/tegola/index.html_ zu finden, das wesentliche Snippet daraus ist folgender Teil und folgend ein Screenshot der Webkarte.

```JavaScript
new ol.layer.VectorTile({
    source: new ol.source.VectorTile({
        format: new ol.format.MVT(),
        url:'http://localhost:8081/maps/borders/{z}/{x}/{y}.pbf'
        })
})
```

![OpenLayers tegola Beispiel](/images/tegolaOwnExample.png)

# Methode 2: Daten am Dateisystem mittels TileServer-GL durch mbtiles
Für diese Methode werden die Daten zuerst mit dem Werkzeug [tippecanoe](https://github.com/mapbox/tippecanoe) aufbereitet und danach dem [tileserver-gl](http://tileserver.org) zur Auslieferung übergeben. Die grobe Architektur ist in folgendem Bild enthalten. Das Werkzeug tippecanoe übersetzt verschiedene Datenformate in das mbtiles Format. Die resultierende mbtiles Datei nutzt tieserver-gl für die Auslieferung der Vector Tiles.

![Architektur](/images/TileServerGLArchitektur.png)

## Prozessierungsstrecke und Konfiguration

### Tippecanoe

Laut [Homepage](https://github.com/mapbox/tippecanoe) definert sich tippecanoe als:

> „Builds vector tilesets from large (or small) collections of GeoJSON, Geobuf, or CSV features, like these."

Das Werkzeug bietet viele Möglichkeiten die Eingabedaten zu verändern und liefert als Ausgabeformat eine _mbtiles_ Datei. Das Programm gibt es wiederum in einem Docker container und man kann es pro Datensatz ausführen. Zum Beispiel kann die Datei world*borders.geojson in world_borders.mbtiles mittels folgendem Kommandozeilenaufruf vom Ordner _/TileServerGL/_ erstellt werden:

Tippecanoe gibt es in einem Docker [image]](https://hub.docker.com/r/klokantech/tippecanoe) das mit folgendem Befehl genutzt werden kann:

`docker run --rm -v $(pwd):/data klokantech/tippecanoe tippecanoe -zg -o /data/world_borders.mbtiles --drop-densest-as-needed /data/world_borders.geojson`

Die mbtiles Datei dient als Eingabe für TileServer-GL. Die Ausgabe von tippecanoe ist in folgendem Snippet enthalten.

```bash
For layer 0, using name "world_bordersgeojson"
246 features, 2868278 bytes of geometry, 10463 bytes of separate metadata, 14197 bytes of string pool
Choosing a maxzoom of -z0 for features about 2660981 feet apart
Choosing a maxzoom of -z4 for resolution of about 17341 feet within features
  99.9%  4/2/6
```

Dabei sieht man, dass tippecanoe als maximalen Zoomelevel für diesen Datensatz die Zoomstufe 4 festgelegt hat.

### TileServer-GL

Laut [Homepage](http://tileserver.org) definert sich tileserver-gl als:

> „Vector and raster maps with GL styles. Server side rendering by Mapbox GL Native. Map tile server for Mapbox GL JS, Android, iOS, Leaflet, OpenLayers, GIS via WMTS, etc.“

Tileserver-gl ist als docker [image]](https://hub.docker.com/r/klokantech/tileserver-gl) nutzbar und wird mit folgenden Befehl gestartet. Dabei wird die zuvor erstellte mbtiles Datei eingebunden.

`docker run --rm -it -v $(pwd):/data -p 8080:80 klokantech/tileserver-gl -V /data/world_borders.mbtiles`

## Anzeige der Vector Tiles in einer Webkarte

Die REST-API von tileserver-gl bietet unter dem Endpunkt: [http://localhost:8080/data/world_borders/{z}/{x}/{y}.pbf](http://localhost:8080/data/world_borders/{z}/{x}/{y}.pbf) Vector Tiles an. Der Dienst bietet eine Anzeige unter der Adresse: [http://localhost:8080/](http://localhost:8080/) an und sieht wie auf folgendem Darstellung aus:

![Tile Server GL Preview](/images/TileServerGLPreview.png)

Die erstellten Vector Tiles können direkt in eine OpenLayers Karte eingebunden werden. Ein komplettes Beispiel ist in der Datei _/TileServerGL/index.html_ zu finden, das wesentliche Snippet daraus ist folgendes:

```JavaScript
new ol.layer.VectorTile({
    source: new ol.source.VectorTile({
        format: new ol.format.MVT(),
        url:'http://localhost:8080/data/world_borders/{z}/{x}/{y}.pbf'
        })
})
```

Die Vector Tiles werden bis zum Zoomlevel 4 (von tippecanoe ausgewählt) von tileserver-gl geliefert. Eine Ansicht der Wekarte ist in folgender Darstellung:

![OpenLayers Tileserverr-gl Beispiel](/images/tileserverOwnExample.png)

# Ändern des Styling mittels JavaScript

Beide Quellen sind in der Webkarte unter _index.html_ eingebunden. Um die einzelnen Objekte zu stylen, kann jedes Attribut verwendet werden, das auf einem Vector Tile angehängt ist. In folgendem Code wird nur zwischen den einzelnen Layernamen ein unterschiedliches Styling erzeugt:

```JavaScript
function customStyleFunction( feature, resolution ) {
    if ( feature.get( 'layer' ) == 'world_bordersgeojson' ) {
        return new ol.style.Style( {
        fill: new ol.style.Fill( {
            color: [155, 0, 0, 0.2],
        } ),
        stroke: new ol.style.Stroke( {
            color: [155, 0, 0, 1],
            width: 3,
        } ),
        } );
    }
    if ( feature.get( 'layer' ) == 'districtsborder' ) {
        return ol.style.Style( {
        fill: new ol.style.Fill( {
            color: [239, 0, 0, 0.2],
        } ),
        stroke: new ol.style.Stroke( {
            color: [239, 0, 0, 1],
            width: 2,
        } ),
        } );
    }

    if ( feature.get( 'layer' ) == 'austriaborder' ) {
        return ol.style.Style( {
        fill: new ol.style.Fill( {
            color: [239, 0, 0, 0.2],
        } ),
        stroke: new ol.style.Stroke( {
            color: [239, 0, 0, 1],
            width: 1,
        } ),
        } );
    }
```
Das Ergebnis ist in fogender Darstellung gegeben:

![Vector Tiles mit OpenLayers](/images/olOwnStyle1.png)

Das Styling der Vector Tiles kann mittels einer JavaScript Funktion geändert werden. Als Auslöser kann jedes Event dienen, im folgenden Snippet dient ein _onclick_ event eines Buttons.

```HTML
 <button onclick="changeStyleFunction()">change styling</button>
```

```JavaScript
function changeStyleFunction() {
    var newStyle = undefined;
    //remove all layers from the map
    olMap.getLayers().forEach( function a( layer ) {
        olMap.removeLayer( layer );
    } );
    // add all layers with the new style
    olMap.addLayer(
        new ol.layer.Tile( {
        source: new ol.source.OSM(),
        } )
    );
    olMap.addLayer(
        new ol.layer.VectorTile( {
        source: new ol.source.VectorTile( {
            format: new ol.format.MVT(),
            url: 'http://localhost:8080/data/world_borders/{z}/{x}/{y}.pbf',
        } ),
        style: newStyle,
        } )
    );
    olMap.addLayer(
        new ol.layer.VectorTile( {
        source: new ol.source.VectorTile( {
            format: new ol.format.MVT(),
            url: 'http://localhost:8081/maps/borders/{z}/{x}/{y}.pbf',
        } ),
        style: newStyle
        } )
    );

    }
```
Das Ergebnis ist in folgender Darstellung zu sehen:

![Vector Tiles mit OpenLayers](/images/olOwnStyle2.png)

# Sind Vector-Tiles etwas für mich?

Folgende Liste mit Entscheidungskriterien kann Sie bei der Entscheidungsfindung unterstützen. Die Kriterien können Sie auch verwenden, um die für Sie passende Methode zu wählen.

__Beispiele für Entscheidungskriterien:__

- Datenaktualsierungszyklen (minütlich, täglich, monatlich)
- Automatisierung der Prozessierungskette
- Ausfallssicherheit durch Replikationen
- Anzahl an angehängten Daten (Datenmenge) an einem Vector Tile
- Speicherplatzbedarf am Server und bei der Datenübertragung
- Genauigkeit der Darstellung
- Offline download der Vector Tiles auf Smartphones
- Gibt es JavaScript Events im bestehenden Frontend die genutzt werden können, um den Karteninhalt zu ändern?


# Weiterführende Quellen

- [Vector Tiles](https://www.basemap.at) der österreichischen basemap
- [Styling File mit Maputnik](https://maputnik.github.io/) erstellen für Vector Tiles
- [Vector Tiles in OpenLayers mit Maputnik style file stylen](https://github.com/openlayers/ol-mapbox-style)
- [ESRI Vector Tile Format konvertieren](https://github.com/BergWerkGIS/vtpk2mbtiles) in mbtiles
- [QGIS Plugin](https://plugins.qgis.org/plugins/vector_tiles_reader/) um Vector Tiles in QGIS als Layer einzubinden
- [QGIS Plugin](https://www.lutraconsulting.co.uk/crowdfunding/vectortile-qgis/) um Vector Tiles ni QGIS zu erzeugen
