// Manual renderer-only diagnostic. No auth, driver writes, or dispatch actions.
// flutter run -t test/manual/android_map_smoke_455.dart -d <android-device>
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() => runApp(MaterialApp(
    themeMode: ThemeMode.light,
    theme: ThemeData.light(),
    home: const Scaffold(
        body: SafeArea(
            child: GoogleMap(
                initialCameraPosition:
                    CameraPosition(target: LatLng(31.921, 44.461), zoom: 16),
                myLocationEnabled: false,
                myLocationButtonEnabled: false)))));
