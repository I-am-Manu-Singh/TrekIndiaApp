import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'dart:async';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:lottie/lottie.dart';
import 'leaderboard_screen.dart';

class TrekTrainingHub extends StatefulWidget {
  const TrekTrainingHub({super.key});

  @override
  State<TrekTrainingHub> createState() => _TrekTrainingHubState();
}

class _TrekTrainingHubState extends State<TrekTrainingHub> {
  final _db = DatabaseService();
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  int _streak = 0;
  int _totalCalories = 0;
  double _weeklyProgress = 0.0;

  final List<Map<String, dynamic>> _trainings = [
    {
      'title': 'Trek Prep: Warm Up',
      'category': 'Warm Up',
      'desc': 'Joint mobility & muscle activation',
      'time': '5 min',
      'level': 'All',
      'color': Colors.amber,
      'icon': Icons.bolt,
      'kcal': 50,
      'exercises': [
        {'name': 'Joint Rotations', 'duration': 60, 'instr': 'Rotate neck, shoulders, wrists, and ankles clockwise and counter-clockwise.', 'lottie': 'https://assets5.lottiefiles.com/packages/lf20_tljiz8mg.json'},
        {'name': 'Dynamic Leg Swings', 'duration': 60, 'instr': 'Hold a wall and swing each leg forward and back for 30s.', 'lottie': 'https://assets5.lottiefiles.com/packages/lf20_skm7pq.json'},
        {'name': 'Arm Circles', 'duration': 60, 'instr': 'Extend arms out and make small circles, gradually increasing size.', 'lottie': 'https://assets5.lottiefiles.com/packages/lf20_tljiz8mg.json'},
        {'name': 'Cat-Cow Stretch', 'duration': 60, 'instr': 'On all fours, arch your back up then dip it down while breathing deeply.', 'lottie': 'https://assets5.lottiefiles.com/packages/lf20_skm7pq.json'},
        {'name': 'Torso Twists', 'duration': 60, 'instr': 'Keep feet planted and rotate your upper body side to side.', 'lottie': 'https://assets5.lottiefiles.com/packages/lf20_tljiz8mg.json'},
      ]
    },
    {
      'title': 'Bodyweight Ascender',
      'category': 'Conditioning',
      'desc': 'Build trekking stamina without equipment',
      'time': '15 min',
      'level': 'Pro',
      'color': Colors.orangeAccent,
      'icon': Icons.directions_walk,
      'kcal': 150,
      'exercises': [
        {'name': 'Reverse Lunges', 'duration': 45, 'instr': 'Step back and lower your hip until both knees are bent at 90 degrees.', 'lottie': 'https://assets5.lottiefiles.com/packages/lf20_skm7pq.json'},
        {'name': 'Step-Ups', 'duration': 45, 'instr': 'Step onto a chair or box, drive your other knee high, then step down.', 'lottie': 'https://assets5.lottiefiles.com/packages/lf20_skm7pq.json'},
        {'name': 'Plank Hold', 'duration': 60, 'instr': 'Maintain a straight line from head to heels on your forearms.', 'lottie': 'https://assets5.lottiefiles.com/packages/lf20_skm7pq.json'},
        {'name': 'Push-Ups', 'duration': 45, 'instr': 'Lower your chest to the floor and push back up, keeping core tight.', 'lottie': 'https://assets4.lottiefiles.com/packages/lf20_q7vD61.json'},
        {'name': 'Mountain Climbers', 'duration': 45, 'instr': 'In plank position, drive knees to chest alternating rapidly.', 'lottie': 'https://assets5.lottiefiles.com/packages/lf20_skm7pq.json'},
      ]
    },
    {
      'title': 'Elite Gym Strength',
      'category': 'Gym',
      'desc': 'Targeted weighted exercises for heavy loads',
      'time': '20 min',
      'level': 'Elite',
      'color': Colors.redAccent,
      'icon': Icons.fitness_center,
      'kcal': 250,
      'exercises': [
        {'name': 'Goblet Squats', 'duration': 45, 'instr': 'Hold a weight at chest level and squat deep, keeping back straight.', 'lottie': 'https://assets4.lottiefiles.com/packages/lf20_q7vD61.json'},
        {'name': 'Weighted Calf Raises', 'duration': 45, 'instr': 'Hold dumbbells and rise onto your toes, then lower slowly.', 'lottie': 'https://assets4.lottiefiles.com/packages/lf20_q7vD61.json'},
        {'name': 'Dumbbell Deadlifts', 'duration': 45, 'instr': 'Hinge at hips to lower weights to shins, then snap back up.', 'lottie': 'https://assets4.lottiefiles.com/packages/lf20_q7vD61.json'},
        {'name': 'Overhead Press', 'duration': 45, 'instr': 'Press weights from shoulders to full extension above your head.', 'lottie': 'https://assets4.lottiefiles.com/packages/lf20_q7vD61.json'},
        {'name': 'Single Leg Step-ups', 'duration': 45, 'instr': 'Hold weights and step up slowly to build stability.', 'lottie': 'https://assets4.lottiefiles.com/packages/lf20_q7vD61.json'},
      ]
    },
    {
      'title': 'Recovery: Cool Down',
      'category': 'Cool Down',
      'desc': 'Post-trek muscle relaxation',
      'time': '8 min',
      'level': 'All',
      'color': Colors.teal,
      'icon': Icons.spa,
      'kcal': 30,
      'exercises': [
        {'name': 'Hamstring Stretch', 'duration': 60, 'instr': 'Sit and reach for your toes, hold for 30s each side.', 'lottie': 'https://assets2.lottiefiles.com/packages/lf20_LpxW8F.json'},
        {'name': 'Child\'s Pose', 'duration': 60, 'instr': 'Kneel and reach forward on the floor, breathing deeply.', 'lottie': 'https://assets2.lottiefiles.com/packages/lf20_LpxW8F.json'},
        {'name': 'Quad Stretch', 'duration': 60, 'instr': 'Stand on one leg and pull the other heel to your glute.', 'lottie': 'https://assets2.lottiefiles.com/packages/lf20_LpxW8F.json'},
        {'name': 'Pigeon Pose', 'duration': 60, 'instr': 'Lower one knee forward and stretch the other leg behind you.', 'lottie': 'https://assets2.lottiefiles.com/packages/lf20_LpxW8F.json'},
        {'name': 'Deep Breathing', 'duration': 60, 'instr': 'Close eyes and focus on 4-count inhale and 6-count exhale.', 'lottie': 'https://assets2.lottiefiles.com/packages/lf20_LpxW8F.json'},
      ]
    }
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final logs = await _db.fetchTrainingLogs();
      if (mounted) {
        setState(() {
          _logs = logs;
          try {
            _calculateStats();
          } catch (e) {
            debugPrint('Conditioning Stats Sync Error: $e');
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calculateStats() {
    if (_logs.isEmpty) {
      _streak = 0;
      _totalCalories = 0;
      return;
    }

    _totalCalories = _logs.fold(0, (sum, item) => sum + (item['calories_burned'] as int? ?? 0));

    // Simple Streak Logic
    final uniqueDays = _logs.map((l) => DateFormat('yyyy-MM-dd').format(DateTime.parse(l['completed_at']))).toSet().toList();
    uniqueDays.sort((a, b) => b.compareTo(a));

    int currentStreak = 0;
    DateTime checker = DateTime.now();
    
    for (int i = 0; i < uniqueDays.length; i++) {
        final day = DateFormat('yyyy-MM-dd').format(checker);
        final prevDay = DateFormat('yyyy-MM-dd').format(checker.subtract(const Duration(days: 1)));
        
        if (uniqueDays.contains(day)) {
            currentStreak++;
            checker = checker.subtract(const Duration(days: 1));
        } else if (i == 0 && !uniqueDays.contains(day)) {
            // Check if streak was only broken today
             checker = checker.subtract(const Duration(days: 1));
             continue; 
        } else {
            break;
        }
    }
    _streak = currentStreak;
    
    // Calculate weekly progress (e.g., target 4 workouts per week)
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final weekLogs = _logs.where((l) => DateTime.parse(l['completed_at']).isAfter(startOfWeek)).length;
    _weeklyProgress = (weekLogs / 4).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('CONDITIONING DEPOT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16, color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.orangeAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWeeklyStats(),
                  const SizedBox(height: 24),
                  _buildTodayStatus(),
                  const SizedBox(height: 32),
                  _buildSectionTitle('ACTIVITY HEATMAP'),
                  const SizedBox(height: 16),
                  _buildHeatMap(),
                  const SizedBox(height: 32),
                  _buildSectionTitle('TREK REQUISITES'),
                  const SizedBox(height: 20),
                  ..._trainings.map((t) => _trainingCard(t)).toList(),
                ],
              ),
            ),
    );
  }

  Widget _buildWeeklyStats() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FadeInUp(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 20)],
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PREP PROGRESS', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    const SizedBox(height: 4),
                    Text('${(_weeklyProgress * 100).toInt()}% READY', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 28, fontWeight: FontWeight.w900)),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.leaderboard_outlined, color: Colors.orangeAccent),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const LeaderboardScreen())),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.bolt, color: Colors.orangeAccent, size: 32),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _weeklyProgress,
                minHeight: 12,
                backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.orangeAccent),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _miniStat('STREAK', '$_streak DAYS', isDark),
                _miniStat('WORKOUTS', '${_logs.length}', isDark),
                _miniStat('KCAL', '${(_totalCalories / 1000).toStringAsFixed(1)}K', isDark),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTodayStatus() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final doneToday = _logs.any((l) => DateFormat('yyyy-MM-dd').format(DateTime.parse(l['completed_at'])) == today);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FadeInUp(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: doneToday ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: doneToday ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(doneToday ? Icons.check_circle : Icons.pending, color: doneToday ? Colors.greenAccent : Colors.orangeAccent),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(doneToday ? 'TREK READY' : 'STANDING BY', style: TextStyle(color: doneToday ? Colors.greenAccent : Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                   Text(doneToday ? 'Daily conditioning cycle complete.' : 'Your 24h prep cycle is pending execution.', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatMap() {
    final now = DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FadeInUp(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.03), borderRadius: BorderRadius.circular(20)),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: 28, // Last 4 weeks
          itemBuilder: (context, index) {
            final date = now.subtract(Duration(days: 27 - index));
            final dateStr = DateFormat('yyyy-MM-dd').format(date);
            final dayLogs = _logs.where((l) => DateFormat('yyyy-MM-dd').format(DateTime.parse(l['completed_at'])) == dateStr).length;
            
            Color heatColor;
            if (dayLogs == 0) heatColor = (isDark ? Colors.white10 : Colors.black12);
            else if (dayLogs == 1) heatColor = Colors.orangeAccent.withOpacity(0.4);
            else if (dayLogs == 2) heatColor = Colors.orangeAccent.withOpacity(0.7);
            else heatColor = Colors.orangeAccent;

            return Container(
              decoration: BoxDecoration(
                color: heatColor,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FadeInLeft(
      child: Text(title, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2)),
    );
  }

  Widget _trainingCard(Map<String, dynamic> t) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FadeInUp(
      child: GestureDetector(
        onTap: () => Navigator.push(
          context, 
          MaterialPageRoute(
            builder: (c) => WorkoutPlayerScreen(
              title: t['title'], 
              kcal: t['kcal'],
              exercises: List<Map<String, dynamic>>.from(t['exercises']),
            )
          )
        ).then((_) => _loadData()),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10)],
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: t['color'].withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
                child: Icon(t['icon'], color: t['color'], size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t['title'], style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(t['desc'], style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(t['time'], style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(4)),
                    child: Text(t['level'], style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 8, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WorkoutPlayerScreen extends StatefulWidget {
  final String title;
  final int kcal;
  final List<Map<String, dynamic>> exercises;
  const WorkoutPlayerScreen({super.key, required this.title, required this.kcal, required this.exercises});

  @override
  State<WorkoutPlayerScreen> createState() => _WorkoutPlayerScreenState();
}

class _WorkoutPlayerScreenState extends State<WorkoutPlayerScreen> {
  int _currentIndex = 0;
  bool _isActive = false;
  late int _timeLeft;
  Timer? _timer;
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _timeLeft = widget.exercises[0]['duration'];
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tts.stop();
    WakelockPlus.disable(); // Release screen lock on mission abort
    NotificationService.clearWorkoutNotifications();
    super.dispose();
  }

  void _speak(String text) async {
    await _tts.speak(text);
  }

  void _startTimer() {
    if (_isActive) {
      _timer?.cancel();
      setState(() => _isActive = false);
      NotificationService.showWorkoutNotification(
        title: "Workout Paused",
        body: "Resume ${widget.exercises[_currentIndex]['name']}",
      );
      return;
    }

    setState(() => _isActive = true);
    WakelockPlus.enable(); // Engage screen stabilization
    final current = widget.exercises[_currentIndex];
    
    // Initial instruction when starting an exercise
    if (_timeLeft == current['duration']) {
      _speak("Starting ${current['name']}. ${current['instr']}");
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() {
          _timeLeft--;
        });
        
        // Update notification every 5 seconds or at crucial times
        if (_timeLeft % 5 == 0 || _timeLeft <= 3) {
          NotificationService.showWorkoutNotification(
            title: "Doing ${current['name']}",
            body: "$_timeLeft seconds remaining",
            progress: current['duration'] - _timeLeft,
            maxProgress: current['duration'],
          );
        }

        if (_timeLeft <= 3 && _timeLeft > 0) {
          _speak("$_timeLeft");
        }
      } else {
        _timer?.cancel();
        _speak("Stop. Well done.");
        _nextExercise();
      }
    });

    NotificationService.showWorkoutNotification(
      title: "Active: ${current['name']}",
      body: "$_timeLeft seconds left",
      progress: current['duration'] - _timeLeft,
      maxProgress: current['duration'],
    );
  }

  void _nextExercise() async {
    if (_currentIndex < widget.exercises.length - 1) {
      setState(() {
        _currentIndex++;
        _timeLeft = widget.exercises[_currentIndex]['duration'];
        _isActive = false;
      });
      _speak("Next exercise is ${widget.exercises[_currentIndex]['name']}");
    } else {
      _finishWorkout();
    }
  }

  Future<void> _finishWorkout() async {
    _timer?.cancel();
    _speak("Trek Accomplished. You've burned ${widget.kcal} calories.");
    NotificationService.clearWorkoutNotifications();

    final totalSecs = widget.exercises.fold(0, (sum, e) => sum + (e['duration'] as int));
    await DatabaseService().logTrainingSession(
      title: widget.title,
      seconds: totalSecs,
      calories: widget.kcal,
      intensity: 'High'
    );
    await DatabaseService().addXP(50);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('TREK ACCOMPLISHED', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stars, color: Colors.orangeAccent, size: 64),
              const SizedBox(height: 16),
              const Text('You are one step closer to the summit.', style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('+50 EXP EARNED', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () { 
                Navigator.pop(c); 
                Navigator.pop(context); 
              }, 
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black),
              child: const Text('RETURN TO BASE', style: TextStyle(fontWeight: FontWeight.bold))
            )
          ],
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.exercises[_currentIndex];
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0F172A), Colors.black],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom - 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white70), 
                              onPressed: () {
                                _timer?.cancel();
                                NotificationService.clearWorkoutNotifications();
                                Navigator.pop(context);
                              }
                            ),
                            Column(
                              children: [
                                Text('EXERCISE ${_currentIndex + 1}/${widget.exercises.length}', 
                                      style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1)),
                                Container(
                                  height: 4, width: 60,
                                  margin: const EdgeInsets.only(top: 4),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      value: (_currentIndex + 1) / widget.exercises.length,
                                      backgroundColor: Colors.white10,
                                      valueColor: const AlwaysStoppedAnimation(Colors.orangeAccent),
                                    ),
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(width: 48),
                          ],
                        ),
                        const SizedBox(height: 20),
                        FadeInDown(
                          key: ValueKey(_currentIndex),
                          child: Column(
                            children: [
                              Text(current['name'].toString().toUpperCase(), 
                                   textAlign: TextAlign.center,
                                   style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 2)),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                                child: Text(widget.title.toUpperCase(), 
                                            style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    if (current['lottie'] != null)
                      FadeIn(
                        key: ValueKey('lottie_${_currentIndex}'),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Lottie.network(
                            current['lottie'],
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.contain,
                            animate: _isActive,
                            errorBuilder: (c, e, s) => Container(
                              height: 120, 
                              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)),
                              child: const Icon(Icons.fitness_center, color: Colors.white24, size: 48)
                            ),
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 24),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 220,
                          height: 220,
                          child: CircularProgressIndicator(
                            value: _timeLeft / current['duration'],
                            strokeWidth: 12,
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation<Color>(_isActive ? Colors.orangeAccent : Colors.white24),
                          ),
                        ),
                        Text('$_timeLeft', style: const TextStyle(color: Colors.white, fontSize: 80, fontWeight: FontWeight.w900)),
                      ],
                    ),

                    const SizedBox(height: 32),
                    FadeInUp(
                      key: ValueKey(_currentIndex + 100),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.white30, size: 16),
                            const SizedBox(height: 8),
                            Text(current['instr'], 
                                 textAlign: TextAlign.center, 
                                 style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic, height: 1.4)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _actionBtn(Icons.skip_previous, () {
                        if (_currentIndex > 0) {
                          _timer?.cancel();
                          setState(() {
                            _currentIndex--;
                            _timeLeft = widget.exercises[_currentIndex]['duration'];
                            _isActive = false;
                          });
                          _speak("Skipping back to ${widget.exercises[_currentIndex]['name']}");
                        }
                      }),
                      GestureDetector(
                        onTap: _startTimer,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.orangeAccent,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.orangeAccent.withOpacity(0.3), blurRadius: 15, spreadRadius: 2)],
                          ),
                          child: Icon(_isActive ? Icons.pause : Icons.play_arrow, color: Colors.black, size: 40),
                        ),
                      ),
                      _actionBtn(Icons.skip_next, () {
                        _timer?.cancel();
                        _nextExercise();
                      }),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _actionBtn(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
      child: IconButton(icon: Icon(icon, color: Colors.white, size: 30), onPressed: onTap),
    );
  }
}
