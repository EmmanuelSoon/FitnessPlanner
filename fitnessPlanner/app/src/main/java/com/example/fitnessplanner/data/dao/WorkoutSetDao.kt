package com.example.fitnessplanner.data.dao

import androidx.lifecycle.LiveData
import androidx.room.*
import com.example.fitnessplanner.data.models.WorkoutSet

@Dao
interface WorkoutSetDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertSet(set: WorkoutSet): Long

    @Update
    suspend fun updateSet(set: WorkoutSet)

    @Delete
    suspend fun deleteSet(set: WorkoutSet)

    @Query("SELECT * FROM workout_sets WHERE id = :id")
    suspend fun getSetById(id: Int): WorkoutSet?

    @Query("SELECT * FROM workout_sets WHERE exerciseId = :exerciseId ORDER BY `order` ASC")
    fun getSetsForExercise(exerciseId: Int): LiveData<List<WorkoutSet>>

    @Query("SELECT * FROM workout_sets WHERE exerciseId = :exerciseId ORDER BY `order` ASC")
    suspend fun getSetsForExerciseSync(exerciseId: Int): List<WorkoutSet>

    @Query("DELETE FROM workout_sets WHERE exerciseId = :exerciseId")
    suspend fun deleteSetsForExercise(exerciseId: Int)
}

