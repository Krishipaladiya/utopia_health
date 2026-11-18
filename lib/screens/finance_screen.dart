import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/clinic_store.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../widgets/common.dart';
import 'money_sheet.dart';

String rupees(int n) =>
    '₹${n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  static const _periods = {
    'today': 'Today',
    'week': 'This Week',
    'month': 'This Month',
  };
  String _direction = 'All';

  Future<void> _sendDaybook(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await runAction(
      context,
      () => api.post('/api/finance/daybook/send-whatsapp', {}),
    );
    if (ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Daybook sent on WhatsApp')),
      );
    }
  }

  Future<void> _delete(BuildContext context, LedgerEntry entry) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(entry.isIncome ? 'Remove this fee?' : 'Remove this spend?'),
        content: Text(
          '${entry.title} • ${rupees(entry.amount)}\nThe totals update right away.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (await runAction(context, () => clinic.deleteLedger(entry))) {
      messenger.showSnackBar(const SnackBar(content: Text('Entry removed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: clinic,
      builder: (context, _) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final entries = clinic.ledger.where((e) {
      if (_direction == 'In (+)') return e.isIncome;
      if (_direction == 'Out (-)') return !e.isIncome;
      return true;
    }).toList();

    return Column(
      children: [
        const ClinicHeader(),
        if (!clinic.loaded) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: RefreshIndicator(
            onRefresh: clinic.refreshFinance,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: [
                if (clinic.error != null)
                  ErrorBanner(message: clinic.error!, onRetry: clinic.loadAll),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final entry in _periods.entries)
                        FilterPill(
                          label: entry.key == 'today'
                              ? 'Today (${rupees(clinic.todayIncome)})'
                              : entry.value,
                          selected: clinic.period == entry.key,
                          onTap: () => clinic.setPeriod(entry.key),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _BalanceCard(
                  periodLabel: _periods[clinic.period] ?? 'This Month',
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => showMoneySheet(context, isFee: true),
                        icon: const Icon(Icons.add_circle_outline, size: 22),
                        label: const Text('Add Patient Fee'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 17),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => showMoneySheet(context, isFee: false),
                        icon: const Icon(
                          Icons.receipt_long_outlined,
                          size: 20,
                          color: AppColors.danger,
                        ),
                        label: const Text('Log Clinic Spend'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.chipBlue,
                          foregroundColor: AppColors.textPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 17),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _InsightsCard(entries: clinic.ledger),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'DAYBOOK & LEDGER',
                        style: AppText.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    _Segmented(
                      options: const ['All', 'In (+)', 'Out (-)'],
                      value: _direction,
                      onChanged: (v) => setState(() => _direction = v),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 26),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.receipt_long_outlined,
                          size: 34,
                          color: AppColors.textFaint,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No entries for ${(_periods[clinic.period] ?? 'this month').toLowerCase()} yet',
                          style: AppText.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Add a patient fee or log a spend above.',
                          style: AppText.inter(
                            fontSize: 12.5,
                            color: AppColors.textFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final entry in entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _LedgerTile(
                      entry: entry,
                      onDelete: () => _delete(context, entry),
                    ),
                  ),
                if (entries.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Tap an entry to remove a mistake.',
                      textAlign: TextAlign.center,
                      style: AppText.inter(
                        fontSize: 11.5,
                        color: AppColors.textFaint,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Material(
                  color: AppColors.chipBlue,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => _sendDaybook(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.description_outlined,
                            size: 20,
                            color: AppColors.primaryDark,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Send this month\'s daybook on WhatsApp',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 20,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.chipBlue,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in options)
            GestureDetector(
              onTap: () => onChanged(o),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: value == o ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: value == o
                      ? const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  o,
                  style: AppText.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: value == o
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.periodLabel});

  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'NET BALANCE • ${periodLabel.toUpperCase()}',
                  style: AppText.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppColors.chipBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_outlined,
                  size: 20,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${clinic.netBalance < 0 ? '-' : ''}${rupees(clinic.netBalance.abs())}',
                    style: AppText.poppins(
                      fontSize: 38,
                      fontWeight: FontWeight.w700,
                      color: clinic.netBalance < 0
                          ? AppColors.danger
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (clinic.summary.changePercent != null)
                AppChip(
                  label:
                      '${clinic.summary.changePercent! >= 0 ? '+' : ''}${clinic.summary.changePercent}%',
                  icon: clinic.summary.changePercent! >= 0
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  color: clinic.summary.changePercent! >= 0
                      ? const Color(0xFF7FF0B4)
                      : AppColors.dangerSoft,
                  textColor: clinic.summary.changePercent! >= 0
                      ? const Color(0xFF00522F)
                      : AppColors.danger,
                  bold: true,
                ),
            ],
          ),
          Text(
            clinic.summary.changePercent == null
                ? 'Fees collected minus clinic spends'
                : 'Fees minus spends, compared with the previous period',
            style: AppText.inter(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                Expanded(
                  flex: clinic.monthIncome > 0 ? clinic.monthIncome : 1,
                  child: SizedBox(
                    height: 7,
                    child: ColoredBox(
                      color: clinic.monthIncome + clinic.monthSpend == 0
                          ? AppColors.chipBlue
                          : AppColors.primaryDark,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  flex: clinic.monthSpend > 0 ? clinic.monthSpend : 1,
                  child: SizedBox(
                    height: 7,
                    child: ColoredBox(color: Color(0xFFD27070)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Incoming Fees',
                  value: rupees(clinic.monthIncome),
                  note:
                      '${clinic.summary.incomeCount} fee${clinic.summary.incomeCount == 1 ? '' : 's'} collected',
                  icon: Icons.arrow_downward_rounded,
                  iconColor: AppColors.primaryDark,
                  iconBg: AppColors.mint,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniStat(
                  label: 'Clinic Spends',
                  value: rupees(clinic.monthSpend),
                  note:
                      '${clinic.summary.spendCount} spend${clinic.summary.spendCount == 1 ? '' : 's'} logged',
                  icon: Icons.arrow_upward_rounded,
                  iconColor: AppColors.danger,
                  iconBg: AppColors.dangerSoft,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.note,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
  });

  final String label;
  final String value;
  final String note;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.chipBlueSoft,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.inter(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 15, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppText.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            note,
            maxLines: 2,
            style: AppText.inter(
              fontSize: 12,
              height: 1.3,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Real numbers for the chosen period: average fee, cash vs online, spend share.
class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.entries});

  final List<LedgerEntry> entries;

  @override
  Widget build(BuildContext context) {
    final fees = entries.where((e) => e.isIncome).toList();
    final income = fees.fold<int>(0, (a, e) => a + e.amount);
    final spend = entries
        .where((e) => !e.isIncome)
        .fold<int>(0, (a, e) => a + e.amount);
    final cash = fees
        .where((e) => e.mode == 'Cash')
        .fold<int>(0, (a, e) => a + e.amount);
    final online = income - cash;
    final avg = fees.isEmpty ? 0 : (income / fees.length).round();
    final spendShare = income == 0 ? null : (spend * 100 / income).round();

    Widget item(String label, String value, IconData icon) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppColors.primaryDark),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.inter(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppText.poppins(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.chipBlue,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.insights_rounded,
                size: 19,
                color: AppColors.primaryDark,
              ),
              const SizedBox(width: 6),
              Text(
                'Quick insights',
                style: AppText.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              item('Avg fee', rupees(avg), Icons.person_outline_rounded),
              item('Cash', rupees(cash), Icons.payments_outlined),
              item('Online', rupees(online), Icons.qr_code_rounded),
              item(
                'Spends',
                spendShare == null ? '-' : '$spendShare% of fees',
                Icons.pie_chart_outline_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LedgerTile extends StatelessWidget {
  const _LedgerTile({required this.entry, required this.onDelete});

  final LedgerEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = entry.isIncome ? AppColors.success : AppColors.danger;
    final bg = entry.isIncome ? AppColors.successSoft : AppColors.dangerSoft;
    final amount = entry.amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );

    return SoftCard(
      onTap: onDelete,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(entry.icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (entry.tag != null) ...[
                      const SizedBox(width: 8),
                      AppChip(
                        label: entry.tag!,
                        color: AppColors.chipBlue,
                        textColor: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  entry.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.inter(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.isIncome ? '+' : '-'}₹$amount',
                style: AppText.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                entry.note,
                style: AppText.inter(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
