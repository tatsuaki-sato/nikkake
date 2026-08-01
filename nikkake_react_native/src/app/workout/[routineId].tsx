import React, { useEffect, useRef, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
  TextInput,
  ActivityIndicator,
  Alert,
  Platform,
} from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { Colors } from '../../constants/colors';
import { useWorkoutStore } from '../../stores/workoutStore';
import { getRoutineWithExercises, getLastSetsByExercise } from '../../lib/repository';
import { formatDuration } from '../../lib/utils';
import { Button, EmptyState, Spacing, Radius } from '../../components/ui';

/**
 * ワークアウト実行画面。
 * 記録はすべてローカルなので、電波が無い場所（ジムの地下など）でも完全に動く。
 */
export default function WorkoutScreen() {
  const { routineId } = useLocalSearchParams<{ routineId: string }>();
  const router = useRouter();

  const {
    activeWorkout,
    restTimer,
    isRestTimerActive,
    startWorkout,
    updateSet,
    toggleSetComplete,
    addSet,
    removeSet,
    nextExercise,
    previousExercise,
    goToExercise,
    stopRestTimer,
    tickRestTimer,
    finishWorkout,
    cancelWorkout,
  } = useWorkoutStore();

  const [loading, setLoading] = useState(true);
  const [notFound, setNotFound] = useState(false);
  const [elapsed, setElapsed] = useState(0);
  const startedRef = useRef(false);

  useEffect(() => {
    if (!routineId || startedRef.current) return;
    startedRef.current = true;

    const load = async () => {
      const [routine, lastSets] = await Promise.all([
        getRoutineWithExercises(routineId),
        getLastSetsByExercise(routineId),
      ]);

      if (!routine || routine.routine_exercises.length === 0) {
        setNotFound(true);
        setLoading(false);
        return;
      }

      startWorkout(routine, lastSets);
      setLoading(false);
    };

    void load();
  }, [routineId, startWorkout]);

  // 経過時間とレストタイマーを1本のintervalでまとめて進める
  useEffect(() => {
    const interval = setInterval(() => {
      const workout = useWorkoutStore.getState().activeWorkout;
      if (workout) {
        setElapsed(Math.floor((Date.now() - new Date(workout.startedAt).getTime()) / 1000));
      }
      tickRestTimer();
    }, 1000);

    return () => clearInterval(interval);
  }, [tickRestTimer]);

  const handleFinish = async () => {
    const summary = await finishWorkout();
    if (summary) {
      router.replace('/workout/summary');
    }
  };

  const handleCancel = () => {
    const discard = () => {
      cancelWorkout();
      router.back();
    };

    if (Platform.OS === 'web') {
      // eslint-disable-next-line no-alert
      if (typeof confirm === 'function' && !confirm('ワークアウトを中断しますか？記録は保存されません。')) return;
      discard();
      return;
    }

    Alert.alert('中断しますか？', 'ここまでの記録は保存されません。', [
      { text: '続ける', style: 'cancel' },
      { text: '中断する', style: 'destructive', onPress: discard },
    ]);
  };

  if (loading) {
    return (
      <View style={styles.loading} testID="workout-loading">
        <ActivityIndicator color={Colors.dark.primary} />
      </View>
    );
  }

  if (notFound || !activeWorkout) {
    return (
      <View style={styles.loading}>
        <EmptyState
          testID="workout-not-found"
          icon="🤔"
          title="開始できませんでした"
          message="ルーティンが見つからないか、種目が登録されていません。"
          action={<Button title="戻る" onPress={() => router.back()} />}
        />
      </View>
    );
  }

  const currentIndex = activeWorkout.currentExerciseIndex;
  const current = activeWorkout.exercises[currentIndex];
  const totalSets = activeWorkout.exercises.reduce((sum, e) => sum + e.sets.length, 0);
  const doneSets = activeWorkout.exercises.reduce(
    (sum, e) => sum + e.sets.filter(s => s.completed).length,
    0
  );
  const progress = totalSets === 0 ? 0 : doneSets / totalSets;

  return (
    <View style={styles.container} testID="workout-screen">
      <View style={styles.header}>
        <TouchableOpacity onPress={handleCancel} accessibilityRole="button" testID="workout-cancel">
          <Text style={styles.cancelText}>中断</Text>
        </TouchableOpacity>

        <View style={styles.headerCenter}>
          <Text style={styles.title} numberOfLines={1}>
            {activeWorkout.routineName}
          </Text>
          <Text style={styles.elapsed} testID="workout-elapsed">
            {formatDuration(elapsed)}
          </Text>
        </View>

        <TouchableOpacity
          style={styles.finishButton}
          onPress={handleFinish}
          accessibilityRole="button"
          testID="workout-finish"
        >
          <Text style={styles.finishButtonText}>完了</Text>
        </TouchableOpacity>
      </View>

      <View style={styles.progressTrack}>
        <View style={[styles.progressBar, { width: `${Math.round(progress * 100)}%` }]} />
      </View>

      {isRestTimerActive ? (
        <TouchableOpacity style={styles.restBanner} onPress={stopRestTimer} testID="rest-timer">
          <Text style={styles.restLabel}>休憩中</Text>
          <Text style={styles.restValue}>{formatDuration(restTimer)}</Text>
          <Text style={styles.restHint}>タップでスキップ</Text>
        </TouchableOpacity>
      ) : null}

      <ScrollView style={styles.content} contentContainerStyle={styles.contentInner}>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.tabs} contentContainerStyle={styles.tabsInner}>
          {activeWorkout.exercises.map((exercise, index) => {
            const allDone = exercise.sets.every(s => s.completed);
            return (
              <TouchableOpacity
                key={exercise.routineExerciseId}
                onPress={() => goToExercise(index)}
                style={[styles.tab, index === currentIndex && styles.tabActive]}
                accessibilityRole="button"
                testID={`workout-tab-${index}`}
              >
                <Text style={[styles.tabText, index === currentIndex && styles.tabTextActive]}>
                  {allDone ? '✓ ' : ''}
                  {exercise.exercise.name}
                </Text>
              </TouchableOpacity>
            );
          })}
        </ScrollView>

        <Text style={styles.exerciseTitle} testID="workout-exercise-name">
          {currentIndex + 1}/{activeWorkout.exercises.length} {current.exercise.name}
        </Text>

        {current.previousSets.length > 0 ? (
          <Text style={styles.previousHint} testID="workout-previous-hint">
            前回:{' '}
            {current.previousSets
              .map(s => (s.durationSec ? `${s.durationSec}秒` : `${s.weight ?? '自重'}×${s.reps ?? '-'}`))
              .join(' / ')}
          </Text>
        ) : null}

        <View style={styles.setsContainer}>
          <View style={styles.rowHeader}>
            <Text style={[styles.columnText, styles.colSet]}>セット</Text>
            <Text style={[styles.columnText, styles.colField]}>kg</Text>
            <Text style={[styles.columnText, styles.colField]}>{current.targetDurationSec ? '秒' : '回'}</Text>
            <Text style={[styles.columnText, styles.colCheck]}>完了</Text>
          </View>

          {current.sets.map(setInfo => (
            <View
              key={setInfo.setNumber}
              style={[styles.setRow, setInfo.completed && styles.setRowCompleted]}
              testID={`set-row-${currentIndex}-${setInfo.setNumber}`}
            >
              <Text style={[styles.setNumber, styles.colSet]}>{setInfo.setNumber}</Text>

              <TextInput
                style={[styles.setInput, styles.colField]}
                value={setInfo.weight === null ? '' : String(setInfo.weight)}
                onChangeText={text =>
                  updateSet(currentIndex, setInfo.setNumber, {
                    weight: text.trim() === '' ? null : Number(text) || 0,
                  })
                }
                keyboardType="numeric"
                placeholder="自重"
                placeholderTextColor={Colors.dark.textSecondary}
                testID={`set-weight-${currentIndex}-${setInfo.setNumber}`}
              />

              {current.targetDurationSec ? (
                <TextInput
                  style={[styles.setInput, styles.colField]}
                  value={setInfo.durationSec === null ? '' : String(setInfo.durationSec)}
                  onChangeText={text =>
                    updateSet(currentIndex, setInfo.setNumber, {
                      durationSec: text.trim() === '' ? null : Number(text) || 0,
                    })
                  }
                  keyboardType="numeric"
                  placeholder="—"
                  placeholderTextColor={Colors.dark.textSecondary}
                  testID={`set-duration-${currentIndex}-${setInfo.setNumber}`}
                />
              ) : (
                <TextInput
                  style={[styles.setInput, styles.colField]}
                  value={setInfo.reps === null ? '' : String(setInfo.reps)}
                  onChangeText={text =>
                    updateSet(currentIndex, setInfo.setNumber, {
                      reps: text.trim() === '' ? null : Number(text) || 0,
                    })
                  }
                  keyboardType="numeric"
                  placeholder="—"
                  placeholderTextColor={Colors.dark.textSecondary}
                  testID={`set-reps-${currentIndex}-${setInfo.setNumber}`}
                />
              )}

              <View style={styles.colCheck}>
                <TouchableOpacity
                  style={[styles.checkButton, setInfo.completed && styles.checkButtonActive]}
                  onPress={() => toggleSetComplete(currentIndex, setInfo.setNumber)}
                  accessibilityRole="checkbox"
                  accessibilityState={{ checked: setInfo.completed }}
                  testID={`set-check-${currentIndex}-${setInfo.setNumber}`}
                >
                  <Text style={styles.checkIcon}>{setInfo.completed ? '✓' : ''}</Text>
                </TouchableOpacity>
              </View>
            </View>
          ))}

          <View style={styles.setActions}>
            <TouchableOpacity onPress={() => removeSet(currentIndex)} testID="remove-set" accessibilityRole="button">
              <Text style={styles.setActionText}>− セットを減らす</Text>
            </TouchableOpacity>
            <TouchableOpacity onPress={() => addSet(currentIndex)} testID="add-set" accessibilityRole="button">
              <Text style={styles.setActionText}>＋ セットを追加</Text>
            </TouchableOpacity>
          </View>
        </View>

        <View style={styles.navButtons}>
          <Button
            title="前の種目"
            variant="secondary"
            onPress={previousExercise}
            disabled={currentIndex === 0}
            testID="workout-prev"
            style={styles.navButton}
          />
          <Button
            title="次の種目"
            variant="secondary"
            onPress={nextExercise}
            disabled={currentIndex === activeWorkout.exercises.length - 1}
            testID="workout-next"
            style={styles.navButton}
          />
        </View>
      </ScrollView>
    </View>
  );
}

const C = Colors.dark;

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: C.background, paddingTop: 56 },
  loading: { flex: 1, backgroundColor: C.background, justifyContent: 'center', alignItems: 'center' },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: Spacing.md,
    marginBottom: Spacing.md,
  },
  headerCenter: { flex: 1, alignItems: 'center' },
  cancelText: { color: C.textSecondary, fontSize: 14 },
  title: { fontSize: 16, fontWeight: 'bold', color: C.textPrimary },
  elapsed: { fontSize: 12, color: C.textSecondary, marginTop: 2 },
  finishButton: {
    backgroundColor: C.primary,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    borderRadius: Radius.sm,
  },
  finishButtonText: { color: '#fff', fontWeight: 'bold' },
  progressTrack: { height: 4, backgroundColor: C.surface, marginHorizontal: Spacing.md, borderRadius: 2 },
  progressBar: { height: 4, backgroundColor: C.success, borderRadius: 2 },
  restBanner: {
    margin: Spacing.md,
    padding: Spacing.md,
    backgroundColor: C.surfaceElevated,
    borderRadius: Radius.md,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: C.accent,
  },
  restLabel: { color: C.textSecondary, fontSize: 12 },
  restValue: { color: C.accent, fontSize: 28, fontWeight: 'bold' },
  restHint: { color: C.textSecondary, fontSize: 11 },
  content: { flex: 1 },
  contentInner: { padding: Spacing.md, paddingBottom: Spacing.xl },
  tabs: { marginBottom: Spacing.md },
  tabsInner: { gap: Spacing.sm },
  tab: {
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    borderRadius: Radius.pill,
    backgroundColor: C.surface,
    borderWidth: 1,
    borderColor: C.border,
  },
  tabActive: { backgroundColor: C.primary, borderColor: C.primary },
  tabText: { color: C.textSecondary, fontSize: 12 },
  tabTextActive: { color: '#fff', fontWeight: 'bold' },
  exerciseTitle: { fontSize: 22, fontWeight: 'bold', color: C.textPrimary, marginBottom: Spacing.xs },
  previousHint: { color: C.textSecondary, fontSize: 12, marginBottom: Spacing.md },
  setsContainer: {
    backgroundColor: C.surface,
    borderRadius: Radius.md,
    padding: Spacing.md,
    borderWidth: 1,
    borderColor: C.border,
  },
  rowHeader: { flexDirection: 'row', marginBottom: Spacing.sm },
  columnText: { color: C.textSecondary, textAlign: 'center', fontSize: 12, fontWeight: 'bold' },
  colSet: { width: 56 },
  colField: { flex: 1 },
  colCheck: { width: 64, alignItems: 'center' },
  setRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: Spacing.sm,
    borderTopWidth: 1,
    borderTopColor: C.border,
    gap: Spacing.sm,
  },
  setRowCompleted: { backgroundColor: C.surfaceElevated },
  setNumber: { textAlign: 'center', color: C.textSecondary },
  setInput: {
    backgroundColor: C.background,
    borderRadius: Radius.sm,
    paddingVertical: Spacing.sm,
    textAlign: 'center',
    color: C.textPrimary,
    borderWidth: 1,
    borderColor: C.border,
    fontSize: 16,
  },
  checkButton: {
    width: 40,
    height: 36,
    borderRadius: Radius.sm,
    backgroundColor: C.background,
    borderWidth: 1,
    borderColor: C.border,
    alignItems: 'center',
    justifyContent: 'center',
  },
  checkButtonActive: { backgroundColor: C.success, borderColor: C.success },
  checkIcon: { color: '#0F0F14', fontWeight: 'bold', fontSize: 16 },
  setActions: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: Spacing.md,
    paddingTop: Spacing.sm,
    borderTopWidth: 1,
    borderTopColor: C.border,
  },
  setActionText: { color: C.primaryLight, fontSize: 13 },
  navButtons: { flexDirection: 'row', gap: Spacing.sm, marginTop: Spacing.lg },
  navButton: { flex: 1 },
});
