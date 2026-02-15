package com.example.fitnessplanner.data.models

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.PrimaryKey

@Entity(
    tableName = "exercises",
    foreignKeys = [
        ForeignKey(
            entity = Workout::class,
            parentColumns = ["id"],
            childColumns = ["workoutId"],
            onDelete = ForeignKey.CASCADE
        )
    ]
)
data class Exercise(
    @PrimaryKey(autoGenerate = true)
    val id: Int = 0,
    val workoutId: Int,
    val name: String,
    val order: Int = 0
)

