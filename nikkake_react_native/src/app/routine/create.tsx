import React from 'react';
import { View, ActivityIndicator, StyleSheet } from 'react-native';
import { useRouter } from 'expo-router';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { listExercises, createRoutine, RoutineInput } from '../../lib/repository';
import { RoutineForm } from '../../components/RoutineForm';
import { Colors } from '../../constants/colors';

export default function RoutineCreateScreen() {
  const router = useRouter();
  const queryClient = useQueryClient();

  const { data: exercises, isLoading } = useQuery({ queryKey: ['exercises'], queryFn: listExercises });

  const handleSubmit = async (input: RoutineInput) => {
    await createRoutine(input);
    await queryClient.invalidateQueries();
    router.back();
  };

  if (isLoading || !exercises) {
    return (
      <View style={styles.loading}>
        <ActivityIndicator color={Colors.dark.primary} />
      </View>
    );
  }

  return <RoutineForm exercises={exercises} submitLabel="作成する" onSubmit={handleSubmit} />;
}

const styles = StyleSheet.create({
  loading: { flex: 1, backgroundColor: Colors.dark.background, justifyContent: 'center', alignItems: 'center' },
});
