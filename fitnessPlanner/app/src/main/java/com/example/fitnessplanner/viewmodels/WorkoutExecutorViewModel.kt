package com.example.fitnessplanner.viewmodels

import android.app.Application
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.CountDownTimer
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.viewModelScope
import com.example.fitnessplanner.data.WorkoutDatabase
import com.example.fitnessplanner.data.models.Exercise
import com.example.fitnessplanner.data.models.Workout
import com.example.fitnessplanner.data.models.WorkoutLog
import com.example.fitnessplanner.data.models.WorkoutSet
import com.example.fitnessplanner.utils.AudioVibratorHelper
import kotlinx.coroutines.launch

class WorkoutExecutorViewModel(application: Application) : AndroidViewModel(application) {
    private val database = WorkoutDatabase.getInstance(application)
    private val workoutDao = database.workoutDao()
    private val exerciseDao = database.exerciseDao()
    private val workoutSetDao = database.workoutSetDao()
    private val workoutLogDao = database.workoutLogDao()
    private val appContext = application.applicationContext

    val currentWorkout = MutableLiveData<Workout>()
    val exercises = MutableLiveData<List<Exercise>>()
    val currentExerciseIndex = MutableLiveData(0)
    val currentExercise = MutableLiveData<Exercise>()
    val currentSetIndex = MutableLiveData(0)
    val currentSet = MutableLiveData<WorkoutSet>()
    val allSetsForExercise = MutableLiveData<List<WorkoutSet>>()

    val timerRunning = MutableLiveData(false)
    val timerText = MutableLiveData("00:00")
    val workoutStartTime = MutableLiveData(0L)

    private var countDownTimer: CountDownTimer? = null
    private var exerciseSetsCache = mutableMapOf<Int, List<WorkoutSet>>()

    fun loadWorkout(workoutId: Int) {
        viewModelScope.launch {
            val workout = workoutDao.getWorkoutById(workoutId)
            if (workout != null) {
                currentWorkout.value = workout
                val exs = exerciseDao.getExercisesForWorkoutSync(workoutId).sortedBy { it.order }
                exercises.value = exs
                workoutStartTime.value = System.currentTimeMillis()

                // Cache all sets for all exercises
                for (exercise in exs) {
                    val sets = workoutSetDao.getSetsForExerciseSync(exercise.id).sortedBy { it.order }
                    exerciseSetsCache[exercise.id] = sets
                }

                // Load first exercise
                if (exs.isNotEmpty()) {
                    loadExercise(0)
                }
            }
        }
    }

    private suspend fun loadExercise(index: Int) {
        val exs = exercises.value ?: return
        if (index >= exs.size) return

        currentExerciseIndex.value = index
        currentExercise.value = exs[index]
        currentSetIndex.value = 0

        val sets = exerciseSetsCache[exs[index].id] ?: emptyList()
        allSetsForExercise.value = sets
        if (sets.isNotEmpty()) {
            currentSet.value = sets[0]
        }
    }

    fun nextSet() {
        val exs = exercises.value ?: return
        val sets = allSetsForExercise.value ?: return
        val currentSetIdx = currentSetIndex.value ?: 0
        val currentExIdx = currentExerciseIndex.value ?: 0

        // Move to next set
        if (currentSetIdx + 1 < sets.size) {
            currentSetIndex.value = currentSetIdx + 1
            currentSet.value = sets[currentSetIdx + 1]
            startRestTimer()
        } else if (currentExIdx + 1 < exs.size) {
            // Move to next exercise
            viewModelScope.launch {
                loadExercise(currentExIdx + 1)
                startRestTimer()
            }
        } else {
            // Workout complete
            finishWorkout()
        }
    }

    fun startRestTimer() {
        val set = currentSet.value ?: return
        val restDuration = set.restDuration * 1000L

        countDownTimer?.cancel()
        timerRunning.value = true

        countDownTimer = object : CountDownTimer(restDuration, 100) {
            override fun onTick(millisUntilFinished: Long) {
                val secondsRemaining = millisUntilFinished / 1000
                val minutes = secondsRemaining / 60
                val seconds = secondsRemaining % 60
                timerText.value = String.format("%02d:%02d", minutes, seconds)
            }

            override fun onFinish() {
                timerText.value = "00:00"
                timerRunning.value = false
                playBeep()
            }
        }.start()
    }

    fun cancelTimer() {
        countDownTimer?.cancel()
        timerRunning.value = false
    }

    private fun playBeep() {
        AudioVibratorHelper.playBeepAndVibrate(appContext)
    }

    fun finishWorkout() {
        cancelTimer()
        viewModelScope.launch {
            val workoutId = currentWorkout.value?.id ?: return@launch
            val duration = System.currentTimeMillis() - (workoutStartTime.value ?: 0L)
            val log = WorkoutLog(
                workoutId = workoutId,
                date = System.currentTimeMillis(),
                duration = duration,
                completed = true
            )
            workoutLogDao.insertLog(log)
        }
    }

    override fun onCleared() {
        super.onCleared()
        cancelTimer()
    }
}


