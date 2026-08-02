import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nikkake_flutter/app.dart';
import 'package:nikkake_flutter/data/local_db.dart';
import 'package:nikkake_flutter/data/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 初期ルーティンのIDは端末ごとに採番されるので、キーを直書きできない。
/// 一覧に出ている該当のボタンを、接頭辞で1件だけ拾う。
Finder routineActionButton(String action) => find.byWidgetPredicate(
      (w) => w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('routine-$action-'),
      description: 'routine-$action-*',
    );

/// アプリ全体を通すシナリオ。
///
/// `flutter test`（ヘッドレスなウィジェットテスト）と
/// `flutter test integration_test`（実機/シミュレータ）の両方から
/// 同じ手順を呼べるように、ここに1本化している。
///
/// 認証は渡さない = 未サインイン状態。
/// このアプリはそれで全機能が使えるので、テスト側の準備は本当にこれだけで済む。

Future<void> pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final db = LocalDb(await LocalStore.open());

  // 既定の 800x600 だとルーティン作成フォームが縦に収まらず、
  // 画面外のウィジェットはビルドされないのでタップできない。
  // スクロール操作をテストごとに挟むより、縦に長い画面として扱う方が意図が読みやすい。
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(NikkakeApp(db: db));
  // ブートストラップ（シード投入）を待つ
  await tester.pumpAndSettle();
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

/// キー付きのTextウィジェットの表示文字列を取り出す。
/// 同じ文字列が画面内に複数あっても、狙った箇所だけを検証できる。
String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data ?? '';

/// 現在の種目の全セットを完了にする
Future<void> completeVisibleSets(WidgetTester tester, int exerciseIndex, int setCount) async {
  for (var i = 1; i <= setCount; i++) {
    final check = find.byKey(Key('set-check-$exerciseIndex-$i'));
    if (check.evaluate().isEmpty) continue;
    await tester.tap(check);
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void registerScenarios() {
  group('起動フロー', () {
    testWidgets('サインインせずに起動でき、ホームが出る', (tester) async {
      await pumpApp(tester);

      expect(find.byKey(const Key('home-screen')), findsOneWidget);
      expect(find.byKey(const Key('login-screen')), findsNothing);
    });

    testWidgets('初回起動でも今日のルーティンがすぐ用意されている', (tester) async {
      await pumpApp(tester);

      expect(find.text('いつものルーティン'), findsOneWidget);
      expect(find.text('今日のルーティン'), findsOneWidget);
    });

    testWidgets('ストリークが0日から表示される', (tester) async {
      await pumpApp(tester);

      expect(find.byKey(const Key('streak-count')), findsOneWidget);
      expect(textOf(tester, 'streak-count'), '0 日');
    });

    testWidgets('初期ルーティンをタップするとその場でワークアウトが始まる', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('いつものルーティン'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('workout-screen')), findsOneWidget);
      expect(
        find.textContaining('腕立て伏せ'),
        findsWidgets,
        reason: '1種目目が表示されているはず',
      );
    });
  });

  group('ルーティン管理', () {
    testWidgets('一覧に初期ルーティンが出る', (tester) async {
      await pumpApp(tester);
      await openTab(tester, 'ルーティン');

      expect(find.byKey(const Key('routines-list')), findsOneWidget);
      expect(find.text('いつものルーティン'), findsOneWidget);
    });

    testWidgets('名前が空だと作成できずエラーが出る', (tester) async {
      await pumpApp(tester);
      await openTab(tester, 'ルーティン');

      await tester.tap(find.byKey(const Key('routines-fab')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('routine-submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('error-message')), findsOneWidget);
      expect(find.text('ルーティン名を入力してください'), findsOneWidget);
      // フォームが開いたまま = 保存されていない
      expect(find.byKey(const Key('routine-form')), findsOneWidget);
    });

    testWidgets('種目が空だと作成できない', (tester) async {
      await pumpApp(tester);
      await openTab(tester, 'ルーティン');

      await tester.tap(find.byKey(const Key('routines-fab')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('routine-name-input')), '種目なし');
      await tester.tap(find.byKey(const Key('routine-submit')));
      await tester.pumpAndSettle();

      expect(find.text('種目を1つ以上追加してください'), findsOneWidget);
    });

    testWidgets('曜日指定で曜日未選択だと作成できない', (tester) async {
      await pumpApp(tester);
      await openTab(tester, 'ルーティン');

      await tester.tap(find.byKey(const Key('routines-fab')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('routine-name-input')), '週次');
      await tester.tap(find.byKey(const Key('frequency-weekly')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add-exercise-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pick-exercise-00000000-0000-4000-8000-000000000009')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('routine-submit')));
      await tester.pumpAndSettle();

      expect(find.text('曜日を1つ以上選んでください'), findsOneWidget);
    });

    testWidgets('新規作成すると一覧とホームの両方に出る', (tester) async {
      await pumpApp(tester);
      await openTab(tester, 'ルーティン');

      await tester.tap(find.byKey(const Key('routines-fab')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('routine-name-input')), '夜の腹筋メニュー');
      await tester.tap(find.byKey(const Key('add-exercise-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pick-exercise-00000000-0000-4000-8000-000000000018')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('exercise-row-0')), findsOneWidget);

      await tester.tap(find.byKey(const Key('routine-submit')));
      await tester.pumpAndSettle();

      expect(find.text('夜の腹筋メニュー'), findsOneWidget);

      await openTab(tester, 'ホーム');
      expect(find.text('夜の腹筋メニュー'), findsOneWidget);
    });

    testWidgets('既存ルーティンを編集すると内容が保存される', (tester) async {
      await pumpApp(tester);
      await openTab(tester, 'ルーティン');

      await tester.tap(routineActionButton('edit'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('routine-name-input')), '朝の全身メニュー');
      await tester.tap(find.byKey(const Key('routine-submit')));
      await tester.pumpAndSettle();

      expect(find.text('朝の全身メニュー'), findsOneWidget);
      expect(find.text('いつものルーティン'), findsNothing);
    });

    testWidgets('一覧から削除できる', (tester) async {
      await pumpApp(tester);
      await openTab(tester, 'ルーティン');

      await tester.tap(routineActionButton('delete'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm-action')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('routines-empty')), findsOneWidget);
      expect(find.text('いつものルーティン'), findsNothing);
    });

    testWidgets('停止したルーティンはホームに出ない', (tester) async {
      await pumpApp(tester);
      await openTab(tester, 'ルーティン');

      await tester.tap(routineActionButton('toggle'));
      await tester.pumpAndSettle();

      expect(find.textContaining('停止中'), findsOneWidget);

      await openTab(tester, 'ホーム');
      expect(find.byKey(const Key('home-empty')), findsOneWidget);
    });
  });

  group('ワークアウト実行', () {
    Future<void> startWorkout(WidgetTester tester) async {
      await tester.tap(find.text('いつものルーティン'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('workout-screen')), findsOneWidget);
    }

    testWidgets('セットを完了にすると休憩タイマーが自動で始まる', (tester) async {
      await pumpApp(tester);
      await startWorkout(tester);

      expect(find.byKey(const Key('rest-timer')), findsNothing);

      await tester.tap(find.byKey(const Key('set-check-0-1')));
      await tester.pump();

      expect(find.byKey(const Key('rest-timer')), findsOneWidget);
      expect(find.text('休憩中'), findsOneWidget);
    });

    testWidgets('休憩タイマーはタップでスキップできる', (tester) async {
      await pumpApp(tester);
      await startWorkout(tester);

      await tester.tap(find.byKey(const Key('set-check-0-1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('rest-timer')));
      await tester.pump();

      expect(find.byKey(const Key('rest-timer')), findsNothing);
    });

    testWidgets('セットを増減できる', (tester) async {
      await pumpApp(tester);
      await startWorkout(tester);

      expect(find.byKey(const Key('set-row-0-3')), findsOneWidget);
      expect(find.byKey(const Key('set-row-0-4')), findsNothing);

      await tester.tap(find.byKey(const Key('add-set')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('set-row-0-4')), findsOneWidget);

      await tester.tap(find.byKey(const Key('remove-set')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('set-row-0-4')), findsNothing);
    });

    testWidgets('種目を移動できる', (tester) async {
      await pumpApp(tester);
      await startWorkout(tester);

      await tester.tap(find.byKey(const Key('workout-next')));
      await tester.pumpAndSettle();
      expect(find.textContaining('2/4'), findsOneWidget);

      await tester.tap(find.byKey(const Key('workout-prev')));
      await tester.pumpAndSettle();
      expect(find.textContaining('1/4'), findsOneWidget);
    });

    testWidgets('時間種目は秒数の入力欄になる', (tester) async {
      await pumpApp(tester);
      await startWorkout(tester);

      await tester.tap(find.byKey(const Key('workout-tab-3'))); // プランク
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('set-duration-3-1')), findsOneWidget);
      expect(find.byKey(const Key('set-reps-3-1')), findsNothing);
    });

    testWidgets('一部だけ完了すると途中記録として保存される', (tester) async {
      await pumpApp(tester);
      await startWorkout(tester);

      await tester.tap(find.byKey(const Key('set-check-0-1')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('workout-finish')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('summary-screen')), findsOneWidget);
      expect(find.text('記録しました'), findsOneWidget);
      expect(find.text('1/11'), findsOneWidget);
    });

    testWidgets('完了後にホームへ戻ると完了扱いになり、ストリークが増える', (tester) async {
      await pumpApp(tester);
      await startWorkout(tester);

      await completeVisibleSets(tester, 0, 3);
      await tester.tap(find.byKey(const Key('workout-finish')));
      await tester.pumpAndSettle();

      expect(textOf(tester, 'summary-streak'), '1 日');

      await tester.tap(find.byKey(const Key('summary-home')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home-screen')), findsOneWidget);
      expect(find.text('今日は完了しました'), findsOneWidget);
    });

    testWidgets('中断すると記録が残らない', (tester) async {
      await pumpApp(tester);
      await startWorkout(tester);

      await tester.tap(find.byKey(const Key('set-check-0-1')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('workout-cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-action')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home-screen')), findsOneWidget);
      expect(textOf(tester, 'streak-count'), '0 日');

      await openTab(tester, '進捗');
      expect(find.byKey(const Key('progress-empty')), findsOneWidget);
    });
  });

  group('進捗', () {
    testWidgets('記録が無いうちは空状態を出す', (tester) async {
      await pumpApp(tester);
      await openTab(tester, '進捗');

      expect(find.byKey(const Key('progress-empty')), findsOneWidget);
      expect(find.text('まだ記録がありません'), findsOneWidget);
    });

    testWidgets('1回記録すると集計とグラフが出る', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('いつものルーティン'));
      await tester.pumpAndSettle();
      await completeVisibleSets(tester, 0, 3);
      await tester.tap(find.byKey(const Key('workout-finish')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('summary-home')));
      await tester.pumpAndSettle();

      await openTab(tester, '進捗');

      expect(find.byKey(const Key('progress-chart')), findsOneWidget);
      expect(find.byKey(const Key('progress-calendar')), findsOneWidget);
      expect(textOf(tester, 'progress-total'), '1回');
      expect(textOf(tester, 'progress-week'), '1回');
      expect(textOf(tester, 'progress-streak'), '1日');
    });
  });

  group('設定とデータの保存先', () {
    testWidgets('未サインインでは端末保存中と表示され、バックアップは任意だと分かる', (tester) async {
      await pumpApp(tester);
      await openTab(tester, '設定');

      expect(find.byKey(const Key('settings-local-card')), findsOneWidget);
      expect(find.text('この端末専用の記録です'), findsOneWidget);
      expect(find.textContaining('サインインしなくても全機能が使えます'), findsOneWidget);
      expect(find.byKey(const Key('settings-enable-backup')), findsOneWidget);
    });

    testWidgets('保存されているデータの件数が出る', (tester) async {
      await pumpApp(tester);
      await openTab(tester, '設定');

      expect(textOf(tester, 'count-routines'), '1');
      expect(textOf(tester, 'count-exercises'), '25');
      expect(textOf(tester, 'count-logs'), '0');
    });

    testWidgets('データを初期化すると初期状態に戻る', (tester) async {
      await pumpApp(tester);

      await openTab(tester, 'ルーティン');
      await tester.tap(find.byKey(const Key('routines-fab')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('routine-name-input')), '消えるルーティン');
      await tester.tap(find.byKey(const Key('add-exercise-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pick-exercise-00000000-0000-4000-8000-000000000009')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('routine-submit')));
      await tester.pumpAndSettle();

      expect(find.text('消えるルーティン'), findsOneWidget);

      await openTab(tester, '設定');
      await tester.tap(find.byKey(const Key('settings-reset')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-action')));
      await tester.pumpAndSettle();

      await openTab(tester, 'ルーティン');
      expect(find.text('消えるルーティン'), findsNothing);
      expect(find.text('いつものルーティン'), findsOneWidget);
    });
  });
}
