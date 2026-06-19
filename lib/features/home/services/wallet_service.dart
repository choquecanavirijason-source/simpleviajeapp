import 'dart:math';
import '../data/wallet_models.dart';

class WalletService {
  final _rng = Random();

  Future<WalletSnapshot> loadSnapshot({bool force = false}) async {
    await Future.delayed(const Duration(milliseconds: 450)); // simulación

    final txs = _fakeTxns();
    final month = DateTime.now().month;
    final incomes = txs
        .where(
          (t) => t.direction == TxnDirection.income && t.date.month == month,
        )
        .fold<double>(0, (a, b) => a + b.amount);
    final expenses = txs
        .where(
          (t) => t.direction == TxnDirection.expense && t.date.month == month,
        )
        .fold<double>(0, (a, b) => a + b.amount);

    return WalletSnapshot(
      balance: 235.50,
      monthIncomes: incomes,
      monthExpenses: expenses,
      status: WalletStatus.active,
      transactions: txs,
    );
  }

  List<WalletTxn> _fakeTxns() {
    final now = DateTime.now();
    final List<WalletTxn> list = [];
    for (int i = 0; i < 16; i++) {
      final dayOffset = _rng.nextInt(6); // últimos 6 días
      final date = DateTime(
        now.year,
        now.month,
        now.day - dayOffset,
        _rng.nextInt(23),
        _rng.nextInt(59),
      );
      final dir = _rng.nextBool() ? TxnDirection.income : TxnDirection.expense;
      final status = [
        TxnStatus.done,
        TxnStatus.pending,
        TxnStatus.failed,
      ][_rng.nextInt(3)];
      final method = TxnMethod.values[_rng.nextInt(TxnMethod.values.length)];
      final amount = dir == TxnDirection.income
          ? 10 + _rng.nextInt(90) + _rng.nextDouble()
          : 5 + _rng.nextInt(60) + _rng.nextDouble();

      list.add(
        WalletTxn(
          id: 'tx_$i',
          date: date,
          amount: double.parse(amount.toStringAsFixed(2)),
          direction: dir,
          status: status,
          method: method,
          title: dir == TxnDirection.income ? 'Recarga' : 'Pago de viaje',
          subtitle: _subtitleFor(method),
        ),
      );
    }
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  String _subtitleFor(TxnMethod m) => switch (m) {
    TxnMethod.card => 'Tarjeta **** 8234',
    TxnMethod.bank => 'Banco Unión',
    TxnMethod.cash => 'Efectivo',
    TxnMethod.transfer => 'Transferencia',
  };
}
