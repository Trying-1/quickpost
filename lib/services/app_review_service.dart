import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// In-App Review Service
/// 
/// Handles requesting app reviews at appropriate times

class AppReviewService {
  static final AppReviewService _instance = AppReviewService._internal();
  factory AppReviewService() => _instance;
  AppReviewService._internal();
  
  static const String _reviewBoxName = 'app_review';
  static const String _exportCountKey = 'export_count';
  static const String _lastReviewRequestKey = 'last_review_request';
  static const String _hasReviewedKey = 'has_reviewed';
  
  // Configuration
  static const int _exportsBeforeReview = 5; // Ask after 5 exports
  static const int _daysBetweenRequests = 30; // Don't ask again for 30 days
  
  Box? _box;
  
  /// Initialize the service
  Future<void> initialize() async {
    try {
      _box = await Hive.openBox(_reviewBoxName);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing review service: $e');
      }
    }
  }
  
  /// Increment export count
  void incrementExportCount() {
    if (_box == null) return;
    
    final currentCount = _box!.get(_exportCountKey, defaultValue: 0) as int;
    _box!.put(_exportCountKey, currentCount + 1);
    
    if (kDebugMode) {
      print('📊 Export count: ${currentCount + 1}');
    }
  }
  
  /// Check if we should request review
  Future<bool> shouldRequestReview() async {
    if (_box == null) return false;
    
    // Check if user already reviewed
    final hasReviewed = _box!.get(_hasReviewedKey, defaultValue: false) as bool;
    if (hasReviewed) {
      return false;
    }
    
    // Check export count
    final exportCount = _box!.get(_exportCountKey, defaultValue: 0) as int;
    if (exportCount < _exportsBeforeReview) {
      return false;
    }
    
    // Check last request time
    final lastRequest = _box!.get(_lastReviewRequestKey) as int?;
    if (lastRequest != null) {
      final daysSinceLastRequest = 
          DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastRequest)).inDays;
      
      if (daysSinceLastRequest < _daysBetweenRequests) {
        return false;
      }
    }
    
    return true;
  }
  
  /// Request in-app review
  Future<void> requestReview() async {
    final inAppReview = InAppReview.instance;
    
    try {
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
        
        // Update last request time
        if (_box != null) {
          _box!.put(_lastReviewRequestKey, DateTime.now().millisecondsSinceEpoch);
        }
        
        if (kDebugMode) {
          print('⭐ Review requested');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error requesting review: $e');
      }
    }
  }
  
  /// Open Play Store page (fallback if in-app review not available)
  Future<void> openStoreListing() async {
    final inAppReview = InAppReview.instance;
    
    try {
      await inAppReview.openStoreListing(
        appStoreId: '', // Not needed for Android
      );
      
      if (kDebugMode) {
        print('🏪 Opened Play Store listing');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error opening store listing: $e');
      }
    }
  }
  
  /// Mark that user has reviewed (so we don't ask again)
  void markAsReviewed() {
    if (_box != null) {
      _box!.put(_hasReviewedKey, true);
    }
  }
  
  /// Check and request review if appropriate
  Future<void> checkAndRequestReview() async {
    if (await shouldRequestReview()) {
      await requestReview();
    }
  }
}
