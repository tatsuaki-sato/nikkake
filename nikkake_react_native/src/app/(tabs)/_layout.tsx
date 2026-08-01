import { Tabs } from 'expo-router';
import { Colors } from '../../constants/colors';
import { Text } from 'react-native';

export default function TabLayout() {
  return (
    <Tabs
      screenOptions={{
        headerShown: true,
        headerStyle: {
          backgroundColor: Colors.dark.surface,
          borderBottomWidth: 1,
          borderBottomColor: Colors.dark.border,
        },
        headerTintColor: Colors.dark.textPrimary,
        tabBarStyle: {
          backgroundColor: Colors.dark.surface,
          borderTopWidth: 1,
          borderTopColor: Colors.dark.border,
        },
        tabBarActiveTintColor: Colors.dark.primaryLight,
        tabBarInactiveTintColor: Colors.dark.textSecondary,
      }}
    >
      <Tabs.Screen
        name="index"
        options={{
          title: 'ホーム',
          tabBarIcon: ({ color }) => <Text style={{ fontSize: 20, color }}>🏠</Text>,
        }}
      />
      <Tabs.Screen
        name="routines"
        options={{
          title: 'ルーティン',
          tabBarIcon: ({ color }) => <Text style={{ fontSize: 20, color }}>📋</Text>,
        }}
      />
      <Tabs.Screen
        name="progress"
        options={{
          title: '進捗',
          tabBarIcon: ({ color }) => <Text style={{ fontSize: 20, color }}>📈</Text>,
        }}
      />
      <Tabs.Screen
        name="settings"
        options={{
          title: '設定',
          tabBarIcon: ({ color }) => <Text style={{ fontSize: 20, color }}>⚙️</Text>,
        }}
      />
    </Tabs>
  );
}
