/**
 * クエリ文字列。将来 packages/contract/operations/ へ切り出して
 * Web / React Native / Flutter / KMP で共有する。
 */

const ROUTINE_FIELDS = `
  id name description color icon
  frequencyType frequencyValue frequencyDays
  isActive sortOrder lockVersion
  routineExercises {
    id sortOrder targetSets targetReps targetWeight targetDurationSec restSec
    exercise { id name category icon isPreset }
  }
`;

export const HOME = `
  query Home($today: Date!, $timeZone: String!) {
    home(today: $today, timeZone: $timeZone) {
      today
      streak { current longest lastCompletedDate }
      due { isDueToday isCompleted frequencyLabel routine { ${ROUTINE_FIELDS} } }
      notScheduled { isDueToday isCompleted frequencyLabel routine { ${ROUTINE_FIELDS} } }
      completed { isDueToday isCompleted frequencyLabel routine { ${ROUTINE_FIELDS} } }
    }
  }
`;

export const ROUTINES = `
  query Routines { routines { ${ROUTINE_FIELDS} } }
`;

export const ROUTINE = `
  query Routine($id: ID!) { routine(id: $id) { ${ROUTINE_FIELDS} } }
`;

export const EXERCISES = `
  query Exercises { exercises { id name category icon isPreset } }
`;

export const WORKOUT_SESSION = `
  query WorkoutSession($routineId: ID!) {
    workoutSession(routineId: $routineId) {
      routine { ${ROUTINE_FIELDS} }
      exercises {
        routineExerciseId targetSets targetReps targetWeight targetDurationSec restSec
        previousLabel
        previousSets { setNumber reps weight durationSec }
        exercise { id name category icon isPreset }
      }
    }
  }
`;

export const PROGRESS = `
  query Progress($today: Date!, $timeZone: String!, $rangeDays: Int!) {
    progress(today: $today, timeZone: $timeZone, rangeDays: $rangeDays) {
      overall { totalWorkouts thisWeekCount totalDurationSec totalSets }
      streak { current longest lastCompletedDate }
      dailyStats { date completedCount totalCount }
      completedDates
      exercisesWithLogs { id name category icon isPreset }
    }
  }
`;

export const EXERCISE_PROGRESS = `
  query ExerciseProgress($exerciseId: ID!, $limit: Int!) {
    exerciseProgress(exerciseId: $exerciseId, limit: $limit) {
      date maxWeight totalReps totalVolume
    }
  }
`;

export const DAY = `
  query Day($date: Date!, $timeZone: String!) {
    day(date: $date, timeZone: $timeZone) {
      date
      workouts {
        routineLogId routineName status durationSec
        exercises { exerciseName setsLabel }
      }
    }
  }
`;

export const VIEWER = `
  query Viewer {
    viewer {
      id email isAnonymous emailVerified storageMode
      counts { routines exercises routineLogs exerciseLogs }
    }
  }
`;

export const CREATE_ANONYMOUS_ACCOUNT = `
  mutation CreateAnonymousAccount($timeZone: String!, $withStarterRoutine: Boolean) {
    createAnonymousAccount(timeZone: $timeZone, withStarterRoutine: $withStarterRoutine) {
      token
      viewer { id isAnonymous storageMode counts { routines exercises routineLogs exerciseLogs } }
      userErrors { message code path }
    }
  }
`;

export const ATTACH_EMAIL_PASSWORD = `
  mutation AttachEmailPassword($email: String!, $password: String!, $displayName: String) {
    attachEmailPassword(email: $email, password: $password, displayName: $displayName) {
      viewer { id email isAnonymous storageMode counts { routines exercises routineLogs exerciseLogs } }
      userErrors { message code path }
    }
  }
`;

export const LINK_EXISTING_ACCOUNT = `
  mutation LinkExistingAccount($email: String!, $password: String!, $merge: Boolean!) {
    linkExistingAccount(email: $email, password: $password, mergeAnonymousData: $merge) {
      token
      viewer { id email isAnonymous storageMode counts { routines exercises routineLogs exerciseLogs } }
      userErrors { message code path }
    }
  }
`;

export const SIGN_OUT = `
  mutation SignOut { signOut { success userErrors { message code } } }
`;

export const CREATE_ROUTINE = `
  mutation CreateRoutine($id: ID!, $name: String!, $description: String, $icon: String!,
                         $color: String!, $frequencyType: FrequencyType!, $frequencyValue: Int,
                         $frequencyDays: [Int!], $exercises: [RoutineExerciseInput!]!) {
    createRoutine(id: $id, name: $name, description: $description, icon: $icon, color: $color,
                  frequencyType: $frequencyType, frequencyValue: $frequencyValue,
                  frequencyDays: $frequencyDays, exercises: $exercises) {
      routine { ${ROUTINE_FIELDS} }
      userErrors { message code path }
    }
  }
`;

export const UPDATE_ROUTINE = `
  mutation UpdateRoutine($id: ID!, $name: String!, $description: String, $icon: String!,
                         $color: String!, $frequencyType: FrequencyType!, $frequencyValue: Int,
                         $frequencyDays: [Int!], $isActive: Boolean, $lockVersion: Int!,
                         $exercises: [RoutineExerciseInput!]!) {
    updateRoutine(id: $id, name: $name, description: $description, icon: $icon, color: $color,
                  frequencyType: $frequencyType, frequencyValue: $frequencyValue,
                  frequencyDays: $frequencyDays, isActive: $isActive, lockVersion: $lockVersion,
                  exercises: $exercises) {
      routine { ${ROUTINE_FIELDS} }
      userErrors { message code path }
    }
  }
`;

export const DELETE_ROUTINE = `
  mutation DeleteRoutine($id: ID!) {
    deleteRoutine(id: $id) { routine { id } userErrors { message code } }
  }
`;

export const SET_ROUTINE_ACTIVE = `
  mutation SetRoutineActive($id: ID!, $isActive: Boolean!) {
    setRoutineActive(id: $id, isActive: $isActive) {
      routine { ${ROUTINE_FIELDS} }
      userErrors { message code }
    }
  }
`;

export const REORDER_ROUTINES = `
  mutation ReorderRoutines($ids: [ID!]!) {
    reorderRoutines(routineIds: $ids) {
      routines { id sortOrder }
      userErrors { message code }
    }
  }
`;

export const CREATE_CUSTOM_EXERCISE = `
  mutation CreateCustomExercise($id: ID!, $name: String!, $category: ExerciseCategory!, $icon: String) {
    createCustomExercise(id: $id, name: $name, category: $category, icon: $icon) {
      exercise { id name category icon isPreset }
      userErrors { message code }
    }
  }
`;

export const RECORD_WORKOUT = `
  mutation RecordWorkout($id: ID!, $routineId: ID!, $logDate: Date!, $timeZone: String!,
                         $startedAt: DateTime!, $durationSec: Int, $totalSets: Int!,
                         $sets: [RecordedSetInput!]!, $clientMutationId: String) {
    recordWorkout(id: $id, routineId: $routineId, logDate: $logDate, timeZone: $timeZone,
                  startedAt: $startedAt, durationSec: $durationSec, totalSets: $totalSets,
                  sets: $sets, clientMutationId: $clientMutationId) {
      routineLog { id status logDate }
      summary { routineLogId routineName durationSec completedSets totalSets totalVolume status }
      streak { current longest lastCompletedDate }
      userErrors { message code }
    }
  }
`;

export const IMPORT_SNAPSHOT = `
  mutation ImportSnapshot($exercises: [JSON!], $routines: [JSON!], $routineExercises: [JSON!],
                          $routineLogs: [JSON!], $exerciseLogs: [JSON!]) {
    importSnapshot(exercises: $exercises, routines: $routines, routineExercises: $routineExercises,
                   routineLogs: $routineLogs, exerciseLogs: $exerciseLogs) {
      imported { routines exercises routineLogs exerciseLogs }
      userErrors { message code }
    }
  }
`;

export const RESET_DATA = `
  mutation ResetData { resetData { success userErrors { message code } } }
`;
