import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../local/secure_storage.dart';
import 'api_path.dart';

/// Singleton service that manages a single WebSocket connection to the
/// Laravel Reverb server, and exposes per-channel event streams so that
/// multiple providers/screens (notifications, chat, ...) can share one
/// connection instead of opening a new socket each.
class ReverbService {
  ReverbService._internal();

  static final ReverbService instance = ReverbService._internal();

  factory ReverbService() => instance;

  // Must match REVERB_APP_KEY in the backend .env
  static const String _appKey = '0z58lxjbuvh5gyymgd0n';

  WebSocketChannel? _channel;
  String? _socketId;
  bool _connected = false;

  final Map<String, StreamController<Map<String, dynamic>>>
      _channelControllers = {};
  final Set<String> _pendingSubscriptions = {};

  String get _reverbHost => ApiPath.REVERB_HOST;

  bool get isConnected => _connected;

  Future<void> connect() async {
    if (_connected) return;

    final isLocal = _reverbHost.contains('10.0.2.2') ||
        _reverbHost.contains('127.0.0.1') ||
        _reverbHost.contains('192.168.');
    final scheme = isLocal ? 'ws' : 'wss';
    final portPart = isLocal ? ':8080' : '';

    final wsUrl =
        '$scheme://$_reverbHost$portPart/app/$_appKey?protocol=7&client=flutter&version=1.0&flash=false';

    debugPrint('Connecting to Reverb WebSocket: $wsUrl');

    _channel = IOWebSocketChannel.connect(Uri.parse(wsUrl));
    _connected = true;

    _channel!.stream.listen(
      _handleMessage,
      onDone: () {
        debugPrint('Reverb WebSocket disconnected');
        _connected = false;
        _socketId = null;
      },
      onError: (err) {
        debugPrint('Reverb WebSocket error: $err');
        _connected = false;
        _socketId = null;
      },
      cancelOnError: false,
    );
  }

  void _handleMessage(dynamic raw) {
    final Map<String, dynamic> decoded =
        jsonDecode(raw as String) as Map<String, dynamic>;
    final String? event = decoded['event'] as String?;

    if (event == 'pusher:connection_established') {
      final data =
          jsonDecode(decoded['data'] as String) as Map<String, dynamic>;
      _socketId = data['socket_id'] as String?;

      final pending = List<String>.from(_pendingSubscriptions);
      _pendingSubscriptions.clear();
      for (final channelName in pending) {
        _sendSubscribe(channelName);
      }
      return;
    }

    if (event == 'pusher:ping') {
      _channel?.sink.add(jsonEncode({'event': 'pusher:pong'}));
      return;
    }

    if (event == 'pusher:error') {
      return;
    }

    final String? channelName = decoded['channel'] as String?;
    if (channelName != null && _channelControllers.containsKey(channelName)) {
      dynamic payload = decoded['data'];
      if (payload is String) {
        try {
          payload = jsonDecode(payload);
        } catch (_) {
          // leave as raw string if it's not JSON
        }
      }
      _channelControllers[channelName]!.add({
        'event': event,
        'data': payload,
      });
    }
  }

  /// Subscribes to a private channel and returns a broadcast stream of
  /// {event, data} maps received on it.
  ///
  /// [channelBaseName] is WITHOUT the "private-" prefix, e.g. "user.5"
  /// or "conversation.12" — the prefix is added automatically.
  Future<Stream<Map<String, dynamic>>> listenToPrivateChannel(
      String channelBaseName) async {
    final fullChannelName = 'private-$channelBaseName';

    _channelControllers[fullChannelName] ??=
        StreamController<Map<String, dynamic>>.broadcast();

    if (!_connected) {
      await connect();
    }

    if (_socketId == null) {
      _pendingSubscriptions.add(fullChannelName);
    } else {
      await _sendSubscribe(fullChannelName);
    }

    return _channelControllers[fullChannelName]!.stream;
  }

  Future<void> _sendSubscribe(String fullChannelName) async {
    final authString = await _authorize(fullChannelName);
    if (authString == null) return;

    _channel?.sink.add(jsonEncode({
      'event': 'pusher:subscribe',
      'data': {
        'auth': authString,
        'channel': fullChannelName,
      },
    }));
  }

  /// Calls POST /broadcasting/auth to get the signed auth string required
  /// by Reverb/Pusher protocol for private channels. This is NOT the same
  /// as the Bearer token — it's an HMAC signature computed server-side
  /// using REVERB_APP_SECRET, socket_id and the channel name.
  Future<String?> _authorize(String fullChannelName) async {
    final token = await SecureStorage.getToken();
    if (token == null || _socketId == null) return null;

    final uri = Uri.parse('${ApiPath.BASE_HOST}api/broadcasting/auth');

    try {
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'socket_id': _socketId,
          'channel_name': fullChannelName,
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['auth'] as String?;
      }
    } catch (_) {
      // network error, auth endpoint unreachable, etc. — caller streams
      // simply won't receive events for this channel.
    }
    return null;
  }

  void unsubscribe(String channelBaseName) {
    final fullChannelName = 'private-$channelBaseName';
    _channel?.sink.add(jsonEncode({
      'event': 'pusher:unsubscribe',
      'data': {'channel': fullChannelName},
    }));
    _channelControllers[fullChannelName]?.close();
    _channelControllers.remove(fullChannelName);
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _connected = false;
    _socketId = null;
    for (final controller in _channelControllers.values) {
      controller.close();
    }
    _channelControllers.clear();
  }
}
