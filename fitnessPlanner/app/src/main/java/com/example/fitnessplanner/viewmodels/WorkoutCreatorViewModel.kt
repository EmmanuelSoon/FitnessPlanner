package com.example.fitnessplanner.viewmodels

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.viewModelScope
import com.example.fitnessplanner.data.WorkoutDatabase
import com.example.fitnessplanner.data.models.Exercise
import com.example.fitnessplanner.data.models.Workout
import com.example.fitnessplanner.data.models.WorkoutSet
import kotlinx.coroutines.launch

class WorkoutCreatorViewModel(application: Application) : AndroidViewModel(application) {
    private val database = WorkoutDatabase.getInstance(application)
    private val workoutDao = database.workoutDao()
    private val exerciseDao = database.exerciseDao()
    private val workoutSetDao = database.workoutSetDao()

    val currentWorkout = MutableLiveData<Workout>()
    val currentExercises = MutableLiveData<MutableList<Exercise>>(mutableListOf())
    val currentSets = MutableLiveData<MutableMap<Int, MutableList<WorkoutSet>>>(mutableMapOf())

    fun createWorkout(name: String, description: String = "") {
        currentWorkout.value = Workout(name = name, description = description)
    }

    fun addExercise(name: String): Exercise {
        val exercises = currentExercises.value ?: mutableListOf()
        val exercise = Exercise(
            workoutId = 0,
            name = name,
            order = exercises.size
        )
        exercises.add(exercise)
        currentExercises.value = exercises
        return exercise
    }

    fun removeExercise(exercise: Exercise) {
        val exercises = currentExercises.value?.toMutableList() ?: return
        exercises.remove(exercise)
        currentExercises.value = exercises
    }

    fun addSetToExercise(exerciseId: Int, reps: Int, restDuration: Int) {
        val sets = currentSets.value ?: mutableMapOf()
        val exerciseSets = sets.getOrPut(exerciseId) { mutableListOf() }
        val set = WorkoutSet(
            exerciseId = exerciseId,
            reps = reps,
            restDuration = restDuration,
            order = exerciseSets.size
        )
        exerciseSets.add(set)
        sets[exerciseId] = exerciseSets
        currentSets.value = sets
    }

    fun removeSet(exerciseId: Int, set: WorkoutSet) {
        val sets = currentSets.value ?: return
        val exerciseSets = sets[exerciseId]?.toMutableList() ?: return
        exerciseSets.remove(set)
        sets[exerciseId] = exerciseSets
        currentSets.value = sets
    }

    fun saveWorkout() {
        viewModelScope.launch {
            val workout = currentWorkout.value ?: return@launch
            val exercises = currentExercises.value ?: return@launch
            val allSets = currentSets.value ?: return@launch

            // Insert workout and get its ID
            val workoutId = workoutDao.insertWorkout(workout).toInt()

            // Insert exercises
            for (exercise in exercises) {
                val updatedExercise = exercise.copy(workoutId = workoutId)
                val exerciseId = exerciseDao.insertExercise(updatedExercise).toInt()

                // Insert sets for this exercise
                allSets[exercise.id]?.forEach { set ->
                    val updatedSet = set.copy(exerciseId = exerciseId)
                    workoutSetDao.insertSet(updatedSet)
                }
            }

            // Reset form
            currentWorkout.value = null
            currentExercises.value = mutableListOf()
            currentSets.value = mutableMapOf()
        }
    }
}

