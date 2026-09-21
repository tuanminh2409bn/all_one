import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BankAccount {
  const BankAccount({
    required this.id,
    required this.bankCode,
    required this.bankDisplayName,
    required this.ownerName,
    required this.accountNumber,
    required this.accountType,
    required this.openingBalance,
    required this.createdAt,
    this.archived = false,
  });

  final String id;
  final String bankCode;
  final String bankDisplayName;
  final String ownerName;
  final String accountNumber;
  final String accountType;
  final int openingBalance;
  final DateTime createdAt;
  final bool archived;

  BankAccount copyWith({
    String? bankCode,
    String? bankDisplayName,
    String? ownerName,
    String? accountNumber,
    String? accountType,
    int? openingBalance,
    bool? archived,
  }) {
    return BankAccount(
      id: id,
      bankCode: bankCode ?? this.bankCode,
      bankDisplayName: bankDisplayName ?? this.bankDisplayName,
      ownerName: ownerName ?? this.ownerName,
      accountNumber: accountNumber ?? this.accountNumber,
      accountType: accountType ?? this.accountType,
      openingBalance: openingBalance ?? this.openingBalance,
      createdAt: createdAt,
      archived: archived ?? this.archived,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'bankCode': bankCode,
    'bankDisplayName': bankDisplayName,
    'ownerName': ownerName,
    'accountNumber': accountNumber,
    'accountType': accountType,
    'openingBalance': openingBalance,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'archived': archived,
  };

  factory BankAccount.fromJson(Map<String, Object?> json) => BankAccount(
    id: json['id']! as String,
    bankCode: json['bankCode']! as String,
    bankDisplayName: json['bankDisplayName']! as String,
    ownerName: json['ownerName']! as String,
    accountNumber: json['accountNumber']! as String,
    accountType: json['accountType']! as String,
    openingBalance: (json['openingBalance']! as num).toInt(),
    createdAt: DateTime.parse(json['createdAt']! as String).toLocal(),
    archived: json['archived'] as bool? ?? false,
  );
}

class LedgerTransaction {
  const LedgerTransaction({
    required this.id,
    required this.accountId,
    required this.title,
    required this.signedAmount,
    required this.occurredAt,
    required this.channel,
    required this.displayOrder,
  });

  final String id;
  final String accountId;
  final String title;
  final int signedAmount;
  final DateTime occurredAt;
  final String channel;
  final int displayOrder;

  bool get incoming => signedAmount >= 0;

  LedgerTransaction copyWith({
    String? accountId,
    String? title,
    int? signedAmount,
    DateTime? occurredAt,
    String? channel,
    int? displayOrder,
  }) {
    return LedgerTransaction(
      id: id,
      accountId: accountId ?? this.accountId,
      title: title ?? this.title,
      signedAmount: signedAmount ?? this.signedAmount,
      occurredAt: occurredAt ?? this.occurredAt,
      channel: channel ?? this.channel,
      displayOrder: displayOrder ?? this.displayOrder,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'accountId': accountId,
    'title': title,
    'signedAmount': signedAmount,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'channel': channel,
    'displayOrder': displayOrder,
  };

  factory LedgerTransaction.fromJson(Map<String, Object?> json) =>
      LedgerTransaction(
        id: json['id']! as String,
        accountId: json['accountId']! as String,
        title: json['title']! as String,
        signedAmount: (json['signedAmount']! as num).toInt(),
        occurredAt: DateTime.parse(json['occurredAt']! as String).toLocal(),
        channel: json['channel']! as String,
        displayOrder: (json['displayOrder']! as num).toInt(),
      );
}

class SavedRecipient {
  const SavedRecipient({
    required this.id,
    required this.displayName,
    required this.bankCode,
    required this.accountNumber,
    this.favorite = false,
    this.showTransferWarning = true,
  });

  final String id;
  final String displayName;
  final String bankCode;
  final String accountNumber;
  final bool favorite;
  final bool showTransferWarning;

  SavedRecipient copyWith({
    String? displayName,
    String? bankCode,
    String? accountNumber,
    bool? favorite,
    bool? showTransferWarning,
  }) {
    return SavedRecipient(
      id: id,
      displayName: displayName ?? this.displayName,
      bankCode: bankCode ?? this.bankCode,
      accountNumber: accountNumber ?? this.accountNumber,
      favorite: favorite ?? this.favorite,
      showTransferWarning: showTransferWarning ?? this.showTransferWarning,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'displayName': displayName,
    'bankCode': bankCode,
    'accountNumber': accountNumber,
    'favorite': favorite,
    'showTransferWarning': showTransferWarning,
  };

  factory SavedRecipient.fromJson(Map<String, Object?> json) => SavedRecipient(
    id: json['id']! as String,
    displayName: json['displayName']! as String,
    bankCode: json['bankCode']! as String,
    accountNumber: json['accountNumber']! as String,
    favorite: json['favorite'] as bool? ?? false,
    showTransferWarning: json['showTransferWarning'] as bool? ?? true,
  );
}

class AppDataStore extends ChangeNotifier {
  AppDataStore();

  static final AppDataStore shared = AppDataStore.inMemory();

  /// Mock data is available only for isolated visual/widget tests. The live
  /// shared store is always initialized from an empty user scope.
  AppDataStore.inMemory({bool withMockData = true}) {
    if (withMockData) _addMockData();
    _initialized = true;
  }

  // Version 2 deliberately starts every user with a clean ledger instead of
  // carrying the old mockup accounts, transactions, and recipients forward.
  static const schemaVersion = 2;

  /// The transfer screen mirrors the banking app's recent-recipient limit.
  /// Keeping the limit in the data layer prevents a user from saving entries
  /// that the screen can no longer show or select.
  static const maxSavedRecipients = 50;

  /// Keeps matching and duplicate detection consistent everywhere account
  /// numbers are entered. Display formatting (for example hyphens) remains
  /// untouched; only comparisons use digits.
  static String normalizedAccountNumber(String value) =>
      value.replaceAll(RegExp(r'[^0-9]'), '');

  static bool isValidAccountNumber(String value) {
    final digits = normalizedAccountNumber(value);
    return digits.length >= 3 && digits.length <= 30;
  }

  SharedPreferences? _preferences;
  String? _storageKey;
  bool _initialized = false;
  int _idSequence = 0;
  int _updatedAtMicros = 0;
  bool _localIsFresh = false;
  DocumentReference<Map<String, dynamic>>? _remoteDocument;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _remoteSubscription;
  final List<BankAccount> _accounts = [];
  final List<LedgerTransaction> _transactions = [];
  final List<SavedRecipient> _recipients = [];
  int _homeCardMonth = 8;
  int _homeCardAmount = 6500;
  int? _homeSpendingMonthOverride;

  bool get initialized => _initialized;
  List<BankAccount> get accounts =>
      List.unmodifiable(_accounts.where((account) => !account.archived));
  List<SavedRecipient> get recipients => List.unmodifiable(_recipients);
  int get homeCardMonth => _homeCardMonth;
  int get homeCardAmount => _homeCardAmount;
  int get homeSpendingMonth =>
      _homeSpendingMonthOverride ?? DateTime.now().month;

  Future<void> initialize(String userScope) async {
    if (_initialized && _storageKey == _keyFor(userScope)) return;
    await _remoteSubscription?.cancel();
    _remoteSubscription = null;
    _remoteDocument = null;
    _preferences = await SharedPreferences.getInstance();
    _storageKey = _keyFor(userScope);
    final raw = _preferences!.getString(_storageKey!);
    final legacyRaw = raw == null
        ? _preferences!.getString(_keyForVersion(userScope, schemaVersion - 1))
        : null;
    final shouldMigrateLegacyData = legacyRaw != null;
    _accounts.clear();
    _transactions.clear();
    _recipients.clear();
    _homeSpendingMonthOverride = null;
    if (raw == null && legacyRaw == null) {
      _localIsFresh = true;
      await _persist();
    } else {
      try {
        _localIsFresh = false;
        _decode(raw ?? legacyRaw!);
        if (shouldMigrateLegacyData) {
          _removeMockupRecords();
          await _persist();
        }
      } catch (_) {
        // Recover from a partial/corrupted local write instead of preventing
        // the user from opening the app.
        _accounts.clear();
        _transactions.clear();
        _recipients.clear();
        _localIsFresh = true;
        await _persist();
      }
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> enableCloudSync({
    required FirebaseFirestore firestore,
    required String userId,
  }) async {
    await _remoteSubscription?.cancel();
    final document = firestore
        .collection('users')
        .doc(userId)
        .collection('app_data')
        .doc('state');
    _remoteDocument = document;
    try {
      final remote = await document
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 8));
      final data = remote.data();
      final remoteSchemaVersion =
          (data?['schemaVersion'] as num?)?.toInt() ?? 0;
      final remoteUpdatedAt = (data?['updatedAtMicros'] as num?)?.toInt() ?? 0;
      if (data != null && remoteSchemaVersion < schemaVersion) {
        // Existing version-1 documents can contain a mix of old mockup rows
        // and user-created rows. Retain the latter while deleting only the
        // records that belong to the mockup, then upgrade the remote schema.
        _decodeMap(Map<String, Object?>.from(data));
        _removeMockupRecords();
        _localIsFresh = false;
        await _persistLocal();
        await document.set(_snapshot());
        notifyListeners();
      } else if (data != null &&
          remoteSchemaVersion >= schemaVersion &&
          (_localIsFresh || remoteUpdatedAt > _updatedAtMicros)) {
        _decodeMap(Map<String, Object?>.from(data));
        _localIsFresh = false;
        await _persistLocal();
        notifyListeners();
      } else {
        await document.set(_snapshot());
        _localIsFresh = false;
      }
    } catch (_) {
      // SharedPreferences remains the immediate offline source. Firestore will
      // resume queued writes when a network connection is available.
    }
    _remoteSubscription = document.snapshots().listen((snapshot) async {
      final data = snapshot.data();
      if (data == null || snapshot.metadata.hasPendingWrites) return;
      final remoteSchemaVersion = (data['schemaVersion'] as num?)?.toInt() ?? 0;
      if (remoteSchemaVersion < schemaVersion) return;
      final remoteUpdatedAt = (data['updatedAtMicros'] as num?)?.toInt() ?? 0;
      if (remoteUpdatedAt <= _updatedAtMicros) return;
      try {
        _decodeMap(Map<String, Object?>.from(data));
        await _persistLocal();
        notifyListeners();
      } catch (_) {
        // Ignore malformed remote snapshots and retain the last valid local
        // state. A later valid snapshot can still be applied.
      }
    });
  }

  BankAccount? accountById(String id) {
    for (final account in _accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  int balanceFor(String accountId) {
    final account = accountById(accountId);
    if (account == null) return 0;
    return _transactions.where((item) => item.accountId == accountId).fold(
      account.openingBalance,
      (balance, item) {
        return balance + item.signedAmount;
      },
    );
  }

  List<LedgerTransaction> transactionsFor(String accountId) {
    final result =
        _transactions.where((item) => item.accountId == accountId).toList()
          ..sort((a, b) {
            final order = a.displayOrder.compareTo(b.displayOrder);
            if (order != 0) return order;
            return b.occurredAt.compareTo(a.occurredAt);
          });
    return List.unmodifiable(result);
  }

  int runningBalanceFor(LedgerTransaction target) {
    final account = accountById(target.accountId);
    if (account == null) return 0;
    final chronological =
        _transactions
            .where((item) => item.accountId == target.accountId)
            .toList()
          ..sort((a, b) {
            final time = a.occurredAt.compareTo(b.occurredAt);
            if (time != 0) return time;
            return a.id.compareTo(b.id);
          });
    var balance = account.openingBalance;
    for (final item in chronological) {
      balance += item.signedAmount;
      if (item.id == target.id) return balance;
    }
    return balance;
  }

  Future<BankAccount> saveAccount(BankAccount account) async {
    _requireInitialized();
    if (account.bankCode.trim().isEmpty ||
        account.bankDisplayName.trim().isEmpty ||
        account.ownerName.trim().isEmpty ||
        account.accountNumber.trim().isEmpty ||
        account.accountType.trim().isEmpty) {
      throw ArgumentError('Thông tin tài khoản không được để trống.');
    }
    if (!isValidAccountNumber(account.accountNumber)) {
      throw ArgumentError('Số tài khoản phải có từ 3 đến 30 chữ số.');
    }
    final duplicate = _accounts.any(
      (item) =>
          item.id != account.id &&
          !item.archived &&
          item.bankCode == account.bankCode &&
          normalizedAccountNumber(item.accountNumber) ==
              normalizedAccountNumber(account.accountNumber),
    );
    if (duplicate) {
      throw StateError('Tài khoản này đã tồn tại.');
    }
    final index = _accounts.indexWhere((item) => item.id == account.id);
    if (index == -1) {
      _accounts.add(account);
    } else {
      _accounts[index] = account;
    }
    await _commit();
    return account;
  }

  Future<BankAccount> createAccount({
    required String bankCode,
    required String bankDisplayName,
    required String ownerName,
    required String accountNumber,
    required String accountType,
    required int openingBalance,
  }) async {
    if (openingBalance < 0) {
      throw ArgumentError('Số dư không được âm.');
    }
    return saveAccount(
      BankAccount(
        id: _newId('account'),
        bankCode: bankCode,
        bankDisplayName: bankDisplayName,
        ownerName: ownerName,
        accountNumber: accountNumber,
        accountType: accountType,
        openingBalance: openingBalance,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<BankAccount> saveAccountWithCurrentBalance(
    BankAccount account,
    int desiredBalance,
  ) {
    if (desiredBalance < 0) {
      throw ArgumentError('Số dư không được âm.');
    }
    final existing = accountById(account.id);
    if (existing == null) {
      return saveAccount(account.copyWith(openingBalance: desiredBalance));
    }
    final transactionDelta = balanceFor(account.id) - existing.openingBalance;
    return saveAccount(
      account.copyWith(openingBalance: desiredBalance - transactionDelta),
    );
  }

  Future<void> archiveAccount(String accountId) async {
    final account = accountById(accountId);
    if (account == null) return;
    await saveAccount(account.copyWith(archived: true));
  }

  Future<LedgerTransaction> saveTransaction(
    LedgerTransaction transaction,
  ) async {
    _requireInitialized();
    final account = accountById(transaction.accountId);
    if (account == null || account.archived) {
      throw StateError('Không tìm thấy tài khoản của giao dịch.');
    }
    if (transaction.title.trim().isEmpty || transaction.signedAmount == 0) {
      throw ArgumentError('Tên và số tiền giao dịch phải hợp lệ.');
    }
    final index = _transactions.indexWhere((item) => item.id == transaction.id);
    final existing = index == -1 ? null : _transactions[index];
    final projectedBalance =
        balanceFor(transaction.accountId) -
        (existing?.signedAmount ?? 0) +
        transaction.signedAmount;
    if (projectedBalance < 0) {
      throw StateError('Số dư khả dụng không đủ.');
    }
    if (index == -1) {
      _transactions.add(transaction);
    } else {
      _transactions[index] = transaction;
    }
    await _commit();
    return transaction;
  }

  Future<LedgerTransaction> createTransaction({
    required String accountId,
    required String title,
    required int signedAmount,
    required DateTime occurredAt,
    required String channel,
  }) async {
    _requireInitialized();
    if (channel.trim().isEmpty) {
      throw ArgumentError('Phương thức giao dịch không được để trống.');
    }
    final account = accountById(accountId);
    if (account == null || account.archived) {
      throw StateError('Không tìm thấy tài khoản của giao dịch.');
    }
    if (title.trim().isEmpty || signedAmount == 0) {
      throw ArgumentError('Tên và số tiền giao dịch phải hợp lệ.');
    }
    if (balanceFor(accountId) + signedAmount < 0) {
      throw StateError('Số dư khả dụng không đủ.');
    }
    final existing = transactionsFor(accountId);
    for (var i = 0; i < existing.length; i++) {
      final index = _transactions.indexWhere(
        (item) => item.id == existing[i].id,
      );
      _transactions[index] = existing[i].copyWith(displayOrder: i + 1);
    }
    return saveTransaction(
      LedgerTransaction(
        id: _newId('transaction'),
        accountId: accountId,
        title: title,
        signedAmount: signedAmount,
        occurredAt: occurredAt,
        channel: channel,
        displayOrder: 0,
      ),
    );
  }

  Future<LedgerTransaction?> duplicateTransaction(String transactionId) async {
    final source = _transactions
        .where((item) => item.id == transactionId)
        .firstOrNull;
    if (source == null) return null;
    return createTransaction(
      accountId: source.accountId,
      title: source.title,
      signedAmount: source.signedAmount,
      occurredAt: source.occurredAt,
      channel: source.channel,
    );
  }

  Future<void> deleteTransaction(String transactionId) async {
    _requireInitialized();
    _transactions.removeWhere((item) => item.id == transactionId);
    await _normalizeTransactionOrder();
  }

  Future<void> reorderTransactions(
    String accountId,
    int oldIndex,
    int newIndex,
  ) async {
    _requireInitialized();
    final ordered = transactionsFor(accountId).toList();
    if (oldIndex < 0 || oldIndex >= ordered.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex < 0 || newIndex >= ordered.length) return;
    final moved = ordered.removeAt(oldIndex);
    ordered.insert(newIndex, moved);
    for (var i = 0; i < ordered.length; i++) {
      final index = _transactions.indexWhere(
        (item) => item.id == ordered[i].id,
      );
      _transactions[index] = ordered[i].copyWith(displayOrder: i);
    }
    await _commit();
  }

  Future<SavedRecipient> saveRecipient(SavedRecipient recipient) async {
    _requireInitialized();
    if (recipient.displayName.trim().isEmpty ||
        recipient.bankCode.trim().isEmpty ||
        recipient.accountNumber.trim().isEmpty) {
      throw ArgumentError('Thông tin người nhận không được để trống.');
    }
    if (!isValidAccountNumber(recipient.accountNumber)) {
      throw ArgumentError('Số tài khoản phải có từ 3 đến 30 chữ số.');
    }
    final index = _recipients.indexWhere((item) => item.id == recipient.id);
    final duplicate = _recipients.any(
      (item) =>
          item.id != recipient.id &&
          item.bankCode == recipient.bankCode &&
          normalizedAccountNumber(item.accountNumber) ==
              normalizedAccountNumber(recipient.accountNumber),
    );
    if (duplicate) {
      throw StateError('Người nhận với tài khoản này đã tồn tại.');
    }
    if (index == -1) {
      if (_recipients.length >= maxSavedRecipients) {
        throw StateError(
          'Bạn chỉ có thể lưu tối đa $maxSavedRecipients người nhận gần đây.',
        );
      }
      _recipients.add(recipient);
    } else {
      _recipients[index] = recipient;
    }
    await _commit();
    return recipient;
  }

  Future<SavedRecipient> createRecipient({
    required String displayName,
    required String bankCode,
    required String accountNumber,
    bool showTransferWarning = true,
  }) {
    return saveRecipient(
      SavedRecipient(
        id: _newId('recipient'),
        displayName: displayName,
        bankCode: bankCode,
        accountNumber: accountNumber,
        showTransferWarning: showTransferWarning,
      ),
    );
  }

  Future<void> deleteRecipient(String recipientId) async {
    _requireInitialized();
    _recipients.removeWhere((item) => item.id == recipientId);
    await _commit();
  }

  Future<void> updateHomeCardUsage({
    required int month,
    required int amount,
  }) async {
    _requireInitialized();
    if (month < 1 || month > 12) {
      throw ArgumentError('Tháng phải nằm trong khoảng từ 1 đến 12.');
    }
    if (amount < 0) {
      throw ArgumentError('Số tiền không được âm.');
    }
    _homeCardMonth = month;
    _homeCardAmount = amount;
    await _commit();
  }

  Future<void> updateHomeSpendingMonth(int month) async {
    _requireInitialized();
    if (month < 1 || month > 12) {
      throw ArgumentError('Tháng phải nằm trong khoảng từ 1 đến 12.');
    }
    _homeSpendingMonthOverride = month;
    await _commit();
  }

  Future<void> _normalizeTransactionOrder() async {
    for (final account in _accounts) {
      final ordered = transactionsFor(account.id);
      for (var i = 0; i < ordered.length; i++) {
        final index = _transactions.indexWhere(
          (item) => item.id == ordered[i].id,
        );
        _transactions[index] = ordered[i].copyWith(displayOrder: i);
      }
    }
    await _commit();
  }

  Future<void> _commit() async {
    _updatedAtMicros = DateTime.now().microsecondsSinceEpoch;
    notifyListeners();
    await _persistLocal();
    final remote = _remoteDocument;
    if (remote != null) {
      try {
        await remote.set(_snapshot());
      } catch (_) {
        // The local commit is authoritative until Firestore reconnects.
      }
    }
  }

  Future<void> _persist() async {
    _updatedAtMicros = DateTime.now().microsecondsSinceEpoch;
    await _persistLocal();
  }

  Future<void> _persistLocal() async {
    if (_preferences == null || _storageKey == null) return;
    await _preferences!.setString(_storageKey!, jsonEncode(_snapshot()));
  }

  void _decode(String raw) {
    _decodeMap(jsonDecode(raw) as Map<String, Object?>);
  }

  void _decodeMap(Map<String, Object?> json) {
    final decodedAccounts = (json['accounts']! as List<Object?>)
        .map(
          (item) =>
              BankAccount.fromJson(Map<String, Object?>.from(item! as Map)),
        )
        .toList();
    final decodedTransactions = (json['transactions']! as List<Object?>)
        .map(
          (item) => LedgerTransaction.fromJson(
            Map<String, Object?>.from(item! as Map),
          ),
        )
        .toList();
    final decodedRecipients = (json['recipients']! as List<Object?>)
        .map(
          (item) =>
              SavedRecipient.fromJson(Map<String, Object?>.from(item! as Map)),
        )
        .toList();
    final accountIds = decodedAccounts.map((account) => account.id).toSet();
    if (decodedTransactions.any(
      (transaction) => !accountIds.contains(transaction.accountId),
    )) {
      throw const FormatException(
        'Giao dịch tham chiếu tài khoản không tồn tại.',
      );
    }

    _accounts
      ..clear()
      ..addAll(decodedAccounts);
    _transactions
      ..clear()
      ..addAll(decodedTransactions);
    _recipients
      ..clear()
      ..addAll(decodedRecipients);
    _idSequence = (json['idSequence'] as num?)?.toInt() ?? 0;
    _updatedAtMicros = (json['updatedAtMicros'] as num?)?.toInt() ?? 0;
    _homeCardMonth = (json['homeCardMonth'] as num?)?.toInt() ?? 8;
    _homeCardAmount = (json['homeCardAmount'] as num?)?.toInt() ?? 6500;
    final decodedSpendingMonth = (json['homeSpendingMonth'] as num?)?.toInt();
    _homeSpendingMonthOverride =
        decodedSpendingMonth != null &&
            decodedSpendingMonth >= 1 &&
            decodedSpendingMonth <= 12
        ? decodedSpendingMonth
        : null;
  }

  Map<String, Object?> _snapshot() => {
    'schemaVersion': schemaVersion,
    'updatedAtMicros': _updatedAtMicros,
    'idSequence': _idSequence,
    'accounts': _accounts.map((item) => item.toJson()).toList(),
    'transactions': _transactions.map((item) => item.toJson()).toList(),
    'recipients': _recipients.map((item) => item.toJson()).toList(),
    'homeCardMonth': _homeCardMonth,
    'homeCardAmount': _homeCardAmount,
    'homeSpendingMonth': _homeSpendingMonthOverride,
  };

  void _addMockData() {
    const accountId = 'default-account';
    _accounts.add(
      BankAccount(
        id: accountId,
        bankCode: '농협',
        bankDisplayName: 'NH농협은행',
        ownerName: 'BUI PHUONG',
        accountNumber: '302-2180-4371-91',
        accountType: 'NH올원모임통장',
        openingBalance: 560289,
        createdAt: DateTime(2026, 7, 20),
      ),
    );
    final seedTransactions = [
      ('TRINHTRUNGMINH', -1000, DateTime(2026, 7, 22, 10, 32, 8), '모바일'),
      ('정상희', -6100, DateTime(2026, 7, 22, 7, 0, 34), '모바일'),
      ('양기석(양화감자탕(', -40000, DateTime(2026, 7, 22, 1, 34, 45), '모바일'),
      ('Npay', -104700, DateTime(2026, 7, 21, 17, 58, 7), '모바일'),
      ('THANH_한패스', -20000, DateTime(2026, 7, 21, 16, 30, 45), '모바일'),
      ('LEKIMCUC', 200000, DateTime(2026, 7, 21, 1, 36, 21), '타행모바일뱅킹'),
      ('LE KIM CUC', -200000, DateTime(2026, 7, 21, 0, 6, 10), '모바일'),
    ];
    for (var i = 0; i < seedTransactions.length; i++) {
      final item = seedTransactions[i];
      _transactions.add(
        LedgerTransaction(
          id: 'seed-transaction-$i',
          accountId: accountId,
          title: item.$1,
          signedAmount: item.$2,
          occurredAt: item.$3,
          channel: item.$4,
          displayOrder: i,
        ),
      );
    }
    const seedRecipients = [
      ('TRINH TRUN', '우리', '1002365702814'),
      ('정상희', '토스뱅크', '100265855542'),
      ('양기석(양화감자탕)', '하나', '63491065897607'),
      ('Npay', '신한', '56020228505759'),
      ('THANH_한패스', '전북', '9105205506132'),
      ('LE KIM CUC', '국민', '91800101463625'),
      ('황지환', '새마을', '9002162430854'),
      ('BUI PHUONG', '토스뱅크', '100263424344'),
    ];
    for (var i = 0; i < seedRecipients.length; i++) {
      final item = seedRecipients[i];
      _recipients.add(
        SavedRecipient(
          id: 'seed-recipient-$i',
          displayName: item.$1,
          bankCode: item.$2,
          accountNumber: item.$3,
        ),
      );
    }
  }

  void _removeMockupRecords() {
    const mockAccountId = 'default-account';
    _accounts.removeWhere((account) => account.id == mockAccountId);
    _transactions.removeWhere(
      (transaction) =>
          transaction.accountId == mockAccountId ||
          transaction.id.startsWith('seed-transaction-'),
    );
    _recipients.removeWhere(
      (recipient) => recipient.id.startsWith('seed-recipient-'),
    );
  }

  String _newId(String prefix) {
    _idSequence += 1;
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$_idSequence';
  }

  String _keyFor(String scope) => _keyForVersion(scope, schemaVersion);

  String _keyForVersion(String scope, int version) =>
      'nh_allone_app_data_v$version-${base64Url.encode(utf8.encode(scope))}';

  void _requireInitialized() {
    if (!_initialized) {
      throw StateError('AppDataStore chưa được khởi tạo.');
    }
  }

  @override
  void dispose() {
    _remoteSubscription?.cancel();
    super.dispose();
  }
}
