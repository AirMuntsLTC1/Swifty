import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_twitter_clone/helper/utility.dart';
import 'package:flutter_twitter_clone/model/chatModel.dart';
import 'package:flutter_twitter_clone/model/user.dart';
import 'package:flutter_twitter_clone/state/appState.dart';
import 'package:flutter_twitter_clone/supabase/supabase_repository.dart';

/// Direct messages. Stored in the `messages` table.
/// The `push-notify` Edge Function (database webhook) sends the push, so the
/// app does not call FCM for chat messages.
class ChatState extends AppState {
  late bool setIsChatScreenOpen; //!obsolete

  List<ChatMessage>? _messageList;
  List<ChatMessage>? _chatUserList;
  UserModel? _chatUser;
  String serverToken = '';

  String? _myId;
  String? _otherId;
  RealtimeChannel? _channel;

  SupabaseRepository get _repo => SupabaseRepository.instance;

  UserModel? get chatUser => _chatUser;
  set setChatUser(UserModel model) {
    _chatUser = model;
  }

  /// Messages of the open conversation, newest first.
  List<ChatMessage>? get messageList {
    if (_messageList == null) return null;
    _messageList!.sort((x, y) => DateTime.parse(y.createdAt!)
        .toLocal()
        .compareTo(DateTime.parse(x.createdAt!).toLocal()));
    return _messageList;
  }

  /// One entry per person you have chatted with (key = their user id).
  List<ChatMessage>? get chatUserList {
    if (_chatUserList == null) return null;
    return List.from(_chatUserList!);
  }

  /// [userId] is the other person (may equal [myId] for the inbox only).
  void databaseInit(String userId, String myId) {
    _myId = myId;
    _otherId = userId == myId ? null : userId;
    if (_channel == null) {
      _channel = _repo.db.channel('messages-$myId')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: _onMessageRealtime,
        )
        ..subscribe();
    }
  }

  @override
  void dispose() {
    if (_channel != null) {
      _repo.db.removeChannel(_channel!);
      _channel = null;
    }
    super.dispose();
  }

  /// Push tokens are stored by AuthState.updateFCMToken().
  void getFCMServerKey() {}

  /// Load the inbox: latest message with each person.
  Future<void> getUserChatList(String userId) async {
    try {
      final rows = await _repo.fetchInboxRows(userId);
      final latest = <String, Map<String, dynamic>>{};
      for (final row in rows) {
        final other = row['sender'] == userId
            ? row['recipient'].toString()
            : row['sender'].toString();
        latest.putIfAbsent(other, () => row);
      }
      _chatUserList = latest.entries
          .map((e) => _summaryFor(e.key, e.value))
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
      _messageList = rows.map(_fromRow).toList();
      notifyListeners();
      _repo.markConversationRead(me, other).catchError((e) => cprint(e));
    } catch (error) {
      cprint(error, errorIn: 'getChatDetailAsync');
    }
  }

  /// Send a message to the open conversation.
  void onMessageSubmitted(ChatMessage message) async {
    final recipient = _chatUser?.userId ?? message.receiverId;
    try {
      final row = await _repo.sendMessage(
        recipient: recipient,
        text: message.message ?? '',
      );
      _addMessage(_fromRow(row));
      _upsertInbox(recipient, row);
      Utility.logEvent('send_message', parameter: {});
    } catch (error) {
      cprint(error, errorIn: 'onMessageSubmitted');
    }
  }

  /// Chat conversation key used before the Supabase migration. Kept so existing
  /// callers still compile. It returns the two ids in sorted order.
  String getChannelName(String user1, String user2) {
    final list = [user1, user2]..sort();
    return '${list[0]}-${list[1]}';
  }

  /// Update the inbox preview when the conversation screen closes.
  void onChatScreenClosed() {
    final other = _chatUser?.userId;
    if (_chatUserList == null || other == null) return;
    final index = _chatUserList!.indexWhere((x) => x.key == other);
    if (index >= 0 && _messageList != null && _messageList!.isNotEmpty) {
      final latest = _messageList!.first;
      _chatUserList![index].message = latest.message;
      _chatUserList![index].createdAt = latest.createdAt;
      notifyListeners();
    }
  }

  /// Push notifications for messages are sent by the database webhook.
  void sendAndRetrieveMessage(ChatMessage model) {}

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  ChatMessage _fromRow(Map<String, dynamic> row) {
    final createdAt =
        row['created_at']?.toString() ?? DateTime.now().toUtc().toIso8601String();
    return ChatMessage(
      key: row['id']?.toString(),
      senderId: row['sender'].toString(),
      message: row['text'] as String?,
      seen: row['read_at'] != null,
      createdAt: createdAt,
      timeStamp: createdAt,
      senderName: '',
      receiverId: row['recipient'].toString(),
    );
  }

  ChatMessage _summaryFor(String other, Map<String, dynamic> row) {
    final model = _fromRow(row);
    model.key = other;
    return model;
  }

  void _addMessage(ChatMessage model) {
    _messageList ??= <ChatMessage>[];
    if (!_messageList!.any((x) => x.key == model.key)) {
      _messageList!.add(model);
    }
    notifyListeners();
  }

  void _upsertInbox(String other, Map<String, dynamic> row) {
    _chatUserList ??= <ChatMessage>[];
    final summary = _summaryFor(other, row);
    final index = _chatUserList!.indexWhere((x) => x.key == other);
    if (index >= 0) {
      _chatUserList![index] = summary;
    } else {
      _chatUserList!.add(summary);
    }
  }

  void _onMessageRealtime(PostgresChangePayload payload) {
    if (payload.eventType == PostgresChangeEvent.delete) return;
    final row = payload.newRecord;
    final me = _myId;
    if (me == null || row.isEmpty || row['id'] == null) return;

    final sender = row['sender']?.toString();
    final recipient = row['recipient']?.toString();
    final other = sender == me ? recipient : sender;
    if (other == null) return;

    if (_otherId != null && other == _otherId) {
      final model = _fromRow(row);
      final index = _messageList?.indexWhere((x) => x.key == model.key) ?? -1;
      if (index >= 0) {
        _messageList![index] = model;
      } else {
        _addMessage(model);
      }
    }
    _upsertInbox(other, row);
    notifyListeners();
  }
}
