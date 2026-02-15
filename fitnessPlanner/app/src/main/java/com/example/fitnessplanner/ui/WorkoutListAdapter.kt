package com.example.fitnessplanner.ui

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.TextView
import com.example.fitnessplanner.R
import com.example.fitnessplanner.data.models.Workout

class WorkoutListAdapter(
    context: Context,
    workouts: MutableList<Workout>,
    val onWorkoutClick: (Workout) -> Unit,
    val onDeleteClick: (Workout) -> Unit
) : ArrayAdapter<Workout>(context, 0, workouts) {

    override fun getView(position: Int, convertView: View?, parent: ViewGroup): View {
        var view = convertView
        if (view == null) {
            view = LayoutInflater.from(context).inflate(R.layout.item_workout, parent, false)
        }

        val workout = getItem(position)
        if (workout != null) {
            val nameTextView = view?.findViewById<TextView>(R.id.workout_name)
            val descriptionTextView = view?.findViewById<TextView>(R.id.workout_description)
            val startButton = view?.findViewById<Button>(R.id.btn_start_workout)
            val deleteButton = view?.findViewById<Button>(R.id.btn_delete_workout)

            nameTextView?.text = workout.name
            descriptionTextView?.text = workout.description

            startButton?.setOnClickListener {
                onWorkoutClick(workout)
            }

            deleteButton?.setOnClickListener {
                onDeleteClick(workout)
            }
        }

        return view!!
    }
}

