import * as Notifications from 'expo-notifications';
import { Platform } from 'react-native';
import { Routine } from '../../types';

export const setupNotificationHandler = () => {
  Notifications.setNotificationHandler({
    handleNotification: async () => ({
      shouldShowAlert: true,
      shouldPlaySound: true,
      shouldSetBadge: false,
      shouldShowBanner: true,
      shouldShowList: true,
    }),
  });
};

export const requestNotificationPermissions = async (): Promise<boolean> => {
  if (Platform.OS === 'web') return false; // Webは一旦スキップ（ブラウザAPIが別途必要）
  
  const { status: existingStatus } = await Notifications.getPermissionsAsync();
  let finalStatus = existingStatus;
  
  if (existingStatus !== 'granted') {
    const { status } = await Notifications.requestPermissionsAsync();
    finalStatus = status;
  }
  
  return finalStatus === 'granted';
};

export const scheduleRoutineReminder = async (routine: Routine) => {
  if (Platform.OS === 'web' || !routine.is_active || !routine.preferred_time) return;

  const [hours, minutes] = routine.preferred_time.split(':').map(Number);
  
  // まず既存のこのルーティンの通知をキャンセル
  await cancelRoutineReminder(routine.id);

  try {
    if (routine.frequency_type === 'daily' || routine.frequency_type === 'every_n_days') {
      // 毎日指定時刻にローカル通知（every_n_days の場合も一旦毎日鳴らして、不要な日はスキップする等の制御が必要だが、ここでは単純に毎日鳴らす設定とする）
      await Notifications.scheduleNotificationAsync({
        identifier: `routine_${routine.id}`,
        content: {
          title: 'ルーティンの時間です！ 🏋️',
          body: `${routine.icon} ${routine.name} の予定時間になりました。`,
          data: { routineId: routine.id },
        },
        trigger: {
          type: Notifications.SchedulableTriggerInputTypes.DAILY,
          hour: hours,
          minute: minutes,
        },
      });
    } else if (routine.frequency_type === 'weekly' && routine.frequency_days.length > 0) {
      // 曜日ごとに設定
      for (const dayOfWeek of routine.frequency_days) {
        // dayOfWeek: 0(Sun) - 6(Sat). expo-notifications では 1(Sun) - 7(Sat)
        const expoWeekday = dayOfWeek + 1;
        await Notifications.scheduleNotificationAsync({
          identifier: `routine_${routine.id}_day_${dayOfWeek}`,
          content: {
            title: 'ルーティンの時間です！ 🏋️',
            body: `${routine.icon} ${routine.name} の予定時間になりました。`,
            data: { routineId: routine.id },
          },
          trigger: {
            type: Notifications.SchedulableTriggerInputTypes.WEEKLY,
            weekday: expoWeekday,
            hour: hours,
            minute: minutes,
          },
        });
      }
    }
  } catch (error) {
    console.error('Failed to schedule notification:', error);
  }
};

export const cancelRoutineReminder = async (routineId: string) => {
  if (Platform.OS === 'web') return;
  const scheduled = await Notifications.getAllScheduledNotificationsAsync();
  
  for (const notif of scheduled) {
    if (notif.identifier.startsWith(`routine_${routineId}`)) {
      await Notifications.cancelScheduledNotificationAsync(notif.identifier);
    }
  }
};

export const cancelAllReminders = async () => {
  if (Platform.OS === 'web') return;
  await Notifications.cancelAllScheduledNotificationsAsync();
};
