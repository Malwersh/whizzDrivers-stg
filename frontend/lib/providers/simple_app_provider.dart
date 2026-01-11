import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/driver_status.dart';

// Simple app state class
class AppState {
  final DriverStatus driverStatus;
  final bool isLoading;

  const AppState({
    this.driverStatus = DriverStatus.offline,
    this.isLoading = false,
  });

  AppState copyWith({
    DriverStatus? driverStatus,
    bool? isLoading,
  }) {
    return AppState(
      driverStatus: driverStatus ?? this.driverStatus,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// Simple state notifier for app state
class AppStateNotifier extends StateNotifier<AppState> {
  AppStateNotifier() : super(const AppState());

  Future<void> initialize(context) async {
    // Simple initialization
    state = state.copyWith(isLoading: false);
  }

  Future<bool> startShift({String? selectedZone}) async {
    state = state.copyWith(isLoading: true);
    
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));
    
    state = state.copyWith(
      driverStatus: DriverStatus.online,
      isLoading: false,
    );
    
    return true;
  }

  Future<bool> endShift() async {
    state = state.copyWith(isLoading: true);
    
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));
    
    state = state.copyWith(
      driverStatus: DriverStatus.offline,
      isLoading: false,
    );
    
    return true;
  }
}

// Provider for app state
final appControllerProvider = StateNotifierProvider<AppStateNotifier, AppState>((ref) {
  return AppStateNotifier();
});
