package com.example.fitnessplanner.data.dao

import androidx.lifecycle.LiveData
import androidx.room.*
import com.example.fitnessplanner.data.models.Workout

@Dao
interface WorkoutDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertWorkout(workout: Workout): Long

    @Update
    suspend fun updateWorkout(workout: Workout)

    @Delete
    suspend fun deleteWorkout(workout: Workout)

    @Query("SELECT * FROM workouts WHERE id = :id")
    suspend fun getWorkoutById(id: Int): Workout?

    @Query("SELECT * FROM workouts WHERE isActive = 1 ORDER BY createdAt DESC")
    fun getAllWorkouts(): LiveData<List<Workout>>

    @Query("SELECT * FROM workouts ORDER BY createdAt DESC")
    fun getAllWorkoutsIncludeInactive(): LiveData<List<Workout>>
}

