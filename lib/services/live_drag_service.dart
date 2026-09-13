import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/game_state_notifier.dart';

// CRITICAL: This service manages Channel 2 (Ephemeral Drag-Position Stream).
// It is STRICTLY for cosmetic rendering of ghost pieces during multiplayer matches.
// NO security rule, Cloud Function, or client code may EVER read this channel as
// input to move validation, clock calculation, or MatchStatus. 
// It is rendering-only data.

class DragPosition {
  final String uid;
  final String fromSquare;
  final double x;
  final double y;
  final int timestamp;

  DragPosition({
    required this.uid,
    required this.fromSquare,
    required this.x,
    required this.y,
    required this.timestamp,
  });

  factory DragPosition.fromMap(Map<dynamic, dynamic> map) {
    return DragPosition(
      uid: map['uid'] as String? ?? '',
      fromSquare: map['fromSquare'] as String? ?? '',
      x: (map['x'] as num?)?.toDouble() ?? 0.0,
      y: (map['y'] as num?)?.toDouble() ?? 0.0,
      timestamp: map['timestamp'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fromSquare': fromSquare,
      'x': x,
      'y': y,
      'timestamp': timestamp,
    };
  }
}

final liveDragServiceProvider = Provider<LiveDragService>((ref) {
  return LiveDragService(FirebaseDatabase.instance);
});

class LiveDragService {
  final FirebaseDatabase _db;
  StreamSubscription? _subscription;
  Timer? _throttleTimer;
  Timer? _stalenessTimer;
  
  Map<String, dynamic>? _pendingWrite;
  bool _isThrottling = false;
  
  // Staleness timeout window
  static const int _stalenessMs = 500;
  // Target ~20fps write rate
  static const int _throttleMs = 50;

  LiveDragService(this._db);

  /// Broadcasts a live drag update. Throttled to avoid overwhelming the network.
  void updateDrag(String matchId, String uid, String fromSquare, double x, double y) {
    final payload = DragPosition(
      uid: uid,
      fromSquare: fromSquare,
      x: x,
      y: y,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ).toMap();

    if (!_isThrottling) {
      _writeToDb(matchId, payload);
      _isThrottling = true;
      _throttleTimer = Timer(const Duration(milliseconds: _throttleMs), () {
        _isThrottling = false;
        if (_pendingWrite != null) {
          _writeToDb(matchId, _pendingWrite!);
          _pendingWrite = null;
        }
      });
    } else {
      _pendingWrite = payload;
    }
  }

  void _writeToDb(String matchId, Map<String, dynamic> payload) {
    _db.ref('liveDrag/$matchId').set(payload).catchError((_) {});
  }

  /// Clears the drag state immediately (e.g. on release).
  void clearDrag(String matchId) {
    _throttleTimer?.cancel();
    _pendingWrite = null;
    _isThrottling = false;
    _db.ref('liveDrag/$matchId').remove().catchError((_) {});
  }

  /// Listens for opponent drag updates. Provides a stream of DragPosition or null.
  Stream<DragPosition?> watchDragState(String matchId, String localUid) {
    final controller = StreamController<DragPosition?>.broadcast();

    _subscription?.cancel();
    _subscription = _db.ref('liveDrag/$matchId').onValue.listen((event) {
      final val = event.snapshot.value;
      if (val == null) {
        controller.add(null);
        return;
      }
      
      try {
        final pos = DragPosition.fromMap(val as Map<dynamic, dynamic>);
        if (pos.uid == localUid || pos.uid.isEmpty) {
          controller.add(null);
          return;
        }

        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - pos.timestamp > _stalenessMs) {
          // Stale data
          controller.add(null);
          return;
        }

        controller.add(pos);

        // Reset staleness timer
        _stalenessTimer?.cancel();
        _stalenessTimer = Timer(const Duration(milliseconds: _stalenessMs), () {
          controller.add(null);
        });
      } catch (_) {
        controller.add(null);
      }
    });

    controller.onCancel = () {
      _subscription?.cancel();
      _stalenessTimer?.cancel();
      _throttleTimer?.cancel();
    };

    return controller.stream;
  }

  void dispose() {
    _subscription?.cancel();
    _stalenessTimer?.cancel();
    _throttleTimer?.cancel();
  }
}

final liveDragStreamProvider = StreamProvider.family<DragPosition?, String>((ref, matchId) {
  final service = ref.watch(liveDragServiceProvider);
  final currentUid = ref.watch(authServiceProvider).currentUid;
  return service.watchDragState(matchId, currentUid);
});

