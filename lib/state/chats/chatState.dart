import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_twitter_clone/helper/utility.dart';
import 'package:flutter_twitter_clone/model/chatModel.dart';
import 'package:flutter_twitter_clone/model/user.dart';
import 'package:flutter_twitter_clone/state/appState.dart';
import 'package:flutter_twitter_clone/supabase/supabase_repository.dart';

/// Direct messages. Changes are received from the public.messages Postgres
/// Changes feed. Row visibility is restricted by the table's RLS policies.
class ChatState extends AppState {
  late bool setIsChatScreenOpen; //!obsolete

  List<ChatMessage>? _messageList;
  List<ChatMessage>? _chatUserList;
  UserModel? _chatUser;
  String serverToken = '';

  String? _myId;
  String? _otherId;
  String? _channelUserId;
  RealtimeChannel? _channel;

  SupabaseRepository get _repo => SupabaseRepository.instance;

  UserModel? get chatUser => _chatUser;
  set setChatUser(UserModel model) {
    _chatUser = model;
  }

  /// Messages of the open conversation, newest first.
  List<ChatMessage>? get messageList {
    if (_messageList == null) return null;
    _messageList!.sort((x, y) => DateTime.parse(y.createdAt!).toLocal()
        .compareTo(DateTime.parse(x.createdAt!).toLocal()));
    return _messageList;
  }

  /// One entry per person you have chatted with (key = their user id).
  List<ChatMessage>? get chatUserList =>
      _chatUserList == null ? null : List<ChatMessage>.from(_chatUserList!);

  /// Call at app start and whenever a conversation is opened. The channel is
  /// reused for the same signed-in user and recreated after an account switch.
  void databaseInit(String userId, String myId) {
    _myId = myId;
    _otherId = userId == myId ? null : userId;
    if (myId.isEmpty) return;
    if (_channel != null && _channelUserId == myId) return;

    final previous = _channel;
    _channel = null;
    _channelUserId = myId;
    if (previous != null) {
      unawaited(_repo.db.removeChannel(previous));
    }

    final channel = _repo.db.channel('messages-$myId');
    _channel = channel
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'messages',
        callback: _onMessageRealtime,
      )
      ..subscribe((status, error) {
        debugPrint('Messages Realtime [$myId]: $status${error == null ? '' : ' ($error)'}');
        if (status == RealtimeSubscribeStatus.subscribed) {
          // A fresh snapshot after subscription and every reconnect prevents
          // an event missed during a network interruption from leaving stale UI.
          getUserChatList(myId);
          if (_otherId != null) getChatDetailAsync();
        }
      });
  }

  @override
  void dispose() {
    final channel = _channel;
    _channel = null;
    _channelUserId = null;
    if (channel != null) unawaited(_repo.db.removeChannel(channel));
    super.dispose();
  }

  /// Push tokens are registered by PushNotificationService after sign-in.
  void getFCMServerKey() {}

  /// Load the inbox: latest message with each person.
  Future<void> getUserChatList(String userId) async {
    try {
      final rows = await _repo.fetchInboxRows(userId);
      if (_myId != null && _myId != userId) return;
      final latest = <String, Map<String, dynamic>>{};
      for (final row in rows) {
        // This screen is the direct-message inbox. Group rows are handled by
        // the group conversation feature, not represented as a person.
        if (row['group_id'] != null || row['recipient'] == null) continue;
        final sender = row['sender']?.toString();
        final recipient = row['recipient']?.toString();
        final other = sender == userId ? recipient : sender;
        if (other == null || other.isEmpty) continue;
        latest.putIfAbsent(other, () => row);
      }
      _chatUserList = latest.entries
          .map((entry) => _summaryFor(entry.key, entry.value))
          .toList()
        ..sort((x, y) => DateTime.parse(y.createdAt!)
            .compareTo(DateTime.parse(x.createdAt!)));
      notifyListeners();
    } catch (error) {
      cprint(error, errorIn: 'getUserChatList');
    }
  }

  /// Load the open conversation.
  Future<void> getChatDetailAsync() async {
    final me = _myId;
    final other = _chatUser?.userId ?? _otherId;
    if (me == null || other == null) return;
    try {
      final rows = await _repo.fetchConversation(me, other);
      if (_myId != me || (_chatUser?.userId ?? _otherId) != other) return;
      _messageList = rows.map(_fromRow).toList();
      notifyListeners();
      _repo.markConversationRead(me, other).catchError((error) => cprint(error));
    } catch (error) {
      cprint(error, errorIn: 'getChatDetailAsync');
    }
  }

  /// Send a message to the open conversation.
  void onMessageSubmitted(ChatMessage message) async {
    final recipient = _chatUser?.userId ?? message.receiverId;
    if (recipient.isEmpty || (message.message ?? '').trim().isEmpty) return;
    try {
      final row = await _repo.sendMessage(
        recipient: recipient,
        text: message.message!.trim(),
      );
      _addMessage(_fromRow(row));
      _upsertInbox(recipient, row);
      notifyListeners();
      Utility.logEvent('send_message', parameter: {});
    } catch (error) {
      cprint(error, errorIn: 'onMessageSubmitted');
    }
  }

  String getChannelName(String user1, String user2) {
    final list = [user1, user2]..sort();
    return '${list[0]}-${list[1]}';
  }

  /// Update the inbox preview and detach the active conversation filter.
  void onChatScreenClosed() {
    final other = _chatUser?.userId;
    if (_chatUserList != null && other != null) {
      final index = _chatUserList!.indexWhere((x) => x.key == other);
      if (index >= 0 && _messageList != null && _messageList!.isNotEmpty) {
        final latest = _messageList!.first;
        _chatUserList![index].message = latest.message;
        _chatUserList![index].createdAt = latest.createdAt;
      }
    }
    _otherId = null;
    notifyListeners();
  }

  /// Kept for existing callers. FCM push delivery is handled server-side.
  void sendAndRetrieveMessage(ChatMessage model) {}

  ChatMessage _fromRow(Map<String, dynamic> row) {
    final createdAt = row['created_at']?.toString() ??
        DateTime.now().toUtc().toIso8601String();
    return ChatMessage(
      key: row['id']?.toString(),
      senderId: row['sender']?.toString() ?? '',
      message: row['text']?.toString(),
      seen: row['read_at'] != null,
      createdAt: createdAt,
      timeStamp: createdAt,
      senderName: '',
      receiverId: row['recipient']?.toString() ?? '',
    );
  }

  ChatMessage _summaryFor(String other, Map<String, dynamic> row) {
    final model = _fromRow(row);
    model.key = other;
    return model;
  }

  void _addMessage(ChatMessage model) {
    _messageList ??= <ChatMessage>[];
    final index = _messageList!.indexWhere((x) => x.key == model.key);
    if (index >= 0) {
      _messageList![index] = model;
    } else {
      _messageList!.add(model);
    }
  }

  void _upsertInbox(String other, Map<String, dynamic> row) {
    _chatUserList ??= <ChatMessage>[];
    final summary = _summaryFor(other, row);
    final index = _chatUserList!.indexWhere((x) => x.key == other);
    if (index >= 0) {
      final existing = _chatUserList![index];
      final existingTime = DateTime.tryParse(existing.createdAt ?? '');
      final incomingTime = DateTime.tryParse(summary.createdAt ?? '');
      if (existingTime != null && incomingTime != null &&
          incomingTime.isBefore(existingTime)) {
        return;
      }
      _chatUserList![index] = summary;
    } else {
      _chatUserList!.add(summary);
    }
    _chatUserList!.sort((x, y) => DateTime.parse(y.createdAt!)
        .compareTo(DateTime.parse(x.createdAt!)));
  }

  void _onMessageRealtime(PostgresChangePayload payload) {
    final me = _myId;
    if (me == null) return;

    if (payload.eventType == PostgresChangeEvent.delete) {
      final oldRow = payload.oldRecord;
      final id = oldRow['id']?.toString();
      if (id != null) {
        _messageList?.removeWhere((message) => message.key == id);
        notifyListeners();
      }
      getUserChatList(me);
      return;
    }

    final row = payload.newRecord;
    if (row.isEmpty || row['id'] == null) return;
    if (row['group_id'] != null) return;

    final sender = row['sender']?.toString();
    final recipient = row['recipient']?.toString();
    if (sender != me && recipient != me) return;
    final other = sender == me ? recipient : sender;
    if (other == null || other.isEmpty) return;

    if (payload.eventType == PostgresChangeEvent.insert) {
      _upsertInbox(other, row);
      if (_otherId == other) {
        _addMessage(_fromRow(row));
        // Incoming messages are immediately marked read while this chat is
        // open. The resulting UPDATE only changes the read receipt, not the
        // inbox preview ordering.
        if (recipient == me && sender != me) {
          _repo.markConversationRead(me, other).catchError((error) => cprint(error));
        }
      }
      notifyListeners();
      return;
    }

    if (payload.eventType == PostgresChangeEvent.update && _otherId == other) {
      final id = row['id'].toString();
      final index = _messageList?.indexWhere((message) => message.key == id) ?? -1;
      if (index >= 0) {
        _messageList![index] = _fromRow(row);
        notifyListeners();
      }
    }
  }
}


