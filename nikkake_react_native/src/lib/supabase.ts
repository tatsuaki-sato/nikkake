import 'react-native-url-polyfill/auto';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { createClient } from '@supabase/supabase-js';
import { Platform } from 'react-native';

const supabaseUrl = 'https://igptzltkydyghneioedm.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlncHR6bHRreWR5Z2huZWlvZWRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM3MDMyNjEsImV4cCI6MjA5OTI3OTI2MX0.pNprCQcr4GkAY86VhF9JUHYtpGxavQxDJjpodea1dAE';

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    storage: Platform.OS === 'web' ? typeof window !== 'undefined' ? window.localStorage : undefined : AsyncStorage,
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false,
  },
});
