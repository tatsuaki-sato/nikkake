package com.myapplication.common.data

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.gotrue.Auth
import io.github.jan.supabase.postgrest.Postgrest

val supabaseUrl = "https://igptzltkydyghneioedm.supabase.co"
val supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlncHR6bHRreWR5Z2huZWlvZWRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM3MDMyNjEsImV4cCI6MjA5OTI3OTI2MX0.pNprCQcr4GkAY86VhF9JUHYtpGxavQxDJjpodea1dAE"

val supabaseClient: SupabaseClient = createSupabaseClient(
    supabaseUrl = supabaseUrl,
    supabaseKey = supabaseAnonKey
) {
    install(Postgrest)
    install(Auth)
}
