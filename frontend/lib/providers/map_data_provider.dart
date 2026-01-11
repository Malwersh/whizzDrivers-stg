import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/map_data.dart';
import '../services/map_data_service.dart';

/// State for map data
class MapDataState {
  final MapDataResponse? data;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdated;

  MapDataState({
    this.data,
    this.isLoading = false,
    this.error,
    this.lastUpdated,
  });

  MapDataState copyWith({
    MapDataResponse? data,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
  }) {
    return MapDataState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// Provider for map data
class MapDataNotifier extends StateNotifier<MapDataState> {
  MapDataNotifier() : super(MapDataState());

  /// Load map data for current location
  Future<void> loadMapData(double lat, double lng) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final data = await MapDataService.fetchMapData(lat: lat, lng: lng);
      
      state = MapDataState(
        data: data,
        isLoading: false,
        error: null,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh map data
  Future<void> refresh(double lat, double lng) async {
    await loadMapData(lat, lng);
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Map data provider
final mapDataProvider = StateNotifierProvider<MapDataNotifier, MapDataState>((ref) {
  return MapDataNotifier();
});
