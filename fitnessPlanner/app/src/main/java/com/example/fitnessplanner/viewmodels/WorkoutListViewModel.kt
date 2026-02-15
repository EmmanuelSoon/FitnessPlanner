package com.example.fitnessplanner.viewmodels

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.LiveData
import androidx.lifecycle.viewModelScope
import com.example.fitnessplanner.data.WorkoutDatabase
import com.example.fitnessplanner.data.models.Workout
import kotlinx.coroutines.launch

class WorkoutListViewModel(application: Application) : AndroidViewModel(application) {
    private val database = WorkoutDatabase.getInstance(application)
    private val workoutDao = database.workoutDao()

    val allWorkouts: LiveData<List<Workout>> = workoutDao.getAllWorkouts()

    fun deleteWorkout(workout: Workout) {
        viewModelScope.launch {
            workoutDao.deleteWorkout(workout)
        }
    }

    fun addWorkout(workout: Workout) {
        viewModelScope.launch {
            workoutDao.insertWorkout(workout)
        }
    }
}

