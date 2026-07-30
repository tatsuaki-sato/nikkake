package com.myapplication.common.domain

data class Routine(
    val id: String,
    val name: String,
    val icon: String,
    val color: String,
    val frequencyType: String,
    val frequencyValue: Int,
    val isActive: Boolean
)
