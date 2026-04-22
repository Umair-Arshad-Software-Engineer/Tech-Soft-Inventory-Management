// lib/screens/damaged_stock/damaged_stock_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/damaged_stock_provider.dart';
import '../../models/damaged_stock_model.dart';
import '../components/loading_indicator.dart';
import '../components/error_widget.dart';

class DamagedStockDetailScreen extends StatefulWidget {
  final int damagedId;

  const DamagedStockDetailScreen({super.key, required this.damagedId});

  @override
  State<DamagedStockDetailScreen> createState() => _DamagedStockDetailScreenState();
}

class _DamagedStockDetailScreenState extends State<DamagedStockDetailScreen> {
  DamagedStockModel? _damagedItem;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final provider = Provider.of<DamagedStockProvider>(context, listen: false);
      final item = await provider.fetchDamagedItemById(widget.damagedId);

      setState(() {
        _damagedItem = item;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load item: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFAFAFC),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAFAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text('Damaged Item Details'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(_error!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_damagedItem == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAFAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text('Damaged Item Details'),
        ),
        body: const Center(child: Text('Item not found')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Damaged Stock Details',
          style: TextStyle(color: Color(0xFF2D3142), fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_damagedItem!.status == 'pending')
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'approve') {
                  _showUpdateStatusDialog('approved');
                } else if (value == 'dispose') {
                  _showUpdateStatusDialog('disposed');
                } else if (value == 'repair') {
                  _showUpdateStatusDialog('repaired');
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'approve', child: Text('Approve')),
                const PopupMenuItem(value: 'dispose', child: Text('Mark as Disposed')),
                const PopupMenuItem(value: 'repair', child: Text('Mark as Repaired')),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusHeader(),
            const SizedBox(height: 24),
            _buildProductInfo(),
            const SizedBox(height: 20),
            _buildDamageInfo(),
            const SizedBox(height: 20),
            _buildFinancialInfo(),
            const SizedBox(height: 20),
            if (_damagedItem!.notes != null) _buildNotes(),
            const SizedBox(height: 20),
            _buildTimeline(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader() {
    final formatter = NumberFormat.currency(symbol: 'Rs ');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_damagedItem!.statusColor, _damagedItem!.statusColor.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _damagedItem!.statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'ID: #${_damagedItem!.id}',
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatter.format(_damagedItem!.lossAmount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Total Loss',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductInfo() {
    // Check if product info is available
    final hasProductInfo = _damagedItem!.productName != null &&
        _damagedItem!.productName!.isNotEmpty;

    return _buildInfoCard(
      'Product Information',
      Icons.inventory_2,
      [
        _infoRow('Product Name',
            hasProductInfo ? _damagedItem!.productName! : 'Loading...'),
        _infoRow('Barcode',
            _damagedItem!.productBarcode ?? 'No barcode'),
        _infoRow('Cost Price',
            _damagedItem!.productCostPrice != null
                ? NumberFormat.currency(symbol: 'Rs ').format(_damagedItem!.productCostPrice)
                : 'Not available'),
        _infoRow('Sale Price',
            _damagedItem!.productSalePrice != null
                ? NumberFormat.currency(symbol: 'Rs ').format(_damagedItem!.productSalePrice)
                : 'Not available'),
      ],
    );
  }

  Widget _buildDamageInfo() {
    return _buildInfoCard(
      'Damage Information',
      Icons.info_outline,
      [
        _infoRow('Quantity Damaged', _damagedItem!.quantity.toString()),
        _infoRow('Reason', DamageReason.fromString(_damagedItem!.reason).displayName),
        _infoRow('Reported Date', _damagedItem!.formattedCreatedAt),
        if (_damagedItem!.approvedAt != null)
          _infoRow('Approved Date', _damagedItem!.formattedApprovedAt),
        if (_damagedItem!.approvedBy != null)
          _infoRow('Approved By', _damagedItem!.approvedBy!),
        if (_damagedItem!.repairNotes != null)
          _infoRow('Repair Notes', _damagedItem!.repairNotes!),
      ],
    );
  }

  Widget _buildFinancialInfo() {
    final estimatedLoss = _damagedItem!.estimatedLoss ?? 0;
    final actualLoss = _damagedItem!.actualLoss ?? 0;
    final difference = actualLoss - estimatedLoss;

    return _buildInfoCard(
      'Financial Impact',
      Icons.attach_money,
      [
        _infoRow('Estimated Loss',
            NumberFormat.currency(symbol: 'Rs ').format(estimatedLoss)),
        _infoRow('Actual Loss',
            NumberFormat.currency(symbol: 'Rs ').format(actualLoss)),
        _infoRow('Difference',
          NumberFormat.currency(symbol: 'Rs ').format(difference.abs()),
          color: difference > 0 ? Colors.red : (difference < 0 ? Colors.green : Colors.grey),
        ),
        if (difference != 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              difference > 0 ? '⚠️ Actual loss higher than estimated' : '✓ Actual loss lower than estimated',
              style: TextStyle(
                fontSize: 12,
                color: difference > 0 ? Colors.red : Colors.green,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNotes() {
    return _buildInfoCard(
      'Additional Notes',
      Icons.note,
      [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            _damagedItem!.notes!,
            style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeline() {
    List<Widget> timelineItems = [
      _timelineItem(
        'Reported',
        _damagedItem!.formattedCreatedAt,
        Icons.report_problem,
        true,
      ),
    ];

    if (_damagedItem!.approvedAt != null) {
      timelineItems.add(
        _timelineItem(
          'Approved',
          _damagedItem!.formattedApprovedAt,
          Icons.check_circle,
          true,
        ),
      );
    }

    if (_damagedItem!.repairedAt != null) {
      timelineItems.add(
        _timelineItem(
          'Repaired',
          _damagedItem!.formattedRepairedAt,
          Icons.build,
          true,
        ),
      );
    }

    if (_damagedItem!.disposedAt != null) {
      timelineItems.add(
        _timelineItem(
          'Disposed',
          _damagedItem!.formattedDisposedAt,
          Icons.delete,
          true,
        ),
      );
    }

    return _buildInfoCard(
      'Status Timeline',
      Icons.timeline,
      timelineItems,
    );
  }

  Widget _timelineItem(String title, String date, IconData icon, bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isCompleted ? const Color(0xFF10B981).withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isCompleted ? const Color(0xFF10B981) : Colors.grey, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2D3142)),
                ),
                Text(
                  date,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF7C3AED), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3142),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: color ?? const Color(0xFF2D3142),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showUpdateStatusDialog(String status) async {
    final notesController = TextEditingController();
    final lossController = TextEditingController();

    String dialogTitle = '';
    String dialogHint = '';

    switch (status) {
      case 'approved':
        dialogTitle = 'Approve Damage Report';
        dialogHint = 'Approval notes (optional)';
        break;
      case 'disposed':
        dialogTitle = 'Mark as Disposed';
        dialogHint = 'Disposal notes (how was it disposed?)';
        break;
      case 'repaired':
        dialogTitle = 'Mark as Repaired';
        dialogHint = 'Repair notes (describe repairs made)';
        break;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(dialogTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (status == 'disposed' || status == 'repaired' || status == 'approved')
                TextField(
                  controller: lossController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Actual Loss Amount',
                    hintText: 'Enter final loss amount (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: dialogHint,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => const Center(child: CircularProgressIndicator()),
              );

              final provider = Provider.of<DamagedStockProvider>(context, listen: false);
              final result = await provider.updateDamagedStatus(
                id: widget.damagedId,
                status: status,
                notes: notesController.text.isNotEmpty ? notesController.text : null,
                actualLoss: lossController.text.isNotEmpty ? double.tryParse(lossController.text) : null,
                repairNotes: status == 'repaired' && notesController.text.isNotEmpty ? notesController.text : null,
              );

              // Close loading dialog
              Navigator.pop(context);

              if (mounted) {
                if (result['success']) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Status updated to ${status.toUpperCase()}'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  await _loadData(); // Refresh the data
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['error'] ?? 'Failed to update status'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}