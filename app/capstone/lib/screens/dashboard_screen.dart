import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hive/hive.dart';
import '../models/patient.dart';
import 'package:capstone/screens/auth/auth_manager.dart';
import 'package:capstone/screens/prediction_history.dart';
import 'package:capstone/services/history_service.dart';
import 'package:intl/intl.dart';
// import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import '../theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _totalPatients = 0;
  int _sickleCellCount = 0;
  int _normalCount = 0;
  int _totalPredictions = 0;
  int _recentPredictions = 0;
  List<Patient> _recentPatients = [];
  List<PredictionHistory> _recentHistory = [];
  bool _loading = true;
  Map<String, int> _predictionsPerWeek = {};
  Map<String, int> _patientsByGender = {};
  List<Map<String, int>> _sickleVsNormalByWeek = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _loading = true);
    final user = await AuthManager.getCurrentUser();
    final emailKey =
        user?.email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_') ?? 'anonymous';
    final patientBox = await Hive.openBox<Patient>('patients_$emailKey');

    await _cleanupInvalidGenderData(patientBox);

    // Load history from SQLite
    final history = await HistoryService.loadHistory();
    final patients = patientBox.values.toList();
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final recentHistory = history
        .where((h) => h.timestamp.isAfter(weekAgo))
        .toList();
    final totalPredictions = history.length;
    final sickleCell = history
        .where((h) => h.prediction.toLowerCase().contains('sickle'))
        .length;
    final normal = history.length - sickleCell;

    // Predictions per week
    Map<String, int> predictionsPerWeek = {};
    for (var i = 7; i >= 0; i--) {
      final weekStart = now.subtract(Duration(days: i * 7));
      final weekEnd = weekStart.add(const Duration(days: 6));
      final weekLabel = DateFormat('MMM d').format(weekStart);
      final count = history
          .where(
            (h) =>
                h.timestamp.isAfter(
                  weekStart.subtract(const Duration(days: 1)),
                ) &&
                h.timestamp.isBefore(weekEnd.add(const Duration(days: 1))),
          )
          .length;
      predictionsPerWeek[weekLabel] = count;
    }

    // Patients by gender
    Map<String, int> patientsByGender = {};
    for (var p in patients) {
      final gender = p.gender;
      if (kDebugMode && (gender != 'Male' && gender != 'Female')) {
        print(
          'Invalid gender found for patient ${p.name}: "$gender" (type: ${gender.runtimeType})',
        );
      }
      if ((gender == 'Male' || gender == 'Female')) {
        patientsByGender[gender] = (patientsByGender[gender] ?? 0) + 1;
      }
    }

    // Sickle vs Normal by week
    List<Map<String, int>> sickleVsNormalByWeek = [];
    for (var i = 7; i >= 0; i--) {
      final weekStart = now.subtract(Duration(days: i * 7));
      final weekEnd = weekStart.add(const Duration(days: 6));
      final sickle = history
          .where(
            (h) =>
                h.timestamp.isAfter(
                  weekStart.subtract(const Duration(days: 1)),
                ) &&
                h.timestamp.isBefore(weekEnd.add(const Duration(days: 1))) &&
                h.prediction.toLowerCase().contains('sickle'),
          )
          .length;
      final normal = history
          .where(
            (h) =>
                h.timestamp.isAfter(
                  weekStart.subtract(const Duration(days: 1)),
                ) &&
                h.timestamp.isBefore(weekEnd.add(const Duration(days: 1))) &&
                !h.prediction.toLowerCase().contains('sickle'),
          )
          .length;
      sickleVsNormalByWeek.add({
        'week': weekStart.millisecondsSinceEpoch,
        'sickle': sickle,
        'normal': normal,
      });
    }

    setState(() {
      _totalPatients = patients.length;
      _sickleCellCount = sickleCell;
      _normalCount = normal;
      _totalPredictions = totalPredictions;
      _recentPredictions = recentHistory.length;
      _recentPatients = patients.reversed.take(3).toList();

      // Sort most recent predictions
      final sortedHistory = List<PredictionHistory>.from(history)
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _recentHistory = sortedHistory.take(3).toList();

      _predictionsPerWeek = predictionsPerWeek;
      _patientsByGender = patientsByGender;
      _sickleVsNormalByWeek = sickleVsNormalByWeek;
      _loading = false;
    });
  }

  Future<void> _cleanupInvalidGenderData(Box<Patient> patientBox) async {
    final patients = patientBox.values.toList();
    for (var p in patients) {
      if ((p.gender != 'Male' && p.gender != 'Female')) {
        final correctedPatient = Patient(
          id: p.id,
          name: p.name,
          age: p.age,
          gender: 'Male',
          contact: p.contact,
          createdAt: p.createdAt,
          lastUpdated: DateTime.now(),
          healthworkerId: p.healthworkerId,
        );
        await patientBox.put(p.id, correctedPatient);
        if (kDebugMode) {
          print(
            'Cleaned up invalid gender for patient ${p.name} (ID: ${p.id}) from "${p.gender}" to "Male"',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
        title: const Text('Dashboard', style: appBarTitleStyle),
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildStatsCards(),
                  const SizedBox(height: 24),
                  _buildPieChart(),
                  const SizedBox(height: 24),
                  _buildLineChart(),
                  const SizedBox(height: 24),
                  _buildBarChart(),
                  const SizedBox(height: 24),
                  _buildGroupedBarChart(),
                  const SizedBox(height: 24),
                  _buildRecentActivity(),
                  const SizedBox(height: 24),
                  _buildQuickActions(context),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _statCard('Patients', _totalPatients, Icons.people, Colors.blue),
        _statCard(
          'Predictions',
          _totalPredictions,
          Icons.analytics,
          Colors.green,
        ),
        _statCard('Sickle Cell', _sickleCellCount, Icons.warning, Colors.red),
        _statCard('Normal', _normalCount, Icons.check_circle, Colors.green),
      ],
    );
  }

  Widget _statCard(String label, int value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Container(
        width: 75,
        height: 110,
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Prediction Distribution',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      color: Colors.red,
                      value: _sickleCellCount.toDouble(),
                      title: 'Sickle',
                      radius: 50,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    PieChartSectionData(
                      color: Colors.green,
                      value: _normalCount.toDouble(),
                      title: 'Normal',
                      radius: 50,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  sectionsSpace: 2,
                  centerSpaceRadius: 30,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart() {
    final weekLabels = _predictionsPerWeek.keys.toList();
    final weekCounts = _predictionsPerWeek.values.toList();
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Predictions Per Week',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < weekLabels.length) {
                            return Text(
                              weekLabels[idx],
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                        interval: 1,
                      ),
                    ),
                  ),
                  minY: 0,
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(
                        weekCounts.length,
                        (i) => FlSpot(i.toDouble(), weekCounts[i].toDouble()),
                      ),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    final genders = _patientsByGender.keys.toList();
    final counts = _patientsByGender.values.toList();
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Patients by Gender',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < genders.length) {
                            return Text(
                              genders[idx],
                              style: const TextStyle(fontSize: 12),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                        interval: 1,
                      ),
                    ),
                  ),
                  barGroups: List.generate(
                    genders.length,
                    (i) => BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: counts[i].toDouble(),
                          color: Colors.purple,
                          width: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedBarChart() {
    final weekLabels = _sickleVsNormalByWeek
        .map(
          (e) => DateFormat(
            'MMM d',
          ).format(DateTime.fromMillisecondsSinceEpoch(e['week']!)),
        )
        .toList();
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sickle Cell vs Normal by Week',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < weekLabels.length) {
                            return Text(
                              weekLabels[idx],
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                        interval: 1,
                      ),
                    ),
                  ),
                  barGroups: List.generate(
                    _sickleVsNormalByWeek.length,
                    (i) => BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: _sickleVsNormalByWeek[i]['sickle']!.toDouble(),
                          color: Colors.red,
                          width: 8,
                        ),
                        BarChartRodData(
                          toY: _sickleVsNormalByWeek[i]['normal']!.toDouble(),
                          color: Colors.green,
                          width: 8,
                        ),
                      ],
                    ),
                  ),
                  groupsSpace: 16,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 16, height: 8, color: Colors.red),
                const SizedBox(width: 4),
                const Text('Sickle'),
                const SizedBox(width: 16),
                Container(width: 16, height: 8, color: Colors.green),
                const SizedBox(width: 4),
                const Text('Normal'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Patients',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._recentPatients.map(
          (p) => ListTile(
            leading: CircleAvatar(child: Text(p.name[0].toUpperCase())),
            title: Text(p.name),
            subtitle: Text('Age: ${p.age}, Gender: ${p.gender}'),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Recent Predictions',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._recentHistory.map(
          (h) => ListTile(
            leading: Icon(
              h.prediction.toLowerCase().contains('sickle')
                  ? Icons.warning
                  : Icons.check_circle,
              color: h.prediction.toLowerCase().contains('sickle')
                  ? Colors.red
                  : Colors.green,
            ),
            title: Text(h.prediction),
            subtitle: Text(
              DateFormat('MMM dd, yyyy – HH:mm').format(h.timestamp),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/patients'),
          icon: const Icon(Icons.people),
          label: const Text('Patients'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/history'),
          icon: const Icon(Icons.analytics),
          label: const Text('History'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/predict'),
          icon: const Icon(Icons.add),
          label: const Text('New Test'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        ),
      ],
    );
  }
}
