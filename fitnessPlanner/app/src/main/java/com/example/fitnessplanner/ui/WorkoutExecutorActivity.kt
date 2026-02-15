package com.example.fitnessplanner.ui

import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.ViewModelProvider
import com.example.fitnessplanner.R
import com.example.fitnessplanner.viewmodels.WorkoutExecutorViewModel

class WorkoutExecutorActivity : AppCompatActivity() {
    private lateinit var viewModel: WorkoutExecutorViewModel
    private lateinit var workoutNameTextView: TextView
    private lateinit var exerciseNameTextView: TextView
    private lateinit var setCountTextView: TextView
    private lateinit var repCountTextView: TextView
    private lateinit var timerTextView: TextView
    private lateinit var nextSetButton: Button
    private lateinit var finishButton: Button

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_workout_executor)

        viewModel = ViewModelProvider(this).get(WorkoutExecutorViewModel::class.java)

        workoutNameTextView = findViewById(R.id.tv_workout_name)
        exerciseNameTextView = findViewById(R.id.tv_exercise_name)
        setCountTextView = findViewById(R.id.tv_set_count)
        repCountTextView = findViewById(R.id.tv_rep_count)
        timerTextView = findViewById(R.id.tv_timer)
        nextSetButton = findViewById(R.id.btn_next_set)
        finishButton = findViewById(R.id.btn_finish_workout)

        val workoutId = intent.getIntExtra("workoutId", -1)
        if (workoutId != -1) {
            viewModel.loadWorkout(workoutId)
        }

        viewModel.currentWorkout.observe(this) { workout ->
            workoutNameTextView.text = workout.name
        }

        viewModel.currentExercise.observe(this) { exercise ->
            exerciseNameTextView.text = exercise.name
        }

        viewModel.currentSetIndex.observe(this) { index ->
            val totalSets = viewModel.allSetsForExercise.value?.size ?: 0
            setCountTextView.text = "Set: ${index + 1}/$totalSets"
        }

        viewModel.currentSet.observe(this) { set ->
            repCountTextView.text = "Reps: ${set.reps}"
            // Start the rest timer after showing the exercise
            if (!viewModel.timerRunning.value!!) {
                viewModel.startRestTimer()
            }
        }

        viewModel.timerText.observe(this) { timer ->
            timerTextView.text = timer
        }

        nextSetButton.setOnClickListener {
            viewModel.cancelTimer()
            viewModel.nextSet()
        }

        finishButton.setOnClickListener {
            viewModel.finishWorkout()
            android.widget.Toast.makeText(this, "Workout completed!", android.widget.Toast.LENGTH_SHORT).show()
            finish()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        viewModel.cancelTimer()
    }
}

