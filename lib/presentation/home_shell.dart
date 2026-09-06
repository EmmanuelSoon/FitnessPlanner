import 'package:flutter/material.dart';

import 'calendar_screen.dart';
import 'history_screen.dart';
import 'run_list_screen.dart';
import 'workout_list_screen.dart';

/// App root: a `NavigationBar` over an `IndexedStack` of the four top-level
/// screens. `IndexedStack` keeps each tab's widget state (including scroll
/// position) alive across switches, unlike `Navigator.push`.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _screens = [
    WorkoutListScreen(),
    CalendarScreen(),
    RunListScreen(),
    HistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.fitness_center_rounded),
            label: 'Workouts',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_rounded),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_run_rounded),
            label: 'Runs',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
