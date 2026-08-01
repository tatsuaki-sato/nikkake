import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ActivityIndicator,
  StyleProp,
  ViewStyle,
  TextStyle,
} from 'react-native';
import { Colors } from '../constants/colors';

/**
 * 画面をまたいで使う小さな部品。
 * 3実装(RN/Flutter/KMP)で見た目を揃える必要があるので、
 * 余白・角丸・色はここに集約して各画面で個別に決めない。
 */

const C = Colors.dark;

export const Spacing = { xs: 4, sm: 8, md: 16, lg: 24, xl: 32 } as const;
export const Radius = { sm: 8, md: 12, lg: 16, pill: 999 } as const;

export const Screen: React.FC<{ children: React.ReactNode; style?: StyleProp<ViewStyle>; testID?: string }> = ({
  children,
  style,
  testID,
}) => (
  <View style={[styles.screen, style]} testID={testID}>
    {children}
  </View>
);

export const Card: React.FC<{ children: React.ReactNode; style?: StyleProp<ViewStyle>; testID?: string }> = ({
  children,
  style,
  testID,
}) => (
  <View style={[styles.card, style]} testID={testID}>
    {children}
  </View>
);

export const SectionTitle: React.FC<{ children: React.ReactNode; style?: StyleProp<TextStyle> }> = ({
  children,
  style,
}) => <Text style={[styles.sectionTitle, style]}>{children}</Text>;

export const Label: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <Text style={styles.label}>{children}</Text>
);

interface ButtonProps {
  title: string;
  onPress: () => void;
  variant?: 'primary' | 'secondary' | 'ghost' | 'danger';
  disabled?: boolean;
  loading?: boolean;
  testID?: string;
  style?: StyleProp<ViewStyle>;
}

export const Button: React.FC<ButtonProps> = ({
  title,
  onPress,
  variant = 'primary',
  disabled,
  loading,
  testID,
  style,
}) => {
  const isDisabled = disabled || loading;

  return (
    <TouchableOpacity
      testID={testID}
      accessibilityRole="button"
      accessibilityState={{ disabled: !!isDisabled }}
      style={[styles.button, buttonVariants[variant], isDisabled && styles.buttonDisabled, style]}
      onPress={onPress}
      disabled={isDisabled}
    >
      {loading ? (
        <ActivityIndicator color={variant === 'primary' ? '#fff' : C.primary} />
      ) : (
        <Text style={[styles.buttonText, buttonTextVariants[variant]]}>{title}</Text>
      )}
    </TouchableOpacity>
  );
};

export const EmptyState: React.FC<{
  icon: string;
  title: string;
  message: string;
  action?: React.ReactNode;
  testID?: string;
}> = ({ icon, title, message, action, testID }) => (
  <View style={styles.emptyState} testID={testID}>
    <Text style={styles.emptyIcon}>{icon}</Text>
    <Text style={styles.emptyTitle}>{title}</Text>
    <Text style={styles.emptyMessage}>{message}</Text>
    {action ? <View style={styles.emptyAction}>{action}</View> : null}
  </View>
);

export const ErrorText: React.FC<{ children: React.ReactNode }> = ({ children }) =>
  children ? (
    <Text style={styles.errorText} accessibilityRole="alert" testID="error-message">
      {children}
    </Text>
  ) : null;

export const Divider: React.FC = () => <View style={styles.divider} />;

export const Badge: React.FC<{ label: string; color?: string }> = ({ label, color = C.primary }) => (
  <View style={[styles.badge, { borderColor: color }]}>
    <Text style={[styles.badgeText, { color }]}>{label}</Text>
  </View>
);

const buttonVariants: Record<NonNullable<ButtonProps['variant']>, ViewStyle> = {
  primary: { backgroundColor: C.primary },
  secondary: { backgroundColor: C.surfaceElevated, borderWidth: 1, borderColor: C.border },
  ghost: { backgroundColor: 'transparent' },
  danger: { backgroundColor: 'transparent', borderWidth: 1, borderColor: C.error },
};

const buttonTextVariants: Record<NonNullable<ButtonProps['variant']>, TextStyle> = {
  primary: { color: '#fff' },
  secondary: { color: C.textPrimary },
  ghost: { color: C.primaryLight },
  danger: { color: C.error },
};

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: C.background,
  },
  card: {
    backgroundColor: C.surface,
    borderRadius: Radius.lg,
    padding: Spacing.md,
    borderWidth: 1,
    borderColor: C.border,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: C.textPrimary,
    marginBottom: Spacing.md,
  },
  label: {
    fontSize: 13,
    fontWeight: '600',
    color: C.textSecondary,
    marginBottom: Spacing.sm,
  },
  button: {
    minHeight: 48,
    paddingHorizontal: Spacing.lg,
    borderRadius: Radius.sm,
    alignItems: 'center',
    justifyContent: 'center',
  },
  buttonDisabled: {
    opacity: 0.4,
  },
  buttonText: {
    fontSize: 16,
    fontWeight: 'bold',
  },
  emptyState: {
    alignItems: 'center',
    padding: Spacing.xl,
  },
  emptyIcon: {
    fontSize: 56,
    marginBottom: Spacing.md,
  },
  emptyTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: C.textPrimary,
    marginBottom: Spacing.sm,
  },
  emptyMessage: {
    color: C.textSecondary,
    textAlign: 'center',
    lineHeight: 20,
  },
  emptyAction: {
    marginTop: Spacing.lg,
    alignSelf: 'stretch',
  },
  errorText: {
    color: C.error,
    marginBottom: Spacing.md,
    fontSize: 14,
  },
  divider: {
    height: 1,
    backgroundColor: C.border,
    marginVertical: Spacing.md,
  },
  badge: {
    paddingHorizontal: Spacing.sm,
    paddingVertical: 2,
    borderRadius: Radius.pill,
    borderWidth: 1,
    alignSelf: 'flex-start',
  },
  badgeText: {
    fontSize: 11,
    fontWeight: 'bold',
  },
});
