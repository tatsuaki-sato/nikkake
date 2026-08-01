import { Stack } from 'expo-router';
import { Colors } from '../../constants/colors';

/**
 * 認証まわりは任意機能なので、独立したモーダルスタックとして持つ。
 * ここに入らなくてもアプリは完全に使える。
 */
export default function AuthLayout() {
  return (
    <Stack
      screenOptions={{
        headerStyle: { backgroundColor: Colors.dark.surface },
        headerTintColor: Colors.dark.textPrimary,
        contentStyle: { backgroundColor: Colors.dark.background },
      }}
    >
      <Stack.Screen name="login" options={{ title: 'バックアップを有効にする' }} />
      <Stack.Screen name="register" options={{ title: 'アカウント作成' }} />
    </Stack>
  );
}
