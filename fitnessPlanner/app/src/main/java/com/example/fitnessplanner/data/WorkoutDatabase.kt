package com.example.fitnessplanner.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import com.example.fitnessplanner.data.dao.ExerciseDao
import com.example.fitnessplanner.data.dao.WorkoutDao
import com.example.fitnessplanner.data.dao.WorkoutLogDao
import com.example.fitnessplanner.data.dao.WorkoutSetDao
import com.example.fitnessplanner.data.models.Exercise
import com.example.fitnessplanner.data.models.Workout
import com.example.fitnessplanner.data.models.WorkoutLog
import com.example.fitnessplanner.data.models.WorkoutSet

@Database(
    entities = [Workout::class, Exercise::class, WorkoutSet::class, WorkoutLog::class],
    version = 1,
    exportSchema = false
)
abstract class WorkoutDatabase : RoomDatabase() {
    abstract fun workoutDao(): WorkoutDao
    abstract fun exerciseDao(): ExerciseDao
    abstract fun workoutSetDao(): WorkoutSetDao
    abstract fun workoutLogDao(): WorkoutLogDao

    companion object {
        @Volatile
        private var INSTANCE: WorkoutDatabase? = null

        fun getInstance(context: Context): WorkoutDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    WorkoutDatabase::class.java,
                    "workout_database"
                ).build()
                INSTANCE = instance
                instance
            }
        }
    }
}

