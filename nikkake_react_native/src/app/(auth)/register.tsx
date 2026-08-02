import React, { useState } from 'react';
import { View, Text, TextInput, StyleSheet, KeyboardAvoidingView, Platform, ScrollView } from 'react-native';
import { useRouter } from 'expo-router';
import { Colors } from '../../constants/colors';
import { useSessionStore } from '../../stores/sessionStore';
import { Button, Card, ErrorText, Label, Spacing, Radius } from '../../components/ui';

/**
 * アカウント作成。
 *
 * 新しいアカウントを作るのではなく、いま使っている匿名アカウントに
 * メールとパスワードを足す。user.id が変わらないので、
 * **これまでの記録は1件も移動しない**（引き継ぎ処理そのものが要らない）。
 */
export default function RegisterScreen() {
  const router = useRouter();
  const signUp = useSessionStore(s => s.signUp);

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

    // 登録はこの時点で有効。メール確認は未導入（docs/QA.md の C4）なので、
    // 「確認メールを送りました」とは出さない。送っていないものを送ったと書かない
    setDone(true);
  };

  if (done) {
    return (
      <View style={styles.container} testID="register-done">
        <Card style={styles.doneCard}>
          <Text style={styles.doneTitle}>登録が完了しました</Text>
          <Text style={styles.doneText}>
            これまでの記録はそのまま残っています。
            機種変更やアプリの入れ直しをしても、このメールアドレスで元に戻せます。
          </Text>
          <Button
            title="アプリに戻る"
            // dismissAll() は expo-router の Web 実装だとサインイン画面に留まる。
            // 登録 → サインイン → タブ の2枚を確実に戻す
            onPress={() => {
              if (router.canGoBack()) router.back();
              if (router.canGoBack()) router.back();
            }}
            testID="register-back"
            style={styles.doneButton}
          />
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
