import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';

class MotionService {
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  final Function() onTwistDetected;
  
  // Detection parameters
  static const double _twistThreshold = 8.0; // Angular velocity threshold
  static const int _cooldownMs = 2000; // Prevent multiple triggers
  
  DateTime _lastTriggerTime = DateTime.fromMillisecondsSinceEpoch(0);
  double _lastY = 0;

  MotionService({required this.onTwistDetected});

  void startListening() {
    _gyroscopeSubscription = gyroscopeEventStream().listen((GyroscopeEvent event) {
      final now = DateTime.now();
      if (now.difference(_lastTriggerTime).inMilliseconds < _cooldownMs) return;

      // A twist is defined as a sharp rotation followed by a sharp return
      // or just a very high spike in Y-axis angular velocity (rotating phone sideways)
      final double y = event.y;
      
      // Detect sharp peak
      if (y.abs() > _twistThreshold) {
        // Double check direction change or just high intensity
        if ((y > 0 && _lastY < 0) || (y < 0 && _lastY > 0) || y.abs() > _twistThreshold * 1.5) {
          _lastTriggerTime = now;
          onTwistDetected();
        }
      }
      
      _lastY = y;
    });
  }

  void stopListening() {
    _gyroscopeSubscription?.cancel();
  }
}
