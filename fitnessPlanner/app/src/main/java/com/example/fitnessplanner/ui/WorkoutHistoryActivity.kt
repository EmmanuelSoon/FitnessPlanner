package com.example.fitnessplanner.ui

import android.os.Bundle
import android.widget.TableLayout
import android.widget.TableRow
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.ViewModelProvider
import com.example.fitnessplanner.R
import com.example.fitnessplanner.viewmodels.WorkoutHistoryViewModel
import java.util.Calendar

class WorkoutHistoryActivity : AppCompatActivity() {
    private lateinit var viewModel: WorkoutHistoryViewModel
    private lateinit var calendarTable: TableLayout
    private lateinit var monthYearTextView: TextView
    private var currentYear = Calendar.getInstance().get(Calendar.YEAR)
    private var currentMonth = Calendar.getInstance().get(Calendar.MONTH)
    private var workoutDates = mutableSetOf<String>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_workout_history)

        viewModel = ViewModelProvider(this).get(WorkoutHistoryViewModel::class.java)

        calendarTable = findViewById(R.id.calendar_table)
        monthYearTextView = findViewById(R.id.tv_month_year)

        viewModel.workoutDates.observe(this) { dates ->
            workoutDates.clear()
            workoutDates.addAll(dates)
            renderCalendar()
        }

        renderCalendar()
    }

    private fun renderCalendar() {
        calendarTable.removeAllViews()

        // Month and year header
        monthYearTextView.text = String.format(
            "%s %d",
            getMonthName(currentMonth),
            currentYear
        )

        // Day of week header
        val dayOfWeekRow = TableRow(this)
        val daysOfWeek = listOf("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")
        for (day in daysOfWeek) {
            val dayTextView = TextView(this)
            dayTextView.text = day
            dayTextView.setPadding(8, 8, 8, 8)
            dayTextView.setBackgroundColor(getColor(android.R.color.darker_gray))
            dayTextView.setTextColor(getColor(android.R.color.white))
            dayOfWeekRow.addView(dayTextView)
        }
        calendarTable.addView(dayOfWeekRow)

        // Calendar days
        val monthDays = viewModel.getMonthDates(currentYear, currentMonth)
        val firstDayOfWeek = viewModel.getFirstDayOfMonth(currentYear, currentMonth)

        var dateRow = TableRow(this)
        var dayCount = 0

        // Add empty cells for days before the first day of month
        for (i in 0 until firstDayOfWeek) {
            val emptyView = TextView(this)
            emptyView.setPadding(8, 8, 8, 8)
            dateRow.addView(emptyView)
            dayCount++
        }

        // Add date cells
        for (day in monthDays) {
            if (dayCount == 7) {
                calendarTable.addView(dateRow)
                dateRow = TableRow(this)
                dayCount = 0
            }

            val dateTextView = TextView(this)
            val dateString = String.format("%04d-%02d-%02d", currentYear, currentMonth + 1, day)

            dateTextView.text = day.toString()
            dateTextView.setPadding(8, 8, 8, 8)

            if (workoutDates.contains(dateString)) {
                dateTextView.setBackgroundColor(getColor(android.R.color.holo_green_light))
            } else {
                dateTextView.setBackgroundColor(getColor(android.R.color.white))
            }

            dateTextView.setTextColor(getColor(android.R.color.black))
            dateRow.addView(dateTextView)
            dayCount++
        }

        // Add remaining empty cells
        while (dayCount < 7) {
            val emptyView = TextView(this)
            emptyView.setPadding(8, 8, 8, 8)
            dateRow.addView(emptyView)
            dayCount++
        }

        calendarTable.addView(dateRow)
    }

    private fun getMonthName(month: Int): String {
        return arrayOf(
            "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December"
        )[month]
    }
}


