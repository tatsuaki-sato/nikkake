import { Stack, ThemeProvider, DarkTheme } from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import { useEffect, useState } from 'react';
import { View, ActivityIndicator, StyleSheet } from 'react-native';
import 'react-native-reanimated';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useAuthStore } from '../stores/authStore';
import { setupNotificationHandler } from '../lib/notifications';
import { prepareLocalData, registerInBackground } from '../lib/bootstrap';
import { Colors } from '../constants/colors';

SplashScreen.preventAutoHideAsync().catch(() => {
  // 既に隠れている場合は無視してよい
});

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      // データ元がローカルストレージなので、取得コストが安く再取得の抑制も要らない
      staleTime: 0,
      retry: false,
      refetchOnWindowFocus: true,
    },
  },
});

export default function RootLayout() {
  const initializeAuth = useAuthStore(s => s.initialize);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    const start = async () => {
      // 初回起動時にプリセット種目と「いつものルーティン」を端末に用意する。
      // ここが終わればサインインの有無に関係なくアプリは完全に使える。
      await prepareLocalData();
      setReady(true);

      // 以降はUIをブロックしない。
      // サーバへの登録も認証確認も通知設定も、表示には必要ない。
      void registerInBackground();
      void initializeAuth();
      setupNotificationHandler();
    };

    void start();
  }, [initializeAuth]);

  useEffect(() => {
    if (ready) {
      SplashScreen.hideAsync().catch(() => {});
    }
  }, [ready]);

  if (!ready) {
    return (
      <View style={styles.loading} testID="app-bootstrap">
        <ActivityIndicator color={Colors.dark.primary} />
      </View>
    );
  }

  const customDarkTheme = {
    ...DarkTheme,
    colors: {
      ...DarkTheme.colors,
      background: Colors.dark.background,
      card: Colors.dark.surface,
      text: Colors.dark.textPrimary,
      primary: Colors.dark.primary,
      border: Colors.dark.border,
    },
  };

  return (
    <QueryClientProvider client={queryClient}>
      <ThemeProvider value={customDarkTheme}>
        <Stack screenOptions={{ headerStyle: { backgroundColor: Colors.dark.surface }, headerTintColor: Colors.dark.textPrimary }}>
          <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
          <Stack.Screen name="(auth)" options={{ headerShown: false, presentation: 'modal' }} />
          <Stack.Screen name="routine/create" options={{ presentation: 'modal', title: 'ルーティン作成' }} />
          <Stack.Screen name="routine/[id]/edit" options={{ presentation: 'modal', title: 'ルーティン編集' }} />
          <Stack.Screen name="workout/[routineId]" options={{ headerShown: false, gestureEnabled: false }} />
          <Stack.Screen name="workout/summary" options={{ headerShown: false, gestureEnabled: false }} />
          <Stack.Screen name="+not-found" options={{ title: '見つかりません' }} />
        </Stack>
      </ThemeProvider>
    </QueryClientProvider>
  );
}

const styles = StyleSheet.create({
  loading: {
    flex: 1,
    backgroundColor: Colors.dark.background,
    justifyContent: 'center',
    alignItems: 'center',
  },
});
