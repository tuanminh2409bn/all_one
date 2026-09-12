import 'package:flutter/material.dart';

import '../core/app_data.dart';
import '../core/bank_catalog.dart';
import 'bank_logo.dart';

class DataManagementScreen extends StatelessWidget {
  const DataManagementScreen({
    super.key,
    required this.store,
    this.initialAccountId,
    this.initialTab = 0,
  });

  final AppDataStore store;
  final String? initialAccountId;
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            '데이터 관리',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: '계좌'),
              Tab(text: '거래내역'),
              Tab(text: '받는 분'),
            ],
          ),
        ),
        body: AnimatedBuilder(
          animation: store,
          builder: (context, _) => TabBarView(
            children: [
              _AccountsPanel(store: store),
              _TransactionsPanel(
                store: store,
                initialAccountId: initialAccountId,
              ),
              _RecipientsPanel(store: store),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountsPanel extends StatelessWidget {
  const _AccountsPanel({required this.store});

  final AppDataStore store;

  @override
  Widget build(BuildContext context) {
    final accounts = store.accounts;
    return Stack(
      children: [
        if (accounts.isEmpty)
          const Center(child: Text('등록된 계좌가 없습니다.'))
        else
          ListView.separated(
            key: const Key('managed-account-list'),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 92),
            itemCount: accounts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final account = accounts[index];
              return Card(
                key: Key('managed-account-${account.id}'),
                child: ListTile(
                  leading: BankLogo(bankCode: account.bankCode, size: 44),
                  title: Text(
                    account.accountType,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${account.bankDisplayName} ${account.accountNumber}\n'
                    '${account.ownerName} · ${_money(store.balanceFor(account.id))}원',
                  ),
                  isThreeLine: true,
                  onTap: () => _editAccount(context, store, account),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _editAccount(context, store, account);
                      } else if (value == 'delete' &&
                          context.mounted &&
                          await _confirmDelete(
                            context,
                            '${account.accountType} 계좌를 삭제할까요?',
                          )) {
                        await store.archiveAccount(account.id);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('수정')),
                      PopupMenuItem(value: 'delete', child: Text('삭제')),
                    ],
                  ),
                ),
              );
            },
          ),
        Positioned(
          right: 18,
          bottom: 18,
          child: FloatingActionButton.extended(
            key: const Key('add-account'),
            onPressed: () => _editAccount(context, store, null),
            icon: const Icon(Icons.add),
            label: const Text('계좌 추가'),
          ),
        ),
      ],
    );
  }
}

class _TransactionsPanel extends StatefulWidget {
  const _TransactionsPanel({
    required this.store,
    required this.initialAccountId,
  });

  final AppDataStore store;
  final String? initialAccountId;

  @override
  State<_TransactionsPanel> createState() => _TransactionsPanelState();
}

class _TransactionsPanelState extends State<_TransactionsPanel> {
  String? _accountId;

  @override
  void initState() {
    super.initState();
    _accountId = widget.initialAccountId;
  }

  @override
  Widget build(BuildContext context) {
    final accounts = widget.store.accounts;
    if (accounts.isEmpty) {
      return const Center(child: Text('먼저 계좌를 추가해주세요.'));
    }
    if (!accounts.any((account) => account.id == _accountId)) {
      _accountId = accounts.first.id;
    }
    final accountId = _accountId!;
    final transactions = widget.store.transactionsFor(accountId);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: DropdownButtonFormField<String>(
            key: const Key('transaction-account-selector'),
            value: accountId,
            decoration: const InputDecoration(
              labelText: '계좌',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final account in accounts)
                DropdownMenuItem(
                  value: account.id,
                  child: Text(
                    '${account.bankDisplayName} ${account.accountNumber}',
                  ),
                ),
            ],
            onChanged: (value) => setState(() => _accountId = value),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              const Text('현재 잔액'),
              const Spacer(),
              Text(
                '${_money(widget.store.balanceFor(accountId))}원',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                key: const Key('add-transaction'),
                onPressed: () =>
                    _editTransaction(context, widget.store, accountId, null),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('추가'),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: transactions.isEmpty
              ? const Center(child: Text('거래내역이 없습니다.'))
              : ReorderableListView.builder(
                  key: const Key('managed-transaction-list'),
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: transactions.length,
                  onReorder: (oldIndex, newIndex) {
                    widget.store.reorderTransactions(
                      accountId,
                      oldIndex,
                      newIndex,
                    );
                  },
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    return ListTile(
                      key: ValueKey(transaction.id),
                      leading: CircleAvatar(
                        backgroundColor: transaction.incoming
                            ? const Color(0xFFE9F2FF)
                            : const Color(0xFFF2F4F8),
                        child: Icon(
                          transaction.incoming
                              ? Icons.south_west_rounded
                              : Icons.north_east_rounded,
                          color: transaction.incoming
                              ? const Color(0xFF0969F6)
                              : const Color(0xFF4C5564),
                        ),
                      ),
                      title: Text(
                        transaction.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${_dateTime(transaction.occurredAt)} · '
                        '${transaction.channel}\n'
                        '잔액 ${_money(widget.store.runningBalanceFor(transaction))}원',
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${transaction.signedAmount >= 0 ? '+' : '-'}'
                            '${_money(transaction.signedAmount.abs())}원',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: transaction.incoming
                                  ? const Color(0xFF0969F6)
                                  : const Color(0xFF151820),
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') {
                                await _editTransaction(
                                  context,
                                  widget.store,
                                  accountId,
                                  transaction,
                                );
                              } else if (value == 'duplicate') {
                                await widget.store.duplicateTransaction(
                                  transaction.id,
                                );
                              } else if (value == 'delete' &&
                                  context.mounted &&
                                  await _confirmDelete(
                                    context,
                                    '${transaction.title} 거래를 삭제할까요?',
                                  )) {
                                await widget.store.deleteTransaction(
                                  transaction.id,
                                );
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('수정')),
                              PopupMenuItem(
                                value: 'duplicate',
                                child: Text('복제'),
                              ),
                              PopupMenuItem(value: 'delete', child: Text('삭제')),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _RecipientsPanel extends StatelessWidget {
  const _RecipientsPanel({required this.store});

  final AppDataStore store;

  @override
  Widget build(BuildContext context) {
    final recipients = store.recipients;
    return Stack(
      children: [
        if (recipients.isEmpty)
          const Center(child: Text('등록된 받는 분이 없습니다.'))
        else
          ListView.builder(
            key: const Key('managed-recipient-list'),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: recipients.length,
            itemBuilder: (context, index) {
              final recipient = recipients[index];
              return ListTile(
                key: Key('managed-recipient-${recipient.id}'),
                leading: BankLogo(bankCode: recipient.bankCode, size: 46),
                title: Text(
                  recipient.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${recipient.bankCode} ${recipient.accountNumber}',
                ),
                onTap: () => _editRecipient(context, store, recipient),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      await _editRecipient(context, store, recipient);
                    } else if (value == 'delete' &&
                        context.mounted &&
                        await _confirmDelete(
                          context,
                          '${recipient.displayName} 받는 분을 삭제할까요?',
                        )) {
                      await store.deleteRecipient(recipient.id);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('수정')),
                    PopupMenuItem(value: 'delete', child: Text('삭제')),
                  ],
                ),
              );
            },
          ),
        Positioned(
          right: 18,
          bottom: 18,
          child: FloatingActionButton.extended(
            key: const Key('add-recipient'),
            onPressed: () => _editRecipient(context, store, null),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('받는 분 추가'),
          ),
        ),
      ],
    );
  }
}

Future<void> _editAccount(
  BuildContext context,
  AppDataStore store,
  BankAccount? account,
) async {
  final result = await showDialog<_AccountDraft>(
    context: context,
    builder: (_) => _AccountEditor(
      account: account,
      displayedBalance: account == null ? 0 : store.balanceFor(account.id),
    ),
  );
  if (result == null) return;
  try {
    if (account == null) {
      await store.createAccount(
        bankCode: result.bankCode,
        bankDisplayName: result.bankDisplayName,
        ownerName: result.ownerName,
        accountNumber: result.accountNumber,
        accountType: result.accountType,
        openingBalance: result.balance,
      );
    } else {
      await store.saveAccountWithCurrentBalance(
        account.copyWith(
          bankCode: result.bankCode,
          bankDisplayName: result.bankDisplayName,
          ownerName: result.ownerName,
          accountNumber: result.accountNumber,
          accountType: result.accountType,
        ),
        result.balance,
      );
    }
  } catch (error) {
    if (context.mounted) _showDataError(context, error);
  }
}

class _AccountDraft {
  const _AccountDraft({
    required this.bankCode,
    required this.bankDisplayName,
    required this.ownerName,
    required this.accountNumber,
    required this.accountType,
    required this.balance,
  });

  final String bankCode;
  final String bankDisplayName;
  final String ownerName;
  final String accountNumber;
  final String accountType;
  final int balance;
}

class _AccountEditor extends StatefulWidget {
  const _AccountEditor({required this.account, required this.displayedBalance});

  final BankAccount? account;
  final int displayedBalance;

  @override
  State<_AccountEditor> createState() => _AccountEditorState();
}

class _AccountEditorState extends State<_AccountEditor> {
  final _formKey = GlobalKey<FormState>();
  late String _bankCode = widget.account?.bankCode ?? BankCatalog.codes.first;
  late final _bankName = TextEditingController(
    text: widget.account?.bankDisplayName ?? _bankCode,
  );
  late final _owner = TextEditingController(
    text: widget.account?.ownerName ?? '',
  );
  late final _accountNumber = TextEditingController(
    text: widget.account?.accountNumber ?? '',
  );
  late final _accountType = TextEditingController(
    text: widget.account?.accountType ?? '저축예금',
  );
  late final _balance = TextEditingController(
    text: widget.displayedBalance.toString(),
  );

  @override
  void dispose() {
    _bankName.dispose();
    _owner.dispose();
    _accountNumber.dispose();
    _accountType.dispose();
    _balance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.account == null ? '계좌 추가' : '계좌 수정'),
    content: SizedBox(
      width: 460,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                key: const Key('account-bank-code'),
                value: _bankCode,
                decoration: const InputDecoration(labelText: '은행'),
                items: [
                  for (final code in BankCatalog.codes)
                    DropdownMenuItem(value: code, child: Text(code)),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    final oldCode = _bankCode;
                    _bankCode = value;
                    if (_bankName.text.isEmpty || _bankName.text == oldCode) {
                      _bankName.text = value;
                    }
                  });
                },
              ),
              _requiredField(
                _bankName,
                '표시 은행명',
                fieldKey: const Key('account-bank-name'),
              ),
              _requiredField(
                _owner,
                '예금주',
                fieldKey: const Key('account-owner'),
              ),
              _requiredField(
                _accountNumber,
                '표시 계좌번호',
                fieldKey: const Key('account-number'),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    AppDataStore.isValidAccountNumber(value ?? '')
                    ? null
                    : '3~30자리 숫자로 입력해주세요.',
              ),
              _requiredField(
                _accountType,
                '계좌 종류',
                fieldKey: const Key('account-type'),
              ),
              TextFormField(
                key: const Key('account-balance'),
                controller: _balance,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '표시 잔액'),
                validator: (value) {
                  final balance = int.tryParse(
                    value?.replaceAll(',', '') ?? '',
                  );
                  return balance == null || balance < 0
                      ? '0 이상의 숫자로 입력해주세요.'
                      : null;
                },
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(
        key: const Key('save-account'),
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            _AccountDraft(
              bankCode: _bankCode,
              bankDisplayName: _bankName.text.trim(),
              ownerName: _owner.text.trim(),
              accountNumber: _accountNumber.text.trim(),
              accountType: _accountType.text.trim(),
              balance: int.parse(_balance.text.replaceAll(',', '')),
            ),
          );
        },
        child: const Text('저장'),
      ),
    ],
  );
}

Future<void> _editTransaction(
  BuildContext context,
  AppDataStore store,
  String accountId,
  LedgerTransaction? transaction,
) async {
  final result = await showDialog<_TransactionDraft>(
    context: context,
    builder: (_) => _TransactionEditor(transaction: transaction),
  );
  if (result == null) return;
  final signedAmount = result.incoming ? result.amount : -result.amount;
  try {
    if (transaction == null) {
      await store.createTransaction(
        accountId: accountId,
        title: result.title,
        signedAmount: signedAmount,
        occurredAt: result.occurredAt,
        channel: result.channel,
      );
    } else {
      await store.saveTransaction(
        transaction.copyWith(
          title: result.title,
          signedAmount: signedAmount,
          occurredAt: result.occurredAt,
          channel: result.channel,
        ),
      );
    }
  } catch (error) {
    if (context.mounted) _showDataError(context, error);
  }
}

class _TransactionDraft {
  const _TransactionDraft({
    required this.title,
    required this.amount,
    required this.incoming,
    required this.occurredAt,
    required this.channel,
  });

  final String title;
  final int amount;
  final bool incoming;
  final DateTime occurredAt;
  final String channel;
}

class _TransactionEditor extends StatefulWidget {
  const _TransactionEditor({required this.transaction});

  final LedgerTransaction? transaction;

  @override
  State<_TransactionEditor> createState() => _TransactionEditorState();
}

class _TransactionEditorState extends State<_TransactionEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(
    text: widget.transaction?.title ?? '',
  );
  late final _amount = TextEditingController(
    text: widget.transaction?.signedAmount.abs().toString() ?? '',
  );
  late final _occurredAt = TextEditingController(
    text: _dateTime(widget.transaction?.occurredAt ?? DateTime.now()),
  );
  late final _channel = TextEditingController(
    text: widget.transaction?.channel ?? '모바일',
  );
  late bool _incoming = widget.transaction?.incoming ?? false;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _occurredAt.dispose();
    _channel.dispose();
    super.dispose();
  }

  DateTime? _parseDate(String value) {
    final trimmed = value.trim();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$').hasMatch(trimmed)) {
      return null;
    }
    final parsed = DateTime.tryParse(trimmed.replaceFirst(' ', 'T'));
    if (parsed == null || _dateTime(parsed) != trimmed) return null;
    return parsed;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.transaction == null ? '거래 추가' : '거래 수정'),
    content: SizedBox(
      width: 460,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _requiredField(_title, '표시 이름'),
              TextFormField(
                key: const Key('transaction-amount'),
                controller: _amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '금액'),
                validator: (value) {
                  final parsed = int.tryParse(value?.replaceAll(',', '') ?? '');
                  return parsed == null || parsed <= 0
                      ? '0보다 큰 금액을 입력해주세요.'
                      : null;
                },
              ),
              SwitchListTile(
                key: const Key('transaction-incoming'),
                contentPadding: EdgeInsets.zero,
                title: Text(_incoming ? '입금' : '출금'),
                value: _incoming,
                onChanged: (value) => setState(() => _incoming = value),
              ),
              TextFormField(
                key: const Key('transaction-date-time'),
                controller: _occurredAt,
                decoration: const InputDecoration(
                  labelText: '날짜·시간 (yyyy-MM-dd HH:mm:ss)',
                ),
                validator: (value) => _parseDate(value ?? '') == null
                    ? '초 단위까지 정확히 입력해주세요.'
                    : null,
              ),
              _requiredField(_channel, '거래 방식'),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(
        key: const Key('save-transaction'),
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            _TransactionDraft(
              title: _title.text.trim(),
              amount: int.parse(_amount.text.replaceAll(',', '')),
              incoming: _incoming,
              occurredAt: _parseDate(_occurredAt.text)!,
              channel: _channel.text.trim(),
            ),
          );
        },
        child: const Text('저장'),
      ),
    ],
  );
}

Future<void> _editRecipient(
  BuildContext context,
  AppDataStore store,
  SavedRecipient? recipient,
) async {
  final result = await showDialog<_RecipientDraft>(
    context: context,
    builder: (_) => _RecipientEditor(recipient: recipient),
  );
  if (result == null) return;
  try {
    if (recipient == null) {
      await store.createRecipient(
        displayName: result.displayName,
        bankCode: result.bankCode,
        accountNumber: result.accountNumber,
      );
    } else {
      await store.saveRecipient(
        recipient.copyWith(
          displayName: result.displayName,
          bankCode: result.bankCode,
          accountNumber: result.accountNumber,
        ),
      );
    }
  } catch (error) {
    if (context.mounted) _showDataError(context, error);
  }
}

class _RecipientDraft {
  const _RecipientDraft({
    required this.displayName,
    required this.bankCode,
    required this.accountNumber,
  });

  final String displayName;
  final String bankCode;
  final String accountNumber;
}

class _RecipientEditor extends StatefulWidget {
  const _RecipientEditor({required this.recipient});

  final SavedRecipient? recipient;

  @override
  State<_RecipientEditor> createState() => _RecipientEditorState();
}

class _RecipientEditorState extends State<_RecipientEditor> {
  final _formKey = GlobalKey<FormState>();
  late String _bankCode = widget.recipient?.bankCode ?? BankCatalog.codes.first;
  late final _name = TextEditingController(
    text: widget.recipient?.displayName ?? '',
  );
  late final _accountNumber = TextEditingController(
    text: widget.recipient?.accountNumber ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _accountNumber.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.recipient == null ? '받는 분 추가' : '받는 분 수정'),
    content: SizedBox(
      width: 460,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _requiredField(
              _name,
              '표시 이름',
              fieldKey: const Key('recipient-name'),
            ),
            DropdownButtonFormField<String>(
              key: const Key('recipient-bank-code'),
              value: _bankCode,
              decoration: const InputDecoration(labelText: '은행'),
              items: [
                for (final code in BankCatalog.codes)
                  DropdownMenuItem(value: code, child: Text(code)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _bankCode = value);
              },
            ),
            _requiredField(
              _accountNumber,
              '계좌번호',
              fieldKey: const Key('recipient-account-number'),
              keyboardType: TextInputType.number,
              validator: (value) =>
                  AppDataStore.isValidAccountNumber(value ?? '')
                  ? null
                  : '3~30자리 숫자로 입력해주세요.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(
        key: const Key('save-recipient'),
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            _RecipientDraft(
              displayName: _name.text.trim(),
              bankCode: _bankCode,
              accountNumber: _accountNumber.text.trim(),
            ),
          );
        },
        child: const Text('저장'),
      ),
    ],
  );
}

Widget _requiredField(
  TextEditingController controller,
  String label, {
  Key? fieldKey,
  TextInputType? keyboardType,
  String? Function(String?)? validator,
}) {
  return TextFormField(
    key: fieldKey,
    controller: controller,
    keyboardType: keyboardType,
    decoration: InputDecoration(labelText: label),
    validator:
        validator ??
        (value) => value == null || value.trim().isEmpty ? '필수 항목입니다.' : null,
  );
}

Future<bool> _confirmDelete(BuildContext context, String message) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('삭제 확인'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제'),
            ),
          ],
        ),
      ) ??
      false;
}

String _money(int value) => value.toString().replaceAllMapped(
  RegExp(r'(?<!^)(?=(\d{3})+$)'),
  (_) => ',',
);

String _dateTime(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
}

void _showDataError(BuildContext context, Object error) {
  final message = switch (error) {
    StateError(:final message) => message.toString(),
    ArgumentError(:final message) => message.toString(),
    _ => '데이터를 저장할 수 없습니다.',
  };
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
