package com.example.fitnessplanner.data.models

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.PrimaryKey

@Entity(
    tableName = "workout_logs",
    foreignKeys = [
        ForeignKey(
            entity = Workout::class,
            parentColumns = ["id"],
            childColumns = ["workoutId"],
            onDelete = ForeignKey.CASCADE
        )
    ]
)
data class WorkoutLog(
    @PrimaryKey(autoGenerate = true)
    val id: Int = 0,
    val workoutId: Int,
    val date: Long = System.currentTimeMillis(),
    val duration: Long = 0, // in milliseconds
    val completed: Boolean = false
)

