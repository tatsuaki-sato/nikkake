import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../providers/auth_controller.dart';
import '../widgets/ui.dart';
import 'login_screen.dart';

/// 設定。
///
/// この画面の主役は「バックアップするかどうか」の説明。
/// サインインは機能を開放するためのものではなく、
/// 端末を変えたときにデータを引き継ぐためだけのもの、と伝わる文言にしてある。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _signOut(BuildContext context, AuthController auth) async {
    final confirmed = await confirmAction(
      context,
      title: 'サインアウト',
      message: 'サインアウトしても記録は消えません。この端末から見えなくなるだけで、'
          '同じアカウントでサインインし直せば戻ります。',
      confirmLabel: 'サインアウト',
    );
    if (!confirmed) return;

    await auth.signOut();
  }

  Future<void> _reset(BuildContext context) async {
    final confirmed = await confirmAction(
      context,
      title: 'データを初期化',
      message: 'この端末のルーティンと記録をすべて削除して、初期状態に戻します。取り消せません。',
      confirmLabel: '初期化する',
    );
    if (!confirmed || !context.mounted) return;

    await context.read<AppState>().resetAll();
  }

  // 「同期」はもう無い。記録がサーバへ送れているかだけを見せる
  String _pendingLabel(AuthController auth) {
    if (auth.lastError != null) return '送信に失敗しました: ${auth.lastError}';
    if (auth.pendingCount > 0) return '未送信の記録: ${auth.pendingCount} 件';
    return 'すべて送信済みです';
  }

  @override
  Widget build(BuildContext context) {
    // Supabaseの初期化に失敗した場合や、認証を組み込まないテスト環境では
    // AuthController が存在しない。その場合もローカルモードとして通常どおり表示する。
    final auth = context.watch<AuthController?>();
    final mode = auth?.mode ?? StorageMode.local;
    final state = context.watch<AppState>();
    final counts = state.counts;

    return ListView(
      key: const Key('settings-screen'),
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        const SectionTitle('データの保存先'),

        if (mode == StorageMode.local || auth == null)
          AppCard(
            key: const Key('settings-local-card'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📱', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: Spacing.md),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'この端末専用の記録です',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkTextPrimary,
                            ),
                          ),
                          SizedBox(height: Spacing.xs),
                          Text(
                            'サインインしなくても全機能が使えます。ただしアプリを削除すると記録も消えます。',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: AppColors.darkTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(color: AppColors.darkBorder, height: Spacing.lg),
                const Text(
                  'メールアドレスを登録すると、機種変更やアプリの入れ直しをしても記録を引き継げます。'
                  '今ある記録はそのまま残ります（作り直しは起きません）。',
                  style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.darkTextSecondary),
                ),
                const SizedBox(height: Spacing.md),
                AppButton(
                  key: const Key('settings-enable-backup'),
                  label: 'バックアップを有効にする',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                ),
              ],
            ),
          )
        else
          AppCard(
            key: const Key('settings-cloud-card'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('☁️', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'バックアップ有効',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkTextPrimary,
                            ),
                          ),
                          const SizedBox(height: Spacing.xs),
                          Text(
                            auth.viewer?.email ?? '',
                            key: const Key('settings-email'),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.darkTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(color: AppColors.darkBorder, height: Spacing.lg),
                Text(
                  _pendingLabel(auth),
                  key: const Key('settings-pending-status'),
                  style: TextStyle(
                    fontSize: 13,
                    color: auth.lastError != null
                        ? AppColors.darkError
                        : AppColors.darkTextSecondary,
                  ),
                ),
                const SizedBox(height: Spacing.md),
                AppButton(
                  key: const Key('settings-flush-now'),
                  label: '今すぐ送信',
                  variant: AppButtonVariant.secondary,
                  onPressed: auth.pendingCount == 0 ? null : auth.flushNow,
                ),
                const SizedBox(height: Spacing.sm),
                AppButton(
                  key: const Key('settings-sign-out'),
                  label: 'サインアウト',
                  variant: AppButtonVariant.ghost,
                  onPressed: () => _signOut(context, auth),
                ),
              ],
            ),
          ),

        const SizedBox(height: Spacing.lg),
        const SectionTitle('保存されているデータ'),
        AppCard(
          key: const Key('settings-counts'),
          child: Column(
            children: [
              _CountRow(label: 'ルーティン', value: counts.routines, valueKey: const Key('count-routines')),
              _CountRow(label: '種目', value: counts.exercises, valueKey: const Key('count-exercises')),
              _CountRow(label: 'ワークアウト記録', value: counts.routineLogs, valueKey: const Key('count-logs')),
              _CountRow(label: 'セット記録', value: counts.exerciseLogs, valueKey: const Key('count-sets')),
            ],
          ),
        ),

        const SizedBox(height: Spacing.lg),
        const SectionTitle('アプリについて'),
        const AppCard(
          child: _CountRow(label: 'バージョン', value: '1.0.0', valueKey: Key('settings-version')),
        ),

        const SizedBox(height: Spacing.lg),
        const SectionTitle('危険な操作'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'この端末のデータをすべて消して初期状態に戻します。'
                'サーバ側も消えます。',
                style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.darkTextSecondary),
              ),
              const SizedBox(height: Spacing.md),
              AppButton(
                key: const Key('settings-reset'),
                label: 'データを初期化',
                variant: AppButtonVariant.danger,
                onPressed: () => _reset(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.xl),
      ],
    );
  }
}

class _CountRow extends StatelessWidget {
  final String label;
  final Object value;
  final Key valueKey;

  const _CountRow({required this.label, required this.value, required this.valueKey});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 14, color: AppColors.darkTextSecondary)),
            Text(
              '$value',
              key: valueKey,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.darkTextPrimary,
              ),
            ),
          ],
        ),
      );
}
