import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class PushNotificationService {
  // Private constructor
  PushNotificationService._privateConstructor();

  // Singleton instance
  static final PushNotificationService _instance =
      PushNotificationService._privateConstructor();

  // Factory constructor
  factory PushNotificationService() => _instance;

  // Firebase instances
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // SharedPreferences keys
  static const String NOTIFICATION_PERMISSION_KEY = 'notification_permission';
  static const String DEVICE_TOKEN_KEY = 'device_token';

  // Initialize Firebase and check notification permissions
  Future<void> initialize() async {
    //Calling the fire
    //await Firebase.initializeApp();

    // Check if permission was previously granted
    final prefs = await SharedPreferences.getInstance();
    bool hasPermission = prefs.getBool(NOTIFICATION_PERMISSION_KEY) ?? false;

    if (!hasPermission) {
      await _checkAndRequestNotificationPermissions();
    }

    // Get and save device token
    String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      await prefs.setString(DEVICE_TOKEN_KEY, token);
      // Save token to user's document in Firestore
      await _updateDeviceToken(token);
    }

    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      await prefs.setString(DEVICE_TOKEN_KEY, newToken);
      await _updateDeviceToken(newToken);
    });

    // Configure FCM callbacks
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
  }

  // Update device token in Firestore
  Future<void> _updateDeviceToken(String token) async {
    try {
      final callable = _functions.httpsCallable('updateDeviceToken');
      await callable.call({'token': token});
    } catch (e) {
      print('Error updating device token: $e');
    }
  }

  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('Received foreground message: ${message.messageId}');
    // You can show a local notification here if needed
  }

  // Handle message taps
  void _handleMessageTap(RemoteMessage message) {
    print('Message tapped: ${message.messageId}');
    // Handle navigation or any other action when notification is tapped
  }

  // Handle background messages
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('Handling background message: ${message.messageId}');
  }

  // Check and request notification permissions
  Future<void> _checkAndRequestNotificationPermissions() async {
    final prefs = await SharedPreferences.getInstance();

    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    bool granted =
        settings.authorizationStatus == AuthorizationStatus.authorized;
    await prefs.setBool(NOTIFICATION_PERMISSION_KEY, granted);

    if (granted) {
      print('User granted notification permission');
    } else {
      print('User declined notification permission');
    }
  }

  // Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(NOTIFICATION_PERMISSION_KEY) ?? false;
  }

  // Send notification to a user by email
  Future<void> sendNotification({
    required String userEmail,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Call the Cloud Function to send notification
      final callable = _functions.httpsCallable('sendNotification');
      final result = await callable.call({
        'userEmail': userEmail,
        'title': title,
        'body': body,
        'data': data,
      });

      if (result.data['success'] == true) {
        // Log successful notification
        await _firestore.collection('notifications').add({
          'userEmail': userEmail,
          'title': title,
          'body': body,
          'data': data,
          'sentAt': FieldValue.serverTimestamp(),
          'status': 'sent',
        });
        print('Notification sent successfully');
      } else {
        throw Exception(result.data['error'] ?? 'Failed to send notification');
      }
    } catch (e) {
      print('Error sending notification: $e');
      // Log failed notification
      await _firestore.collection('notifications').add({
        'userEmail': userEmail,
        'title': title,
        'body': body,
        'data': data,
        'sentAt': FieldValue.serverTimestamp(),
        'status': 'failed',
        'error': e.toString(),
      });
      rethrow;
    }
  }

  // Clear notification settings (useful for logout)
  Future<void> clearNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(NOTIFICATION_PERMISSION_KEY);
    await prefs.remove(DEVICE_TOKEN_KEY);
  }
}
