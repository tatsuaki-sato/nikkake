import React, { useState } from 'react';
import { View, Text, TextInput, StyleSheet, KeyboardAvoidingView, Platform, ScrollView } from 'react-native';
import { Link, useRouter } from 'expo-router';
import { Colors } from '../../constants/colors';
import { useSessionStore } from '../../stores/sessionStore';
import { Button, Card, ErrorText, Label, Spacing, Radius } from '../../components/ui';

/**
 * サインイン画面。
 *
 * この画面はアプリの入口ではない。設定から任意で開く「バックアップ設定」であり、
 * ここを飛ばしてもアプリの全機能が使えることを画面上でも明示している。
 */
export default function LoginScreen() {
  const router = useRouter();
  const signIn = useSessionStore(s => s.signIn);

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');

  const handleLogin = async () => {
    if (!email || !password) {
      setErrorMsg('メールアドレスとパスワードを入力してください');
      return;
    }

    setLoading(true);
    setErrorMsg('');

    const { error } = await signIn(email.trim(), password);
    setLoading(false);

    if (error) {
      // サーバは userErrors.message にそのまま画面へ出せる日本語を入れて返す
      setErrorMsg(error);
      return;
    }

    router.back();
  };

  return (
    <KeyboardAvoidingView style={styles.container} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <ScrollView contentContainerStyle={styles.content} testID="login-screen">
        <View style={styles.header}>
          <Text style={styles.title}>nikkake</Text>
          <Text style={styles.subtitle}>毎日の日課を、習慣に。</Text>
        </View>

        <Card style={styles.notice} testID="login-optional-notice">
          <Text style={styles.noticeText}>
            サインインは任意です。しなくてもルーティンの作成も記録も全部使えます。
            機種変更やアプリの入れ直しで記録を失いたくない場合だけ設定してください。
          </Text>
        </Card>

        <ErrorText>{errorMsg}</ErrorText>

        <View style={styles.field}>
          <Label>メールアドレス</Label>
          <TextInput
            style={styles.input}
            value={email}
            onChangeText={setEmail}
            placeholder="example@email.com"
            placeholderTextColor={Colors.dark.textSecondary}
            autoCapitalize="none"
            autoCorrect={false}
            keyboardType="email-address"
            testID="login-email"
          />
        </View>

        <View style={styles.field}>
          <Label>パスワード</Label>
          <TextInput
            style={styles.input}
            value={password}
            onChangeText={setPassword}
            placeholder="••••••••"
            placeholderTextColor={Colors.dark.textSecondary}
            secureTextEntry
            testID="login-password"
          />
        </View>

        <Button title="サインイン" onPress={handleLogin} loading={loading} testID="login-submit" />

        <Link href="/(auth)/register" style={styles.link} testID="login-to-register">
          <Text style={styles.linkText}>アカウントを作る</Text>
        </Link>

        <Button
          title="あとで設定する"
          variant="ghost"
          onPress={() => router.back()}
          testID="login-skip"
          style={styles.skipButton}
        />
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const C = Colors.dark;

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: C.background },
  content: { padding: Spacing.lg, paddingTop: Spacing.xl },
  header: { alignItems: 'center', marginBottom: Spacing.lg },
  title: { fontSize: 32, fontWeight: 'bold', color: C.primaryLight },
  subtitle: { fontSize: 14, color: C.textSecondary, marginTop: Spacing.xs },
  notice: { marginBottom: Spacing.lg, backgroundColor: C.surfaceElevated },
  noticeText: { color: C.textSecondary, fontSize: 13, lineHeight: 20 },
  field: { marginBottom: Spacing.md },
  input: {
    backgroundColor: C.surface,
    padding: Spacing.md,
    borderRadius: Radius.sm,
    color: C.textPrimary,
    borderWidth: 1,
    borderColor: C.border,
  },
  link: { marginTop: Spacing.lg, alignSelf: 'center' },
  linkText: { color: C.primaryLight, fontSize: 14 },
  skipButton: { marginTop: Spacing.sm },
});
