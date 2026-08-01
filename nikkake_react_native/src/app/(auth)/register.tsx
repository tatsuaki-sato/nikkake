import React, { useState } from 'react';
import { View, Text, TextInput, StyleSheet, KeyboardAvoidingView, Platform, ScrollView } from 'react-native';
import { useRouter } from 'expo-router';
import { Colors } from '../../constants/colors';
import { useAuthStore } from '../../stores/authStore';
import { Button, Card, ErrorText, Label, Spacing, Radius } from '../../components/ui';

/**
 * アカウント作成。
 * 既にローカルにあるルーティンと記録は、作成後の初回同期でそのまま引き継がれる。
 */
export default function RegisterScreen() {
  const router = useRouter();
  const signUp = useAuthStore(s => s.signUp);

  const [displayName, setDisplayName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');
  const [done, setDone] = useState(false);

  const handleRegister = async () => {
    if (!email || !password) {
      setErrorMsg('メールアドレスとパスワードを入力してください');
      return;
    }
    if (password.length < 6) {
      setErrorMsg('パスワードは6文字以上にしてください');
      return;
    }

    setLoading(true);
    setErrorMsg('');

    const { error } = await signUp(email.trim(), password, displayName.trim() || undefined);
    setLoading(false);

    if (error) {
      setErrorMsg(error);
      return;
    }

    // メール確認が必要な設定だとこの時点ではサインインが完了していない
    if (useAuthStore.getState().user) {
      router.dismissAll();
    } else {
      setDone(true);
    }
  };

  if (done) {
    return (
      <View style={styles.container} testID="register-done">
        <Card style={styles.doneCard}>
          <Text style={styles.doneTitle}>確認メールを送りました</Text>
          <Text style={styles.doneText}>
            メール内のリンクを開くとバックアップが有効になります。
            それまでも、この端末での記録はこれまで通り続けられます。
          </Text>
          <Button title="アプリに戻る" onPress={() => router.dismissAll()} style={styles.doneButton} />
        </Card>
      </View>
    );
  }

  return (
    <KeyboardAvoidingView style={styles.container} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <ScrollView contentContainerStyle={styles.content} testID="register-screen">
        <Card style={styles.notice}>
          <Text style={styles.noticeText}>
            今この端末にあるルーティンと記録は、アカウント作成後にそのままクラウドへ引き継がれます。
          </Text>
        </Card>

        <ErrorText>{errorMsg}</ErrorText>

        <View style={styles.field}>
          <Label>ニックネーム（任意）</Label>
          <TextInput
            style={styles.input}
            value={displayName}
            onChangeText={setDisplayName}
            placeholder="にっかけ太郎"
            placeholderTextColor={Colors.dark.textSecondary}
            testID="register-name"
          />
        </View>

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
            testID="register-email"
          />
        </View>

        <View style={styles.field}>
          <Label>パスワード（6文字以上）</Label>
          <TextInput
            style={styles.input}
            value={password}
            onChangeText={setPassword}
            placeholder="••••••••"
            placeholderTextColor={Colors.dark.textSecondary}
            secureTextEntry
            testID="register-password"
          />
        </View>

        <Button title="アカウントを作る" onPress={handleRegister} loading={loading} testID="register-submit" />
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const C = Colors.dark;

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: C.background },
  content: { padding: Spacing.lg },
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
  doneCard: { margin: Spacing.lg },
  doneTitle: { color: C.textPrimary, fontSize: 18, fontWeight: 'bold', marginBottom: Spacing.sm },
  doneText: { color: C.textSecondary, fontSize: 13, lineHeight: 20 },
  doneButton: { marginTop: Spacing.lg },
});
