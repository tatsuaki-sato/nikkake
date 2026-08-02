import React from 'react';
import { View, Text, StyleSheet, ScrollView, Alert, Platform } from 'react-native';
import { useFocusEffect, useRouter } from 'expo-router';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { Colors } from '../../constants/colors';
import { useSessionStore } from '../../stores/sessionStore';
import { getCounts, resetData } from '../../lib/repository';
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
  const { viewer, mode, pending, lastError, signOut, flushNow, refresh } = useSessionStore();

  const countsQuery = useQuery({ queryKey: ['counts'], queryFn: getCounts });

  // ワークアウトを記録してから戻ってきたときに件数を合わせる。
  // 取り直さないと、記録したのに0件のままに見える
  useFocusEffect(
    React.useCallback(() => {
      void countsQuery.refetch();
      void refresh();
    }, [])
  );

  const counts = countsQuery.data ?? {
    routines: 0,
    exercises: 0,
    routineLogs: 0,
    exerciseLogs: 0,
  };

  const handleSignOut = () => {
    const doSignOut = async () => {
      await signOut();
      await refresh();
      await queryClient.invalidateQueries();
    };

    const message =
      'サインアウトしても記録は消えません。この端末から見えなくなるだけで、'
      + '同じアカウントでサインインし直せば戻ります。';

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
      await resetData();
      await refresh();
      await queryClient.invalidateQueries();
    };

    const message = 'ルーティンと記録をすべて削除して、初期状態に戻します。サーバ側も消えます。取り消せません。';

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

  // 「同期」はもう無い。記録がサーバへ送れているかだけを見せる
  const pendingLabel = () => {
    if (lastError) return `送信に失敗しました: ${lastError}`;
    if (pending > 0) return `未送信の記録: ${pending} 件`;
    return 'すべて送信済みです';
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content} testID="settings-screen">
      <SectionTitle>データの保存先</SectionTitle>

      {mode === 'local' ? (
        <Card testID="settings-local-card">
          <View style={styles.statusRow}>
            <Text style={styles.statusIcon}>📱</Text>
            <View style={styles.statusInfo}>
              <Text style={styles.statusTitle}>この端末専用の記録です</Text>
              <Text style={styles.statusMessage}>
                サインインしなくても全機能が使えます。ただしアプリを削除すると記録も消えます。
              </Text>
            </View>
          </View>

          <Divider />

          <Text style={styles.helpText}>
            メールアドレスを登録すると、機種変更やアプリの入れ直しをしても記録を引き継げます。
            今ある記録はそのまま残ります（作り直しは起きません）。
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
                {viewer?.email}
              </Text>
            </View>
          </View>

          <Divider />

          <Text
            style={[styles.helpText, lastError ? styles.errorText : null]}
            testID="settings-pending-status"
          >
            {pendingLabel()}
          </Text>

          <Button
            title="今すぐ送信"
            variant="secondary"
            onPress={() => void flushNow()}
            disabled={pending === 0}
            testID="settings-flush-now"
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
        <CountRow label="ルーティン" value={counts.routines} testID="count-routines" />
        <CountRow label="種目" value={counts.exercises} testID="count-exercises" />
        <CountRow label="ワークアウト記録" value={counts.routineLogs} testID="count-logs" />
        <CountRow label="セット記録" value={counts.exerciseLogs} testID="count-sets" />
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
