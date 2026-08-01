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
      message: 'サインアウトしても、この端末の記録は消えません。クラウドへのバックアップが止まるだけです。',
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

  String _syncLabel(SyncState sync) {
    switch (sync.status) {
      case SyncStatus.syncing:
        return '同期中…';
      case SyncStatus.offline:
        return 'オフラインのため未同期';
      case SyncStatus.error:
        return '同期に失敗: ${sync.lastError ?? '不明なエラー'}';
      case SyncStatus.idle:
        final at = sync.lastSyncedAt?.toLocal();
        return at == null
            ? 'まだ同期していません'
            : '最終同期 ${at.year}/${at.month}/${at.day} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Supabaseの初期化に失敗した場合や、認証を組み込まないテスト環境では
    // AuthController が存在しない。その場合もローカルモードとして通常どおり表示する。
    final auth = context.watch<AuthController?>();
    final mode = auth?.mode ?? StorageMode.local;
    final state = context.watch<AppState>();
    final counts = state.localCounts;

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
                            'この端末にだけ保存中',
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
                  'バックアップを有効にすると、機種変更やアプリの入れ直しをしても記録を引き継げます。'
                  '今ある記録もそのままクラウドへ引き継がれます。',
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
                            auth.user?.email ?? '',
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
                  _syncLabel(auth.sync),
                  key: const Key('settings-sync-status'),
                  style: TextStyle(
                    fontSize: 13,
                    color: auth.sync.status == SyncStatus.error
                        ? AppColors.darkError
                        : AppColors.darkTextSecondary,
                  ),
                ),
                if (auth.pendingCount > 0)
                  Text(
                    '未送信の変更: ${auth.pendingCount} 件',
                    style: const TextStyle(fontSize: 13, color: AppColors.darkTextSecondary),
                  ),
                const SizedBox(height: Spacing.md),
                AppButton(
                  key: const Key('settings-sync-now'),
                  label: '今すぐ同期',
                  variant: AppButtonVariant.secondary,
                  loading: auth.sync.status == SyncStatus.syncing,
                  onPressed: auth.syncNow,
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
              _CountRow(label: 'ルーティン', value: counts['routines'] ?? 0, valueKey: const Key('count-routines')),
              _CountRow(label: '種目', value: counts['exercises'] ?? 0, valueKey: const Key('count-exercises')),
              _CountRow(label: 'ワークアウト記録', value: counts['routine_logs'] ?? 0, valueKey: const Key('count-logs')),
              _CountRow(label: 'セット記録', value: counts['exercise_logs'] ?? 0, valueKey: const Key('count-sets')),
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
                '${mode == StorageMode.cloud ? 'クラウド側のバックアップは残ります。' : ''}',
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
