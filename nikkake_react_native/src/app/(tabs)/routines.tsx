import React from 'react';
import { View, Text, StyleSheet, FlatList, TouchableOpacity, RefreshControl, Alert, Platform } from 'react-native';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useRouter, useFocusEffect } from 'expo-router';
import { Colors } from '../../constants/colors';
import { listRoutinesWithExercises, deleteRoutine, setRoutineActive } from '../../lib/repository';
import { formatFrequency } from '../../lib/utils';
import { Button, EmptyState, Spacing, Radius } from '../../components/ui';
import { RoutineWithExercises } from '../../../types';

export default function RoutinesScreen() {
  const router = useRouter();
  const queryClient = useQueryClient();

  const { data: routines = [], refetch, isFetching } = useQuery({
    queryKey: ['routinesWithExercises'],
    queryFn: listRoutinesWithExercises,
  });

  useFocusEffect(
    React.useCallback(() => {
      void refetch();
    }, [refetch])
  );

  const invalidate = () =>
    queryClient.invalidateQueries({ predicate: q => typeof q.queryKey[0] === 'string' });

  const handleDelete = (routine: RoutineWithExercises) => {
    const remove = async () => {
      await deleteRoutine(routine.id);
      await invalidate();
    };

    // Alert.alertはWebでは何も出ないので、E2Eが動くWeb向けにconfirmへ落とす
    if (Platform.OS === 'web') {
      // eslint-disable-next-line no-alert
      if (typeof confirm === 'function' && !confirm(`「${routine.name}」を削除しますか？記録は残ります。`)) return;
      void remove();
      return;
    }

    Alert.alert('ルーティンを削除', `「${routine.name}」を削除しますか？これまでの記録は残ります。`, [
      { text: 'キャンセル', style: 'cancel' },
      { text: '削除', style: 'destructive', onPress: () => void remove() },
    ]);
  };

  const handleToggleActive = async (routine: RoutineWithExercises) => {
    await setRoutineActive(routine.id, !routine.is_active);
    await invalidate();
  };

  return (
    <View style={styles.container} testID="routines-screen">
      {routines.length === 0 ? (
        <View style={styles.emptyWrap}>
          <EmptyState
            testID="routines-empty"
            icon="📋"
            title="ルーティンがありません"
            message="よくやるメニューを登録しておくと、次からは1タップで始められます。"
            action={<Button title="ルーティンを作る" onPress={() => router.push('/routine/create')} testID="routines-empty-create" />}
          />
        </View>
      ) : (
        <FlatList
          data={routines}
          keyExtractor={item => item.id}
          testID="routines-list"
          refreshControl={<RefreshControl refreshing={isFetching} onRefresh={refetch} tintColor={Colors.dark.primary} />}
          contentContainerStyle={styles.listContainer}
          renderItem={({ item }) => (
            <View style={[styles.card, !item.is_active && styles.cardInactive]} testID={`routine-row-${item.id}`}>
              <TouchableOpacity
                style={styles.cardMain}
                accessibilityRole="button"
                onPress={() => router.push(`/routine/${item.id}/edit`)}
                testID={`routine-edit-${item.id}`}
              >
                <View style={[styles.iconContainer, { backgroundColor: item.color }]}>
                  <Text style={styles.icon}>{item.icon}</Text>
                </View>
                <View style={styles.cardInfo}>
                  <Text style={styles.cardTitle}>{item.name}</Text>
                  <Text style={styles.cardSubtitle}>
                    {formatFrequency(item)} ・ {item.routine_exercises.length}種目
                    {item.is_active ? '' : ' ・ 停止中'}
                  </Text>
                </View>
              </TouchableOpacity>

              <View style={styles.actions}>
                <TouchableOpacity
                  onPress={() => void handleToggleActive(item)}
                  style={styles.actionButton}
                  accessibilityRole="button"
                  accessibilityLabel={item.is_active ? '停止する' : '再開する'}
                  testID={`routine-toggle-${item.id}`}
                >
                  <Text style={styles.actionIcon}>{item.is_active ? '⏸' : '▶'}</Text>
                </TouchableOpacity>
                <TouchableOpacity
                  onPress={() => handleDelete(item)}
                  style={styles.actionButton}
                  accessibilityRole="button"
                  accessibilityLabel="削除する"
                  testID={`routine-delete-${item.id}`}
                >
                  <Text style={styles.actionIcon}>🗑</Text>
                </TouchableOpacity>
              </View>
            </View>
          )}
        />
      )}

      <TouchableOpacity
        style={styles.fab}
        onPress={() => router.push('/routine/create')}
        accessibilityRole="button"
        accessibilityLabel="新しく作る"
        testID="routines-fab"
      >
        <Text style={styles.fabIcon}>＋</Text>
      </TouchableOpacity>
    </View>
  );
}

const C = Colors.dark;

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: C.background },
  emptyWrap: { flex: 1, justifyContent: 'center' },
  listContainer: { padding: Spacing.md, paddingBottom: 100 },
  card: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: C.surface,
    borderRadius: Radius.lg,
    marginBottom: Spacing.sm,
    borderWidth: 1,
    borderColor: C.border,
    paddingRight: Spacing.sm,
  },
  cardInactive: { opacity: 0.5 },
  cardMain: { flexDirection: 'row', alignItems: 'center', flex: 1, padding: Spacing.md },
  iconContainer: {
    width: 48,
    height: 48,
    borderRadius: 24,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: Spacing.md,
  },
  icon: { fontSize: 24 },
  cardInfo: { flex: 1 },
  cardTitle: { color: C.textPrimary, fontSize: 16, fontWeight: 'bold', marginBottom: 2 },
  cardSubtitle: { color: C.textSecondary, fontSize: 12 },
  actions: { flexDirection: 'row' },
  actionButton: { padding: Spacing.sm },
  actionIcon: { fontSize: 16 },
  fab: {
    position: 'absolute',
    bottom: Spacing.lg,
    right: Spacing.lg,
    width: 60,
    height: 60,
    borderRadius: 30,
    backgroundColor: C.primary,
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: C.primary,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 5,
  },
  fabIcon: { fontSize: 28, color: '#fff' },
});
