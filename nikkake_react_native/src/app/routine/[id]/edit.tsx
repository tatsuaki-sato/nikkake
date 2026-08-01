import React from 'react';
import { View, ActivityIndicator, StyleSheet, Alert, Platform } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import {
  listExercises,
  getRoutineWithExercises,
  updateRoutine,
  deleteRoutine,
  RoutineInput,
} from '../../../lib/repository';
import { RoutineForm } from '../../../components/RoutineForm';
import { EmptyState, Screen, Spacing } from '../../../components/ui';
import { Colors } from '../../../constants/colors';

export default function RoutineEditScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const queryClient = useQueryClient();

  const exercisesQuery = useQuery({ queryKey: ['exercises'], queryFn: listExercises });
  const routineQuery = useQuery({
    queryKey: ['routine', id],
    queryFn: () => getRoutineWithExercises(id),
    enabled: !!id,
  });

  const handleSubmit = async (input: RoutineInput) => {
    await updateRoutine(id, input);
    await queryClient.invalidateQueries();
    router.back();
  };

  const handleDelete = () => {
    const remove = async () => {
      await deleteRoutine(id);
      await queryClient.invalidateQueries();
      router.back();
    };

    // Alert.alertはWebでは表示されないため、Webはブラウザのconfirmに落とす
    if (Platform.OS === 'web') {
      // eslint-disable-next-line no-alert
      if (typeof confirm === 'function' && !confirm('このルーティンを削除しますか？記録は残ります。')) return;
      void remove();
      return;
    }

    Alert.alert('ルーティンを削除', 'このルーティンを削除しますか？これまでの記録は残ります。', [
      { text: 'キャンセル', style: 'cancel' },
      { text: '削除', style: 'destructive', onPress: () => void remove() },
    ]);
  };

  if (exercisesQuery.isLoading || routineQuery.isLoading) {
    return (
      <View style={styles.loading}>
        <ActivityIndicator color={Colors.dark.primary} />
      </View>
    );
  }

  if (!routineQuery.data) {
    return (
      <Screen style={styles.centered}>
        <EmptyState
          icon="🔍"
          title="ルーティンが見つかりません"
          message="削除された可能性があります。"
          testID="routine-not-found"
        />
      </Screen>
    );
  }

  return (
    <RoutineForm
      exercises={exercisesQuery.data ?? []}
      initial={routineQuery.data}
      submitLabel="保存する"
      onSubmit={handleSubmit}
      onDelete={handleDelete}
    />
  );
}

const styles = StyleSheet.create({
  loading: { flex: 1, backgroundColor: Colors.dark.background, justifyContent: 'center', alignItems: 'center' },
  centered: { justifyContent: 'center', padding: Spacing.md },
});
