package com.example.fitnessplanner.ui

import android.os.Bundle
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.EditText
import android.widget.ListView
import android.widget.Spinner
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.ViewModelProvider
import com.example.fitnessplanner.R
import com.example.fitnessplanner.data.models.Exercise
import com.example.fitnessplanner.viewmodels.WorkoutCreatorViewModel

class WorkoutCreatorActivity : AppCompatActivity() {
    private lateinit var viewModel: WorkoutCreatorViewModel
    private lateinit var workoutNameEditText: EditText
    private lateinit var workoutDescEditText: EditText
    private lateinit var exerciseNameEditText: EditText
    private lateinit var exerciseListView: ListView
    private lateinit var repsEditText: EditText
    private lateinit var restSpinner: Spinner
    private lateinit var customRestEditText: EditText
    private lateinit var addExerciseButton: Button
    private lateinit var addSetButton: Button
    private lateinit var saveWorkoutButton: Button

    private var exerciseAdapter: ArrayAdapter<String>? = null
    private var selectedExerciseId = -1
    private val restPresets = listOf(30, 60, 90, 120)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_workout_creator)

        viewModel = ViewModelProvider(this).get(WorkoutCreatorViewModel::class.java)

        workoutNameEditText = findViewById(R.id.et_workout_name)
        workoutDescEditText = findViewById(R.id.et_workout_description)
        exerciseNameEditText = findViewById(R.id.et_exercise_name)
        exerciseListView = findViewById(R.id.exercise_list_view)
        repsEditText = findViewById(R.id.et_reps)
        restSpinner = findViewById(R.id.spinner_rest_duration)
        customRestEditText = findViewById(R.id.et_custom_rest)
        addExerciseButton = findViewById(R.id.btn_add_exercise)
        addSetButton = findViewById(R.id.btn_add_set)
        saveWorkoutButton = findViewById(R.id.btn_save_workout)

        // Setup rest duration spinner
        val restAdapter = ArrayAdapter(
            this,
            android.R.layout.simple_spinner_item,
            restPresets.map { "${it}s" }
        )
        restAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
        restSpinner.adapter = restAdapter

        exerciseAdapter = ArrayAdapter(this, android.R.layout.simple_list_item_1, mutableListOf())
        exerciseListView.adapter = exerciseAdapter

        addExerciseButton.setOnClickListener {
            val name = exerciseNameEditText.text.toString().trim()
            if (name.isNotEmpty()) {
                val exercise = viewModel.addExercise(name)
                selectedExerciseId = exercise.id
                exerciseNameEditText.text.clear()
                updateExerciseList()
            }
        }

        addSetButton.setOnClickListener {
            if (selectedExerciseId == -1) {
                android.widget.Toast.makeText(this, "Please select or add an exercise", android.widget.Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }
            val reps = repsEditText.text.toString().toIntOrNull()
            if (reps == null || reps <= 0) {
                android.widget.Toast.makeText(this, "Please enter valid reps", android.widget.Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }

            val restDuration = if (customRestEditText.text.isNotEmpty()) {
                customRestEditText.text.toString().toIntOrNull() ?: restPresets[restSpinner.selectedItemPosition]
            } else {
                restPresets[restSpinner.selectedItemPosition]
            }

            viewModel.addSetToExercise(selectedExerciseId, reps, restDuration)
            repsEditText.text.clear()
            customRestEditText.text.clear()
            android.widget.Toast.makeText(this, "Set added", android.widget.Toast.LENGTH_SHORT).show()
        }

        saveWorkoutButton.setOnClickListener {
            val name = workoutNameEditText.text.toString().trim()
            if (name.isEmpty()) {
                android.widget.Toast.makeText(this, "Please enter workout name", android.widget.Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }
            val description = workoutDescEditText.text.toString().trim()
            viewModel.createWorkout(name, description)
            viewModel.saveWorkout()
            android.widget.Toast.makeText(this, "Workout saved", android.widget.Toast.LENGTH_SHORT).show()
            finish()
        }

        exerciseListView.setOnItemClickListener { _, _, position, _ ->
            selectedExerciseId = viewModel.currentExercises.value?.get(position)?.id ?: -1
            android.widget.Toast.makeText(this, "Selected exercise", android.widget.Toast.LENGTH_SHORT).show()
        }
    }

    private fun updateExerciseList() {
        exerciseAdapter?.clear()
        val exercises = viewModel.currentExercises.value ?: emptyList()
        exerciseAdapter?.addAll(exercises.map { it.name })
        exerciseAdapter?.notifyDataSetChanged()
    }
}

