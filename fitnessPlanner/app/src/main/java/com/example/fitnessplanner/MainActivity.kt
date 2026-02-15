package com.example.fitnessplanner

import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.ListView
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.ViewModelProvider
import com.example.fitnessplanner.ui.WorkoutCreatorActivity
import com.example.fitnessplanner.ui.WorkoutExecutorActivity
import com.example.fitnessplanner.ui.WorkoutHistoryActivity
import com.example.fitnessplanner.ui.WorkoutListAdapter
import com.example.fitnessplanner.viewmodels.WorkoutListViewModel

class MainActivity : AppCompatActivity() {
    private lateinit var viewModel: WorkoutListViewModel
    private lateinit var workoutListView: ListView
    private lateinit var createButton: Button
    private lateinit var historyButton: Button
    private lateinit var adapter: WorkoutListAdapter

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        viewModel = ViewModelProvider(this).get(WorkoutListViewModel::class.java)

        workoutListView = findViewById(R.id.workout_list_view)
        createButton = findViewById(R.id.btn_create_workout)
        historyButton = findViewById(R.id.btn_workout_history)

        adapter = WorkoutListAdapter(
            this,
            mutableListOf(),
            onWorkoutClick = { workout ->
                val intent = Intent(this, WorkoutExecutorActivity::class.java)
                intent.putExtra("workoutId", workout.id)
                startActivity(intent)
            },
            onDeleteClick = { workout ->
                viewModel.deleteWorkout(workout)
            }
        )
        workoutListView.adapter = adapter

        createButton.setOnClickListener {
            startActivity(Intent(this, WorkoutCreatorActivity::class.java))
        }

        historyButton.setOnClickListener {
            startActivity(Intent(this, WorkoutHistoryActivity::class.java))
        }

        viewModel.allWorkouts.observe(this) { workouts ->
            adapter.clear()
            adapter.addAll(workouts)
            adapter.notifyDataSetChanged()
        }
    }
}

