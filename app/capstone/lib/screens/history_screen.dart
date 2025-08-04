import 'package:flutter/material.dart';
import 'package:capstone/services/history_service.dart';
import 'package:capstone/screens/prediction_history.dart';
import 'package:capstone/screens/auth/auth_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:capstone/widgets/app_bottom_navbar.dart';
import '../theme.dart';
import 'package:capstone/models/patient.dart';
import 'dart:convert';
import 'dart:io';

class HistoryScreen extends StatefulWidget {
  final List<PredictionHistory>? testHistory;
  const HistoryScreen({Key? key, this.testHistory}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<PredictionHistory>> _historyFuture;
  bool _isClearing = false;
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedFilter = 'all';
  List<PredictionHistory> _allHistory = [];
  List<PredictionHistory> _filteredHistory = [];
  final List<String> _filterOptions = [
    'all',
    'sickle_cell',
    'normal',
    'high_confidence',
    'low_confidence',
    'recent_week',
    'recent_month',
  ];
  Map<String, dynamic> _analytics = {
    'recent_week': 0,
    'recent_month': 0,
    'avg_confidence': 0.0,
    'high_confidence': 0,
    'low_confidence': 0,
  };
  bool _isSelectionMode = false;
  Set<String> _selectedItems = {};
  bool _hasMoreItems = true;
  int _currentPage = 1;
  final int _itemsPerPage = 20;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.testHistory != null) {
      _allHistory = widget.testHistory!;
      _filteredHistory = widget.testHistory!;
      _isLoading = false;
    } else {
      _loadHistory();
    }
    _scrollController.addListener(_scrollListener);
  }

  void _scrollToPrediction(String predictionId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final index = _filteredHistory.indexWhere(
        (item) => item.id == predictionId,
      );

      if (index != -1) {
        final itemHeight = 120.0;
        final scrollPosition = index * itemHeight;
        _scrollController.animateTo(
          scrollPosition,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Found prediction: ${_filteredHistory[index].prediction}',
              ),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.blue[600],
            ),
          );
        }
      } else {
        if (_hasMoreItems && !_isLoading) {
          _loadMoreItems().then((_) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToPrediction(predictionId);
            });
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Prediction not found in history'),
                backgroundColor: Colors.orange[600],
              ),
            );
          }
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args['predictionId'] != null) {
      final predictionId = args['predictionId'] as String;
      _scrollToPrediction(predictionId);
    }
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final history = await HistoryService.loadHistory(
        page: _currentPage,
        limit: _itemsPerPage,
      );

      if (!mounted) return;

      setState(() {
        _allHistory = history;
        _filteredHistory = history;
        _hasMoreItems = history.length == _itemsPerPage;
        _isLoading = false;
      });
      _applyFilters();
      _calculateAnalytics();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load history: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreItems();
    }
  }

  Future<void> _loadMoreItems() async {
    if (!_hasMoreItems || _isLoading) return;

    setState(() => _isLoading = true);
    _currentPage++;

    try {
      final newItems = await HistoryService.loadHistory(
        page: _currentPage,
        limit: _itemsPerPage,
      );

      setState(() {
        _allHistory.addAll(newItems);
        _hasMoreItems = newItems.length == _itemsPerPage;
        _applyFilters();
      });
    } catch (error) {
      if (kDebugMode) {
        print('Error loading more items: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _calculateAnalytics() async {
    if (_allHistory.isEmpty) {
      setState(() {
        _analytics = {
          'recent_week': 0,
          'recent_month': 0,
          'avg_confidence': 0.0,
          'high_confidence': 0,
          'low_confidence': 0,
        };
      });
      return;
    }

    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final monthAgo = now.subtract(const Duration(days: 30));

    final recentWeek = _allHistory
        .where((h) => h.timestamp.isAfter(weekAgo))
        .length;
    final recentMonth = _allHistory
        .where((h) => h.timestamp.isAfter(monthAgo))
        .length;

    final totalConfidence = _allHistory.fold<double>(
      0.0,
      (sum, h) => sum + h.confidence,
    );
    final avgConfidence = totalConfidence / _allHistory.length;

    final highConfidence = _allHistory.where((h) => h.confidence >= 90).length;
    final lowConfidence = _allHistory.where((h) => h.confidence < 70).length;

    if (mounted) {
      setState(() {
        _analytics = {
          'recent_week': recentWeek,
          'recent_month': recentMonth,
          'avg_confidence': avgConfidence,
          'high_confidence': highConfidence,
          'low_confidence': lowConfidence,
        };
      });
    }
  }

  void _applyFilters() {
    if (_allHistory.isEmpty) {
      setState(() => _filteredHistory = []);
      return;
    }

    List<PredictionHistory> filtered = List.from(_allHistory);

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((item) {
        return item.prediction.toLowerCase().contains(query) ||
            item.id.toLowerCase().contains(query) ||
            (item.patientName?.toLowerCase().contains(query) ?? false) ||
            item.confidence.toString().contains(query) ||
            DateFormat(
              'MMM dd, yyyy',
            ).format(item.timestamp).toLowerCase().contains(query);
      }).toList();
    }

    filtered = _applyCategoryFilter(filtered);

    setState(() => _filteredHistory = filtered);
  }

  List<PredictionHistory> _applyCategoryFilter(List<PredictionHistory> items) {
    final now = DateTime.now();

    switch (_selectedFilter) {
      case 'sickle_cell':
        return items
            .where((item) => item.prediction.toLowerCase().contains('sickle'))
            .toList();
      case 'normal':
        return items
            .where((item) => item.prediction.toLowerCase().contains('normal'))
            .toList();
      case 'high_confidence':
        return items.where((item) => item.confidence >= 90).toList();
      case 'low_confidence':
        return items.where((item) => item.confidence < 70).toList();
      case 'recent_week':
        final weekAgo = now.subtract(const Duration(days: 7));
        return items.where((item) => item.timestamp.isAfter(weekAgo)).toList();
      case 'recent_month':
        final monthAgo = now.subtract(const Duration(days: 30));
        return items.where((item) => item.timestamp.isAfter(monthAgo)).toList();
      case 'all':
      default:
        return items;
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text(
          'Are you sure you want to clear all prediction history? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isClearing = true);
    try {
      await HistoryService.clearHistory();
      await _loadHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('History cleared successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear history: ${e.toString()}'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClearing = false);
      }
    }
  }

  Map<String, dynamic> _getStatistics() {
    if (_allHistory.isEmpty) {
      return {'total': 0, 'sickle_cell': 0, 'normal': 0, 'avg_confidence': 0.0};
    }

    final sickleCellCount = _allHistory
        .where((item) => item.prediction.toLowerCase().contains('sickle'))
        .length;
    final normalCount = _allHistory.length - sickleCellCount;

    final totalConfidence = _allHistory.fold<double>(
      0.0,
      (sum, item) => sum + item.confidence,
    );
    final avgConfidence = totalConfidence / _allHistory.length;

    return {
      'total': _allHistory.length,
      'sickle_cell': sickleCellCount,
      'normal': normalCount,
      'avg_confidence': avgConfidence,
    };
  }

  @override
  Widget build(BuildContext context) {
    final stats = _getStatistics();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed('/home');
            }
          },
        ),
        backgroundColor: const Color(0xFFB71C1C),
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text('Prediction History', style: appBarTitleStyle),
        actions: [
          if (_allHistory.isNotEmpty) ...[
            if (_isSelectionMode) ...[
              TextButton(
                onPressed: _selectedItems.isEmpty ? null : _bulkDelete,
                child: Text(
                  'Delete ( [0m${_selectedItems.length})',
                  style: TextStyle(
                    color: _selectedItems.isEmpty ? Colors.grey : Colors.white,
                  ),
                ),
              ),
              TextButton(
                onPressed: _toggleSelectionMode,
                child: const Text('Cancel'),
              ),
            ] else ...[
              IconButton(
                onPressed: _isClearing ? null : _clearHistory,
                icon: _isClearing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.clear_all),
                tooltip: 'Clear History',
              ),
              IconButton(
                onPressed: _toggleSelectionMode,
                icon: const Icon(Icons.select_all),
                tooltip: 'Select Multiple',
              ),
            ],
          ],
        ],
      ),
      body: Column(
        children: [
          _buildStatisticsCard(stats),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by patient name, confidence, or date...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 12,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                _applyFilters();
              },
            ),
          ),
          _buildFilterChips(),
          Expanded(child: _buildHistoryList()),
        ],
      ),
      bottomNavigationBar: const AppBottomNavBar(currentRoute: '/history'),
    );
  }

  Widget _buildStatisticsCard(Map<String, dynamic> stats) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: const Color(0xFFB71C1C)),
                const SizedBox(width: 8),
                const Text(
                  'Statistics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total',
                    '${stats['total']}',
                    Icons.history,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Sickle Cell',
                    '${stats['sickle_cell']}',
                    Icons.warning,
                    Colors.red,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Normal',
                    '${stats['normal']}',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Avg Confidence',
                    '${stats['avg_confidence'].toStringAsFixed(1)}%',
                    Icons.trending_up,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _filterOptions.length,
        itemBuilder: (context, index) {
          final filter = _filterOptions[index];
          final isSelected = _selectedFilter == filter;

          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(_getFilterLabel(filter)),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = filter;
                });
                _applyFilters();
              },
              selectedColor: const Color(0xFFB71C1C).withOpacity(0.2),
              checkmarkColor: const Color(0xFFB71C1C),
            ),
          );
        },
      ),
    );
  }

  String _getFilterLabel(String filter) {
    switch (filter) {
      case 'all':
        return 'All';
      case 'sickle_cell':
        return 'Sickle Cell';
      case 'normal':
        return 'Normal';
      case 'high_confidence':
        return 'High Confidence';
      case 'low_confidence':
        return 'Low Confidence';
      case 'recent_week':
        return 'Recent Week';
      case 'recent_month':
        return 'Recent Month';
      default:
        return filter;
    }
  }

  Widget _buildHistoryList() {
    if (_isLoading && _currentPage == 1) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _allHistory.isEmpty ? 'No history available' : 'No results found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _allHistory.isEmpty
                  ? 'Start making predictions to see your history here'
                  : 'Try adjusting your search or filters',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _filteredHistory.length + (_hasMoreItems ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _filteredHistory.length) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const SizedBox(),
            ),
          );
        }
        return _buildHistoryCard(_filteredHistory[index]);
      },
    );
  }

  Widget _buildHistoryCard(PredictionHistory item) {
    final isSickleCell = item.prediction.toLowerCase().contains('sickle');
    final confidenceColor = item.confidence >= 90
        ? Colors.green
        : item.confidence >= 70
        ? Colors.orange
        : Colors.red;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      child: InkWell(
        onTap: _isSelectionMode
            ? () => _toggleItemSelection(item.id)
            : () => _showDetails(context, item),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (_isSelectionMode) ...[
                Checkbox(
                  value: _selectedItems.contains(item.id),
                  onChanged: (value) => _toggleItemSelection(item.id),
                  activeColor: const Color(0xFFB71C1C),
                ),
                const SizedBox(width: 8),
              ],
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                  color: Colors.grey[200],
                ),
                child: FutureBuilder<bool>(
                  future: item.imageFile.exists(),
                  builder: (context, snapshot) {
                    if (snapshot.data == true) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(item.imageFile, fit: BoxFit.cover),
                      );
                    } else {
                      if (kDebugMode) {
                        print('Image file missing: ${item.imagePath}');
                      }
                      // Use a Center with a single Icon and short text to avoid overflow
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.broken_image,
                              color: Colors.grey[400],
                              size: 28,
                            ),
                            SizedBox(height: 2),
                            Text(
                              'No image',
                              style: TextStyle(fontSize: 9, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.prediction,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: confidenceColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${item.confidence.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: confidenceColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (!item.isSynced) ...[
                                const SizedBox(width: 4),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (item.patientName != null) ...[
                      Row(
                        children: [
                          Icon(Icons.person, size: 14, color: Colors.blue[600]),
                          const SizedBox(width: 4),
                          Text(
                            item.patientName!,
                            style: TextStyle(
                              color: Colors.blue[600],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat(
                            'MMM dd, yyyy - hh:mm a',
                          ).format(item.timestamp),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isSickleCell
                                ? Colors.red.withOpacity(0.1)
                                : Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isSickleCell ? 'Sickle Cell' : 'Normal',
                            style: TextStyle(
                              color: isSickleCell ? Colors.red : Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!_isSelectionMode)
                const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooterIconButton(
    BuildContext context,
    IconData icon,
    String route,
  ) {
    return IconButton(
      icon: Icon(icon),
      color: const Color(0xFFB71C1C),
      iconSize: 28,
      onPressed: () => Navigator.pushNamed(context, route),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter History'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _filterOptions.map((filter) {
              return RadioListTile<String>(
                title: Text(_getFilterLabel(filter)),
                value: filter,
                groupValue: _selectedFilter,
                onChanged: (value) {
                  setState(() {
                    _selectedFilter = value!;
                  });
                  _applyFilters();
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showDetails(BuildContext context, PredictionHistory item) {
    final isSickleCell = item.prediction.toLowerCase().contains('sickle');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isSickleCell ? Icons.warning : Icons.check_circle,
              color: isSickleCell ? Colors.red : Colors.green,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.prediction,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: FutureBuilder<bool>(
                  future: item.imageFile.exists(),
                  builder: (context, snapshot) {
                    if (snapshot.data == true) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(item.imageFile, fit: BoxFit.cover),
                      );
                    } else {
                      return Center(
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.grey[400],
                          size: 48,
                        ),
                      );
                    }
                  },
                ),
              ),
              if (item.heatmapUrl != null && item.heatmapUrl!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: _buildGradCamImage(item.heatmapUrl!),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Grad-CAM Visualization',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
              if (item.patientName != null)
                _buildDetailRow(
                  'Patient',
                  item.patientName!,
                  icon: Icons.person,
                ),
              _buildDetailRow('ID', item.id, icon: Icons.fingerprint),
              _buildDetailRow(
                'Confidence',
                '${item.confidence.toStringAsFixed(1)}%',
                icon: Icons.analytics,
              ),
              _buildDetailRow(
                'Date',
                DateFormat.yMMMd().format(item.timestamp),
                icon: Icons.calendar_today,
              ),
              _buildDetailRow(
                'Time',
                DateFormat.jm().format(item.timestamp),
                icon: Icons.access_time,
              ),
              if (!item.isSynced)
                _buildDetailRow(
                  'Sync Status',
                  'Pending',
                  icon: Icons.sync,
                  valueColor: Colors.orange,
                ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSickleCell
                      ? Colors.red.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSickleCell ? Colors.red : Colors.green,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSickleCell ? Icons.warning : Icons.check_circle,
                      color: isSickleCell ? Colors.red : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isSickleCell
                            ? 'Sickle Cell Disease Detected - Immediate medical attention recommended'
                            : 'Normal Result - No sickle cell disease detected',
                        style: TextStyle(
                          color: isSickleCell ? Colors.red : Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (item.patientId == null || item.patientName == null)
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                // Navigate to patient selection/creation screen
                final selectedPatient = await Navigator.pushNamed(
                  context,
                  '/patients',
                  arguments: {'isSelectionMode': true},
                );
                if (selectedPatient != null) {
                  await HistoryService.updatePredictionPatient(
                    item.id,
                    selectedPatient as Patient,
                  );
                  await _loadHistory();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Patient added to prediction.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              child: const Text('Add Patient'),
            )
          else
            TextButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Prediction'),
                    content: const Text(
                      'Are you sure you want to delete this prediction from history? This action cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  Navigator.pop(context);
                  await HistoryService.deleteHistoryItem(item.id);
                  await _loadHistory();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Prediction deleted.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Delete'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    IconData? icon,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
          ],
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.black87,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradCamImage(String url) {
    if (url.startsWith('data:image')) {
      // Base64 encoded image
      try {
        final base64String = url.split(',')[1];
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Failed to load base64 Grad-CAM image: $error');
            return _buildGradCamFallback();
          },
        );
      } catch (e) {
        debugPrint('Failed to decode base64 Grad-CAM image: $e');
        return _buildGradCamFallback();
      }
    } else if (url.startsWith('http')) {
      // Network URL
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Failed to load network Grad-CAM image: $error');
          return _buildGradCamFallback();
        },
      );
    } else if (url.startsWith('/')) {
      // Local file path
      final file = File(url);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Failed to load local Grad-CAM image: $error');
            return _buildGradCamFallback();
          },
        );
      } else {
        debugPrint('Local Grad-CAM file does not exist: $url');
        return _buildGradCamFallback();
      }
    } else {
      debugPrint('Unknown Grad-CAM URL format: $url');
      return _buildGradCamFallback();
    }
  }

  Widget _buildGradCamFallback() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported,
              size: 32,
              color: Colors.grey.shade600,
            ),
            const SizedBox(height: 4),
            Text(
              'Grad-CAM Unavailable',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sharePredictionDetails(PredictionHistory prediction) async {
    try {
      final user = await AuthManager.getCurrentUser();
      final userName = user?.fullName ?? 'Healthcare Worker';
      final facilityName = user?.facilityName ?? 'Healthcare Facility';

      final shareText =
          '''
        SickleClinix Prediction Report

        Patient: ${prediction.patientName ?? 'Unknown'}
        Prediction: ${prediction.prediction}
        Confidence: ${prediction.confidence.toStringAsFixed(1)}%
        Date: ${DateFormat('MMM dd, yyyy HH:mm').format(prediction.timestamp)}
        Healthcare Worker: $userName
        Facility: $facilityName

Generated by SickleClinix - Sickle Cell Detection
''';

      await Share.share(
        shareText,
        subject:
            'SickleClinix Prediction Report - ${prediction.patientName ?? 'Unknown Patient'}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: ${e.toString()}'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedItems.clear();
      }
    });
  }

  void _toggleItemSelection(String itemId) {
    setState(() {
      if (_selectedItems.contains(itemId)) {
        _selectedItems.remove(itemId);
        if (_selectedItems.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedItems.add(itemId);
      }
    });
  }

  Future<void> _bulkDelete() async {
    if (_selectedItems.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected Items'),
        content: Text(
          'Are you sure you want to delete ${_selectedItems.length} selected prediction(s)? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isClearing = true);

    try {
      for (final itemId in _selectedItems) {
        await HistoryService.deleteHistoryItem(itemId);
      }
      await _loadHistory();
      await _calculateAnalytics();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted ${_selectedItems.length} prediction(s)'),
            backgroundColor: Colors.green[600],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting items: $e'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isClearing = false;
          _isSelectionMode = false;
          _selectedItems.clear();
        });
      }
    }
  }
}
