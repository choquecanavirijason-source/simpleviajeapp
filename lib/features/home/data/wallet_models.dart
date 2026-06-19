enum TxnDirection { income, expense }

enum TxnStatus { done, pending, failed }

enum TxnMethod { card, bank, cash, transfer }

class WalletTxn {
  final String id;
  final DateTime date;
  final double amount;
  final TxnDirection direction;
  final TxnStatus status;
  final TxnMethod method;
  final String title;
  final String subtitle;

  WalletTxn({
    required this.id,
    required this.date,
    required this.amount,
    required this.direction,
    required this.status,
    required this.method,
    required this.title,
    required this.subtitle,
  });
}

enum WalletStatus { active, limited, locked }

class WalletSnapshot {
  final double balance;
  final double monthIncomes;
  final double monthExpenses;
  final WalletStatus status;
  final List<WalletTxn> transactions;

  WalletSnapshot({
    required this.balance,
    required this.monthIncomes,
    required this.monthExpenses,
    required this.status,
    required this.transactions,
  });
}
