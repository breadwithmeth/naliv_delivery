import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

/// Supplies explicitly synthetic map tiles without network I/O.
class FixtureTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _tile;
}

final _tile = MemoryImage(base64Decode(_tilePng));
const _tilePng =
    'iVBORw0KGgoAAAANSUhEUgAAAQAAAAEABAMAAACuXLVVAAAAJFBMVEX////c5dXL1cm3wrqnwsymsq1/jZFseoJod4BaanZNXW1IWWmvoV5UAAABxklEQVR42u3bMUsCYQCA4fe+bMipIKIhyP6B0BrV0BZFc1OFnUtT1I+oqbXDpSGnhiDao10Q/0DS6BBKY+m1ZBRI0OBV8r7Td4rweN/pHd5nNMWA0nZ/NPDp7/vZiwO/nAABAgQIEPDrgFx/sPjl4dc7p0CAAAECBAgQIECAgMwvy2sM/KHLKRAgQIAAAQIECDAzMzOz0S9yLZkAAQIECMB7Rhn0dZlYt/4f98B378GDUIAAAQIECBAgQMA/uCyvjcAeqHkQChDwBwD5uDQRdqKjuFo64yxfPszHJfJbbJO7oFouDB2QJhV6YfwqaVWA9LyaJhXSIvOEG1rJVjZTcLvS7A87ADRCE+4hLWQDeFr6GM4B8BzaLHcg1IcOiOLdz1vlgyjeg0a4Y/qwMHN0PfSzYZowwcJlf+t8LU2A9uQzsyebrdOMPobrzVWgEerwCEB3mdDsFbP6Hsg9vKwCt8fX8BjF+9DbYKz9fkDiXTPPBQIECBAgQIAAAQIECBAgQIAAAQIECBAgQAD+89rMzMzMcA2Jl+UCBDDSq+vHisNYbu4UCBAgQIAAAQIECBDwg8vybs0pECBAgAABAgQIECBAwEgC3gD3zGGKXSH29gAAAABJRU5ErkJggg==';
