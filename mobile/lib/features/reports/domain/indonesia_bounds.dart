import 'package:latlong2/latlong.dart';

class IndonesiaBounds {
  static final LatLng southWest = LatLng(-11.2, 94.5);
  static final LatLng northEast = LatLng(6.3, 141.1);
  static final LatLng center = LatLng(-2.5, 118.0);

  static bool contains(LatLng point) {
    return point.latitude >= southWest.latitude &&
        point.latitude <= northEast.latitude &&
        point.longitude >= southWest.longitude &&
        point.longitude <= northEast.longitude;
  }
}
