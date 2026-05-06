import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  FirebaseAnalyticsObserver get observer => FirebaseAnalyticsObserver(analytics: _analytics);

  /// Log custom event
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics.logEvent(
        name: name,
        parameters: parameters,
      );
      if (kDebugMode) {
        print('Analytics: Event logged -> $name with $parameters');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Analytics: Failed to log event $name: $e');
      }
    }
  }

  /// Log save/export actions
  Future<void> logSaveAction({
    required String feature,
    required String type, // 'video', 'image', 'preset', etc.
    Map<String, Object>? parameters,
  }) async {
    await logEvent(
      name: 'save_action',
      parameters: {
        'feature': feature,
        'type': type,
        ...?parameters,
      },
    );
  }

  /// Screen tracking
  Future<void> setCurrentScreen({
    required String screenName,
  }) async {
    try {
      await _analytics.logScreenView(screenName: screenName);
      if (kDebugMode) {
        print('Analytics: Screen view -> $screenName');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Analytics: Failed to log screen view $screenName: $e');
      }
    }
  }

  // --- Specific Events ---

  Future<void> logAppOpen() async {
    await logEvent(name: 'app_open_custom');
  }

  Future<void> logOnboardingStarted() async {
    await logEvent(name: 'onboarding_started');
  }

  Future<void> logOnboardingCompleted() async {
    await logEvent(name: 'onboarding_completed');
  }

  Future<void> logVideoProcessingStarted({
    required String type,
    required int durationMs,
  }) async {
    await logEvent(
      name: 'video_processing_started',
      parameters: {
        'type': type,
        'duration_ms': durationMs,
      },
    );
  }

  Future<void> logVideoProcessingSuccess({
    required String type,
    required int durationMs,
    required int processingTimeMs,
  }) async {
    await logEvent(
      name: 'video_processing_success',
      parameters: {
        'type': type,
        'duration_ms': durationMs,
        'processing_time_ms': processingTimeMs,
      },
    );
  }

  Future<void> logVideoProcessingFailed({
    required String type,
    required String error,
  }) async {
    await logEvent(
      name: 'video_processing_failed',
      parameters: {
        'type': type,
        'error': error,
      },
    );
  }

  Future<void> logImageBulkCropStarted({
    required int imageCount,
  }) async {
    await logEvent(
      name: 'image_bulk_crop_started',
      parameters: {
        'image_count': imageCount,
      },
    );
  }

  Future<void> logImageBulkCropSuccess({
    required int imageCount,
    required int processingTimeMs,
  }) async {
    await logEvent(
      name: 'image_bulk_crop_success',
      parameters: {
        'image_count': imageCount,
        'processing_time_ms': processingTimeMs,
      },
    );
  }
}
