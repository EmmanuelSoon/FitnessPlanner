package com.example.fitnessplanner.viewmodels

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.LiveData
import androidx.lifecycle.viewModelScope
import com.example.fitnessplanner.data.WorkoutDatabase
import com.example.fitnessplanner.data.models.WorkoutLog
import kotlinx.coroutines.launch
import java.util.Calendar

class WorkoutHistoryViewModel(application: Application) : AndroidViewModel(application) {
    private val database = WorkoutDatabase.getInstance(application)
    private val workoutLogDao = database.workoutLogDao()

    val workoutDates: LiveData<List<String>> = workoutLogDao.getAllWorkoutDates()

    fun getLogsForDateRange(startDate: Long, endDate: Long): LiveData<List<WorkoutLog>> {
        return workoutLogDao.getLogsByDateRange(startDate, endDate)
    }

    fun getLogsForWorkout(workoutId: Int): LiveData<List<WorkoutLog>> {
        return workoutLogDao.getLogsForWorkout(workoutId)
    }

    fun deleteLog(log: WorkoutLog) {
        viewModelScope.launch {
            workoutLogDao.deleteLog(log)
        }
    }

    fun getMonthDates(year: Int, month: Int): List<Int> {
        val calendar = Calendar.getInstance()
        calendar.set(year, month, 1)
        val daysInMonth = calendar.getActualMaximum(Calendar.DAY_OF_MONTH)
        return (1..daysInMonth).toList()
    }

    fun getFirstDayOfMonth(year: Int, month: Int): Int {
        val calendar = Calendar.getInstance()
        calendar.set(year, month, 1)
        return calendar.get(Calendar.DAY_OF_WEEK) - 1
    }
}

