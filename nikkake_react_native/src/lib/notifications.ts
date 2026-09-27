import * as Notifications from 'expo-notifications';
import { Platform } from 'react-native';
import type { HomeView } from './views';
import { planReminders, REMINDER_ID_PREFIX } from './reminders';

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

/**
 * 通知をホームの状態に合わせて並べ直す。ホームを読むたびに呼ぶ。
 * 許可が無ければ何もしない（許可はフォームで通知をオンにしたときに求める）。
 */
let syncing: Promise<void> = Promise.resolve();

export const syncReminders = (home: HomeView, now: Date = new Date()): Promise<void> => {
  // 連続で呼ばれても、取り消しと予約が混ざらないよう1本ずつ流す
  syncing = syncing.then(() => applyReminders(home, now)).catch(error => {
    console.error('Failed to schedule notifications:', error);
  });
  return syncing;
};

const applyReminders = async (home: HomeView, now: Date) => {
  if (Platform.OS === 'web') return;
  const { status } = await Notifications.getPermissionsAsync();
  if (status !== 'granted') return;

  const scheduled = await Notifications.getAllScheduledNotificationsAsync();
  for (const notif of scheduled) {
    if (notif.identifier.startsWith(REMINDER_ID_PREFIX)) {
      await Notifications.cancelScheduledNotificationAsync(notif.identifier);
    }
  }

  for (const reminder of planReminders(home, now)) {
    await Notifications.scheduleNotificationAsync({
      identifier: reminder.identifier,
      content: {
        title: reminder.title,
        body: reminder.body,
        data: { routineId: reminder.routineId },
      },
      trigger: { type: Notifications.SchedulableTriggerInputTypes.DATE, date: reminder.at },
    });
  }
};

/** 通知をタップしたらそのルーティンのワークアウトを開く */
export const onReminderOpened = (open: (routineId: string) => void) => {
  if (Platform.OS === 'web') return () => {};
  const subscription = Notifications.addNotificationResponseReceivedListener(response => {
    const routineId = response.notification.request.content.data?.routineId;
    if (typeof routineId === 'string') open(routineId);
  });
  return () => subscription.remove();
};

export const cancelAllReminders = async () => {
  if (Platform.OS === 'web') return;
  await Notifications.cancelAllScheduledNotificationsAsync();
};
