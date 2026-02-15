package com.example.fitnessplanner.data.dao

import androidx.lifecycle.LiveData
import androidx.room.*
import com.example.fitnessplanner.data.models.WorkoutLog

@Dao
interface WorkoutLogDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertLog(log: WorkoutLog): Long

    @Update
    suspend fun updateLog(log: WorkoutLog)

    @Delete
    suspend fun deleteLog(log: WorkoutLog)

    @Query("SELECT * FROM workout_logs WHERE id = :id")
    suspend fun getLogById(id: Int): WorkoutLog?

    @Query("SELECT * FROM workout_logs WHERE workoutId = :workoutId ORDER BY date DESC")
    fun getLogsForWorkout(workoutId: Int): LiveData<List<WorkoutLog>>

    @Query("SELECT * FROM workout_logs WHERE date >= :startDate AND date <= :endDate ORDER BY date DESC")
    fun getLogsByDateRange(startDate: Long, endDate: Long): LiveData<List<WorkoutLog>>

    @Query("SELECT DISTINCT DATE(date/1000, 'unixepoch') as workoutDate FROM workout_logs WHERE completed = 1 ORDER BY workoutDate DESC")
    fun getAllWorkoutDates(): LiveData<List<String>>

    @Query("SELECT * FROM workout_logs WHERE completed = 1 ORDER BY date DESC LIMIT 1")
    suspend fun getLastCompletedWorkout(): WorkoutLog?
}

