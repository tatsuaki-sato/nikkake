package com.myapplication.common.store

import com.myapplication.common.domain.Routine
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

class RoutineStore {
    private val _routines = MutableStateFlow<List<Routine>>(emptyList())
    val routines: StateFlow<List<Routine>> = _routines.asStateFlow()

    fun setRoutines(newRoutines: List<Routine>) {
        _routines.value = newRoutines
    }

    fun addRoutine(routine: Routine) {
        _routines.update { it + routine }
    }
}

object AppStores {
    val routineStore = RoutineStore()
}
