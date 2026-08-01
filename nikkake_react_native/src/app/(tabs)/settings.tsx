import React from 'react';
import { View, Text, StyleSheet, ScrollView, Alert, Platform } from 'react-native';
import { useRouter } from 'expo-router';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { Colors } from '../../constants/colors';
import { useAuthStore } from '../../stores/authStore';
import { getLocalCounts, getPendingCount } from '../../lib/sync';
import { resetDatabase } from '../../lib/localDb';
import { seedIfNeeded } from '../../lib/seed';
import { Button, Card, Divider, SectionTitle, Spacing, Radius } from '../../components/ui';

/**
 * 設定。
 *
 * この画面の主役は「バックアップするかどうか」の説明。
 * サインインは機能を開放するためのものではなく、
 * 端末を変えたときにデータを引き継ぐためだけのもの、と伝わる文言にしてある。
 */
export default function SettingsScreen() {
  const router = useRouter();
  const queryClient = useQueryClient();
  const { user, mode, sync, signOut, syncNow } = useAuthStore();

  const countsQuery = useQuery({ queryKey: ['localCounts'], queryFn: getLocalCounts });
  const pendingQuery = useQuery({
    queryKey: ['pendingCount', sync.lastSyncedAt],
    queryFn: getPendingCount,
    enabled: mode === 'cloud',
  });

  const counts = countsQuery.data ?? {};

  const handleSignOut = () => {
    const doSignOut = async () => {
      await signOut();
      await queryClient.invalidateQueries();
    };

    const message = 'サインアウトしても、この端末の記録は消えません。クラウドへのバックアップが止まるだけです。';

    if (Platform.OS === 'web') {
      // eslint-disable-next-line no-alert
      if (typeof confirm === 'function' && !confirm(message)) return;
      void doSignOut();
      return;
    }

    Alert.alert('サインアウト', message, [
      { text: 'キャンセル', style: 'cancel' },
      { text: 'サインアウト', style: 'destructive', onPress: () => void doSignOut() },
    ]);
  };

  const handleReset = () => {
    const doReset = async () => {
      await resetDatabase();
      await seedIfNeeded();
      await queryClient.invalidateQueries();
    };

    const message = 'この端末のルーティンと記録をすべて削除して、初期状態に戻します。取り消せません。';

    if (Platform.OS === 'web') {
      // eslint-disable-next-line no-alert
      if (typeof confirm === 'function' && !confirm(message)) return;
      void doReset();
      return;
    }

    Alert.alert('データを初期化', message, [
      { text: 'キャンセル', style: 'cancel' },
      { text: '初期化する', style: 'destructive', onPress: () => void doReset() },
    ]);
  };

  const syncLabel = () => {
    switch (sync.status) {
      case 'syncing':
        return '同期中…';
      case 'offline':
        return 'オフラインのため未同期';
      case 'error':
        return `同期に失敗: ${sync.lastError ?? '不明なエラー'}`;
      default:
        return sync.lastSyncedAt
          ? `最終同期 ${new Date(sync.lastSyncedAt).toLocaleString('ja-JP')}`
          : 'まだ同期していません';
    }
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content} testID="settings-screen">
      <SectionTitle>データの保存先</SectionTitle>

      {mode === 'local' ? (
        <Card testID="settings-local-card">
          <View style={styles.statusRow}>
            <Text style={styles.statusIcon}>📱</Text>
            <View style={styles.statusInfo}>
              <Text style={styles.statusTitle}>この端末にだけ保存中</Text>
              <Text style={styles.statusMessage}>
                サインインしなくても全機能が使えます。ただしアプリを削除すると記録も消えます。
              </Text>
            </View>
          </View>

          <Divider />

          <Text style={styles.helpText}>
            バックアップを有効にすると、機種変更やアプリの入れ直しをしても記録を引き継げます。
            今ある記録もそのままクラウドへ引き継がれます。
          </Text>

          <Button
            title="バックアップを有効にする"
            onPress={() => router.push('/(auth)/login')}
            testID="settings-enable-backup"
            style={styles.actionButton}
          />
        </Card>
      ) : (
        <Card testID="settings-cloud-card">
          <View style={styles.statusRow}>
            <Text style={styles.statusIcon}>☁️</Text>
            <View style={styles.statusInfo}>
              <Text style={styles.statusTitle}>バックアップ有効</Text>
              <Text style={styles.statusMessage} testID="settings-email">
                {user?.email}
              </Text>
            </View>
          </View>

          <Divider />

          <Text style={[styles.helpText, sync.status === 'error' && styles.errorText]} testID="settings-sync-status">
            {syncLabel()}
          </Text>
          {pendingQuery.data ? (
            <Text style={styles.helpText}>未送信の変更: {pendingQuery.data} 件</Text>
          ) : null}

          <Button
            title="今すぐ同期"
            variant="secondary"
            onPress={() => void syncNow()}
            loading={sync.status === 'syncing'}
            testID="settings-sync-now"
            style={styles.actionButton}
          />
          <Button
            title="サインアウト"
            variant="ghost"
            onPress={handleSignOut}
            testID="settings-sign-out"
            style={styles.actionButton}
          />
        </Card>
      )}

      <SectionTitle style={styles.sectionSpacing}>保存されているデータ</SectionTitle>
      <Card testID="settings-counts">
        <CountRow label="ルーティン" value={counts.routines ?? 0} testID="count-routines" />
        <CountRow label="種目" value={counts.exercises ?? 0} testID="count-exercises" />
        <CountRow label="ワークアウト記録" value={counts.routine_logs ?? 0} testID="count-logs" />
        <CountRow label="セット記録" value={counts.exercise_logs ?? 0} testID="count-sets" />
      </Card>

      <SectionTitle style={styles.sectionSpacing}>アプリについて</SectionTitle>
      <Card>
        <CountRow label="バージョン" value="1.0.0" testID="settings-version" />
      </Card>

      <SectionTitle style={styles.sectionSpacing}>危険な操作</SectionTitle>
      <Card>
        <Text style={styles.helpText}>
          この端末のデータをすべて消して初期状態に戻します。
          {mode === 'cloud' ? 'クラウド側のバックアップは残ります。' : ''}
        </Text>
        <Button
          title="データを初期化"
          variant="danger"
          onPress={handleReset}
          testID="settings-reset"
          style={styles.actionButton}
        />
      </Card>

      <View style={{ height: Spacing.xl }} />
    </ScrollView>
  );
}

const CountRow: React.FC<{ label: string; value: number | string; testID: string }> = ({ label, value, testID }) => (
  <View style={styles.countRow}>
    <Text style={styles.countLabel}>{label}</Text>
    <Text style={styles.countValue} testID={testID}>
      {value}
    </Text>
  </View>
);

const C = Colors.dark;

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: C.background },
  content: { padding: Spacing.md },
  statusRow: { flexDirection: 'row', alignItems: 'flex-start', gap: Spacing.md },
  statusIcon: { fontSize: 28 },
  statusInfo: { flex: 1 },
  statusTitle: { color: C.textPrimary, fontSize: 16, fontWeight: 'bold', marginBottom: Spacing.xs },
  statusMessage: { color: C.textSecondary, fontSize: 13, lineHeight: 19 },
  helpText: { color: C.textSecondary, fontSize: 13, lineHeight: 19 },
  errorText: { color: C.error },
  actionButton: { marginTop: Spacing.md },
  sectionSpacing: { marginTop: Spacing.lg },
  countRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: Spacing.sm,
  },
  countLabel: { color: C.textSecondary, fontSize: 14 },
  countValue: { color: C.textPrimary, fontSize: 15, fontWeight: 'bold' },
});
