package com.example.fitnessplanner.data.dao

import androidx.lifecycle.LiveData
import androidx.room.*
import com.example.fitnessplanner.data.models.Exercise

@Dao
interface ExerciseDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertExercise(exercise: Exercise): Long

    @Update
    suspend fun updateExercise(exercise: Exercise)

    @Delete
    suspend fun deleteExercise(exercise: Exercise)

    @Query("SELECT * FROM exercises WHERE id = :id")
    suspend fun getExerciseById(id: Int): Exercise?

    @Query("SELECT * FROM exercises WHERE workoutId = :workoutId ORDER BY `order` ASC")
    fun getExercisesForWorkout(workoutId: Int): LiveData<List<Exercise>>

    @Query("SELECT * FROM exercises WHERE workoutId = :workoutId ORDER BY `order` ASC")
    suspend fun getExercisesForWorkoutSync(workoutId: Int): List<Exercise>

    @Query("DELETE FROM exercises WHERE workoutId = :workoutId")
    suspend fun deleteExercisesForWorkout(workoutId: Int)
}

