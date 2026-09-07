import 'package:flutter/material.dart';

import 'calendar_screen.dart';
import 'insights_screen.dart';
import 'run_list_screen.dart';
import 'workout_list_screen.dart';

/// App root: a `NavigationBar` over an `IndexedStack` of the four top-level
/// screens. `IndexedStack` keeps each tab's widget state (including scroll
/// position) alive across switches, unlike `Navigator.push`.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  /// Lets a screen pushed on top of the shell (e.g. Workout Complete) jump
  /// straight to a tab after popping back to this route.
  static final GlobalKey<HomeShellState> navKey = GlobalKey<HomeShellState>();

  /// Index of [InsightsScreen] in [HomeShellState._screens] below — kept
  /// next to that list so the two stay in sync if the tab order ever
  /// changes. Exposed for screens that navigate to Insights via [navKey].
  static const int insightsTabIndex = 3;

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _screens = [
    WorkoutListScreen(),
    CalendarScreen(),
    RunListScreen(),
    InsightsScreen(), // index == HomeShell.insightsTabIndex
  ];

  void switchTab(int index) => setState(() => _index = index);

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
            icon: Icon(Icons.insights_rounded),
            label: 'Insights',
          ),
        ],
      ),
    );
  }
}
