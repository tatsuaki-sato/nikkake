/// GraphQL のクエリ文字列。
///
/// 正は packages/contract/schema.graphql で、
/// `rake graphql:verify` が契約と実装の差を検査している。
/// フィールドを足すときは先に契約を直すこと。
library;

const _routineFields = '''
  id name description color icon
  frequencyType frequencyValue frequencyDays
  isActive sortOrder lockVersion
  routineExercises {
    id sortOrder targetSets targetReps targetWeight targetDurationSec restSec
    exercise { id name category icon isPreset }
  }
''';

const _todayRoutine = '''
  isDueToday isCompleted frequencyLabel
  routine { $_routineFields }
''';

const createAnonymousAccount = '''
  mutation CreateAnonymousAccount(\$timeZone: String!, \$withStarterRoutine: Boolean) {
    createAnonymousAccount(timeZone: \$timeZone, withStarterRoutine: \$withStarterRoutine) {
      token
      userErrors { message code }
    }
  }
''';

const importSnapshot = '''
  mutation ImportSnapshot(\$exercises: [JSON!], \$routines: [JSON!], \$routineExercises: [JSON!],
                          \$routineLogs: [JSON!], \$exerciseLogs: [JSON!]) {
    importSnapshot(exercises: \$exercises, routines: \$routines, routineExercises: \$routineExercises,
                   routineLogs: \$routineLogs, exerciseLogs: \$exerciseLogs) {
      imported { routines exercises routineLogs exerciseLogs }
      userErrors { message code }
    }
  }
''';

const home = '''
  query Home(\$today: Date!, \$timeZone: String!) {
    home(today: \$today, timeZone: \$timeZone) {
      today
      streak { current longest lastCompletedDate }
      due { $_todayRoutine }
      notScheduled { $_todayRoutine }
      completed { $_todayRoutine }
    }
  }
''';

const routines = '''
  query Routines { routines { $_routineFields } }
''';

const exercises = '''
  query Exercises { exercises { id name category icon isPreset } }
''';

const workoutSession = '''
  query WorkoutSession(\$routineId: ID!) {
    workoutSession(routineId: \$routineId) {
      routine { $_routineFields }
      exercises {
        routineExerciseId targetSets targetReps targetWeight targetDurationSec restSec
        previousLabel
        previousSets { setNumber reps weight durationSec }
        exercise { id name category icon isPreset }
      }
    }
  }
''';

const progress = '''
  query Progress(\$today: Date!, \$timeZone: String!, \$rangeDays: Int!) {
    progress(today: \$today, timeZone: \$timeZone, rangeDays: \$rangeDays) {
      overall { totalWorkouts thisWeekCount totalDurationSec totalSets }
      streak { current longest lastCompletedDate }
      dailyStats { date completedCount totalCount }
      completedDates
      exercisesWithLogs { id name category icon isPreset }
    }
  }
''';

const exerciseProgress = '''
  query ExerciseProgress(\$exerciseId: ID!, \$limit: Int!) {
    exerciseProgress(exerciseId: \$exerciseId, limit: \$limit) {
      date maxWeight totalReps totalVolume
    }
  }
''';

const viewer = '''
  query Viewer {
    viewer { id email isAnonymous storageMode
      counts { routines exercises routineLogs exerciseLogs } }
  }
''';

const createRoutine = '''
  mutation CreateRoutine(\$id: ID!, \$name: String!, \$description: String, \$icon: String!,
                         \$color: String!, \$frequencyType: FrequencyType!, \$frequencyValue: Int,
                         \$frequencyDays: [Int!], \$exercises: [RoutineExerciseInput!]!) {
    createRoutine(id: \$id, name: \$name, description: \$description, icon: \$icon, color: \$color,
                  frequencyType: \$frequencyType, frequencyValue: \$frequencyValue,
                  frequencyDays: \$frequencyDays, exercises: \$exercises) {
      routine { $_routineFields }
      userErrors { message code path }
    }
  }
''';

const updateRoutine = '''
  mutation UpdateRoutine(\$id: ID!, \$name: String!, \$description: String, \$icon: String!,
                         \$color: String!, \$frequencyType: FrequencyType!, \$frequencyValue: Int,
                         \$frequencyDays: [Int!], \$isActive: Boolean, \$lockVersion: Int!,
                         \$exercises: [RoutineExerciseInput!]!) {
    updateRoutine(id: \$id, name: \$name, description: \$description, icon: \$icon, color: \$color,
                  frequencyType: \$frequencyType, frequencyValue: \$frequencyValue,
                  frequencyDays: \$frequencyDays, isActive: \$isActive, lockVersion: \$lockVersion,
                  exercises: \$exercises) {
      routine { $_routineFields }
      userErrors { message code path }
    }
  }
''';

const deleteRoutine = '''
  mutation DeleteRoutine(\$id: ID!) {
    deleteRoutine(id: \$id) { routine { id } userErrors { message code } }
  }
''';

const setRoutineActive = '''
  mutation SetRoutineActive(\$id: ID!, \$isActive: Boolean!) {
    setRoutineActive(id: \$id, isActive: \$isActive) {
      routine { $_routineFields }
      userErrors { message code }
    }
  }
''';

const createCustomExercise = '''
  mutation CreateCustomExercise(\$id: ID!, \$name: String!, \$category: ExerciseCategory!, \$icon: String) {
    createCustomExercise(id: \$id, name: \$name, category: \$category, icon: \$icon) {
      exercise { id name category icon isPreset }
      userErrors { message code }
    }
  }
''';

const recordWorkout = '''
  mutation RecordWorkout(\$id: ID!, \$routineId: ID!, \$logDate: Date!, \$timeZone: String!,
                         \$startedAt: DateTime!, \$durationSec: Int, \$totalSets: Int!,
                         \$sets: [RecordedSetInput!]!, \$clientMutationId: String) {
    recordWorkout(id: \$id, routineId: \$routineId, logDate: \$logDate, timeZone: \$timeZone,
                  startedAt: \$startedAt, durationSec: \$durationSec, totalSets: \$totalSets,
                  sets: \$sets, clientMutationId: \$clientMutationId) {
      summary { routineLogId routineName durationSec completedSets totalSets totalVolume status }
      streak { current longest lastCompletedDate }
      userErrors { message code }
    }
  }
''';

const resetData = '''
  mutation ResetData { resetData { success userErrors { message code } } }
''';
