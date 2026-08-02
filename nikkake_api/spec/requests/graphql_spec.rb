# frozen_string_literal: true

require "rails_helper"

# GraphQL を HTTP 越しに叩く結合テスト。
# 認証・認可・冪等性・「今日」の受け渡しといった、
# サービス単体では確認できない層をここで守る。
#
# 注意: ヒアドキュメントと複数行の引数を同じ行に書くと、Ruby が引数側を
# ヒアドキュメント本体として取り込む。variables は必ず先に局所変数へ束縛する。
RSpec.describe "GraphQL API", type: :request do
  before { PresetSyncer.call }

  PUSH_UP_ID = "00000000-0000-4000-8000-000000000003"

  def post_graphql(query, variables: {}, token: nil, time_zone: "Asia/Tokyo")
    headers = { "CONTENT_TYPE" => "application/json" }
    headers["Authorization"] = "Bearer #{token}" if token
    headers["X-Nikkake-Timezone"] = time_zone

    post "/graphql", params: { query: query, variables: variables }.to_json, headers: headers
    JSON.parse(response.body)
  end

  # 匿名アカウントを1つ作り、初期ルーティンまで用意する
  def signed_up
    query = <<~GQL
      mutation($tz: String!) {
        createAnonymousAccount(timeZone: $tz) {
          token
          viewer { id isAnonymous }
          userErrors { message }
        }
      }
    GQL

    payload = post_graphql(query, variables: { tz: "Asia/Tokyo" }).dig("data", "createAnonymousAccount")
    user = User.find(payload.dig("viewer", "id"))
    StarterRoutineBuilder.call(user: user)
    [ payload["token"], user ]
  end

  RECORD_WORKOUT = <<~GQL
    mutation($id: ID!, $rid: ID!, $date: Date!, $sets: [RecordedSetInput!]!, $total: Int!) {
      recordWorkout(
        id: $id, routineId: $rid, logDate: $date, timeZone: "Asia/Tokyo",
        startedAt: "2026-08-05T10:00:00Z", durationSec: 600,
        totalSets: $total, sets: $sets
      ) {
        routineLog { id status logDate }
        summary { completedSets totalSets totalVolume status }
        streak { current }
        userErrors { message code }
      }
    }
  GQL

  def a_set(exercise_id: PUSH_UP_ID, number: 1, reps: 10, weight: 50.0)
    { id: SecureRandom.uuid, exerciseId: exercise_id, setNumber: number,
      actualReps: reps, actualWeight: weight }
  end

  describe "匿名アカウントの発行" do
    it "識別情報を送らずにトークンを取得できる" do
      query = <<~GQL
        mutation($tz: String!) {
          createAnonymousAccount(timeZone: $tz) {
            token
            viewer { id isAnonymous email storageMode }
            userErrors { message code }
          }
        }
      GQL

      payload = post_graphql(query, variables: { tz: "Asia/Tokyo" }).dig("data", "createAnonymousAccount")

      expect(payload["token"]).to be_present
      expect(payload.dig("viewer", "isAnonymous")).to be(true)
      expect(payload.dig("viewer", "email")).to be_nil
      expect(payload["userErrors"]).to be_empty
    end

    it "作った直後から今日やるルーティンが1件ある（起動直後に1タップで始められる）" do
      create = <<~GQL
        mutation { createAnonymousAccount(timeZone: "Asia/Tokyo") { token } }
      GQL
      token = post_graphql(create).dig("data", "createAnonymousAccount", "token")

      home = post_graphql(HOME_QUERY, variables: { today: "2026-08-05" }, token: token).dig("data", "home")

      expect(home["due"].size).to eq(1)
      expect(home.dig("due", 0, "routine", "name")).to eq("いつものルーティン")

      # 種目まで揃っていること（1タップで開始できる条件）
      routine_id = home.dig("due", 0, "routine", "id")
      session = post_graphql(SESSION_QUERY, variables: { rid: routine_id }, token: token)
      expect(session.dig("data", "workoutSession", "exercises").size).to eq(4)
    end

    it "ネイティブ向けに初期ルーティンを作らせないこともできる" do
      # 端末側でシードしてから importSnapshot する経路。両方で作ると2つできる
      create = <<~GQL
        mutation { createAnonymousAccount(timeZone: "Asia/Tokyo", withStarterRoutine: false) { token } }
      GQL
      token = post_graphql(create).dig("data", "createAnonymousAccount", "token")

      home = post_graphql(HOME_QUERY, variables: { today: "2026-08-05" }, token: token).dig("data", "home")

      expect(home["due"]).to be_empty
    end
  end

  describe "認証" do
    it "トークンが無いとデータを取れない" do
      body = post_graphql("{ viewer { id } }")

      expect(body["errors"].first["message"]).to eq("認証が必要です")
      expect(body["errors"].first.dig("extensions", "code")).to eq("UNAUTHENTICATED")
    end

    it "偽のトークンでも取れない" do
      body = post_graphql("{ viewer { id } }", token: "fake")
      expect(body["errors"].first.dig("extensions", "code")).to eq("UNAUTHENTICATED")
    end
  end

  describe "認可" do
    it "他人のルーティンは取得できない（存在しないIDと同じ扱いにして存在を漏らさない）" do
      _token_a, user_a = signed_up
      token_b, = signed_up
      routine_a = user_a.routines.kept.first

      body = post_graphql(
        "query($id: ID!) { routine(id: $id) { id name } }",
        variables: { id: routine_a.id }, token: token_b
      )

      expect(body.dig("data", "routine")).to be_nil
      expect(body["errors"]).to be_nil
    end

    it "他人のルーティンには記録できない" do
      _token_a, user_a = signed_up
      token_b, = signed_up
      vars = { id: SecureRandom.uuid, rid: user_a.routines.kept.first.id,
               date: "2026-08-05", sets: [], total: 1 }

      body = post_graphql(RECORD_WORKOUT, variables: vars, token: token_b)

      expect(body.dig("data", "recordWorkout", "routineLog")).to be_nil
      expect(body.dig("data", "recordWorkout", "userErrors").first["code"]).to eq("NOT_FOUND")
    end
  end

  HOME_QUERY = <<~GQL
      query($today: Date!) {
        home(today: $today, timeZone: "Asia/Tokyo") {
          today
          streak { current longest }
          due { routine { id name } isDueToday isCompleted frequencyLabel }
          completed { routine { name } }
        }
    }
  GQL

  describe "ホーム" do
    it "起動直後に今日やるルーティンが1件返る" do
      token, = signed_up

      home = post_graphql(HOME_QUERY, variables: { today: "2026-08-05" }, token: token).dig("data", "home")

      expect(home["today"]).to eq("2026-08-05")
      expect(home["due"].size).to eq(1)
      expect(home.dig("due", 0, "routine", "name")).to eq("いつものルーティン")
      expect(home.dig("due", 0, "frequencyLabel")).to eq("毎日")
      expect(home.dig("streak", "current")).to eq(0)
      expect(home["completed"]).to be_empty
    end

    it "クライアントが送った today がそのまま使われる（サーバは今日を計算しない）" do
      token, = signed_up

      home = post_graphql(HOME_QUERY, variables: { today: "2020-01-01" }, token: token).dig("data", "home")

      expect(home["today"]).to eq("2020-01-01")
    end

    it "記録すると完了区分へ移る" do
      token, user = signed_up
      vars = { id: SecureRandom.uuid, rid: user.routines.kept.first.id,
               date: "2026-08-05", sets: [ a_set ], total: 11 }
      post_graphql(RECORD_WORKOUT, variables: vars, token: token)

      home = post_graphql(HOME_QUERY, variables: { today: "2026-08-05" }, token: token).dig("data", "home")

      expect(home["due"]).to be_empty
      expect(home["completed"].size).to eq(1)
    end
  end

  describe "ワークアウトの記録" do
    it "サマリーとストリークが返る" do
      token, user = signed_up
      vars = { id: SecureRandom.uuid, rid: user.routines.kept.first.id,
               date: "2026-08-05", sets: [ a_set ], total: 1 }

      payload = post_graphql(RECORD_WORKOUT, variables: vars, token: token).dig("data", "recordWorkout")

      expect(payload["userErrors"]).to be_empty
      expect(payload.dig("routineLog", "status")).to eq("COMPLETED")
      expect(payload.dig("summary", "totalVolume")).to eq(500.0)
      expect(payload.dig("streak", "current")).to eq(1)
    end

    it "一部だけなら PARTIAL になる（status はサーバが判定する）" do
      token, user = signed_up
      vars = { id: SecureRandom.uuid, rid: user.routines.kept.first.id,
               date: "2026-08-05", sets: [ a_set ], total: 11 }

      payload = post_graphql(RECORD_WORKOUT, variables: vars, token: token).dig("data", "recordWorkout")

      expect(payload.dig("routineLog", "status")).to eq("PARTIAL")
    end

    it "同じ id で再送しても二重登録されない" do
      token, user = signed_up
      vars = { id: SecureRandom.uuid, rid: user.routines.kept.first.id,
               date: "2026-08-05", sets: [], total: 1 }

      2.times { post_graphql(RECORD_WORKOUT, variables: vars, token: token) }

      expect(user.routine_logs.kept.count).to eq(1)
    end
  end

  describe "ルーティンの作成" do
    CREATE_ROUTINE = <<~GQL
      mutation($id: ID!, $name: String!, $type: FrequencyType!, $days: [Int!],
               $exercises: [RoutineExerciseInput!]!) {
        createRoutine(id: $id, name: $name, icon: "💪", color: "#6C5CE7",
                      frequencyType: $type, frequencyDays: $days, exercises: $exercises) {
          routine { id name frequencyType }
          userErrors { message code path }
        }
      }
    GQL

    def an_exercise
      { id: SecureRandom.uuid, exerciseId: PUSH_UP_ID, targetSets: 3, targetReps: 10 }
    end

    it "名前が空だと弾く" do
      token, = signed_up
      vars = { id: SecureRandom.uuid, name: "", type: "DAILY", days: [], exercises: [ an_exercise ] }

      error = post_graphql(CREATE_ROUTINE, variables: vars, token: token)
              .dig("data", "createRoutine", "userErrors").first

      expect(error["message"]).to eq("ルーティン名を入力してください")
      expect(error["code"]).to eq("VALIDATION")
    end

    it "種目が空だと弾く" do
      token, = signed_up
      vars = { id: SecureRandom.uuid, name: "空", type: "DAILY", days: [], exercises: [] }

      error = post_graphql(CREATE_ROUTINE, variables: vars, token: token)
              .dig("data", "createRoutine", "userErrors").first

      expect(error["message"]).to eq("種目を1つ以上追加してください")
    end

    it "曜日指定で曜日未選択だと弾く" do
      token, = signed_up
      vars = { id: SecureRandom.uuid, name: "週次", type: "WEEKLY", days: [], exercises: [ an_exercise ] }

      error = post_graphql(CREATE_ROUTINE, variables: vars, token: token)
              .dig("data", "createRoutine", "userErrors").first

      expect(error["message"]).to eq("曜日を1つ以上選んでください")
    end

    it "正しい入力なら作成できる" do
      token, user = signed_up
      vars = { id: SecureRandom.uuid, name: "夜の腹筋", type: "DAILY", days: [], exercises: [ an_exercise ] }

      payload = post_graphql(CREATE_ROUTINE, variables: vars, token: token).dig("data", "createRoutine")

      expect(payload["userErrors"]).to be_empty
      expect(payload.dig("routine", "name")).to eq("夜の腹筋")
      expect(user.routines.kept.pluck(:name)).to include("夜の腹筋")
    end
  end

  SESSION_QUERY = <<~GQL
      query($rid: ID!) {
        workoutSession(routineId: $rid) {
          routine { name }
          exercises { exercise { name } previousLabel restSec targetDurationSec }
        }
    }
  GQL

  describe "ワークアウトセッション" do
    it "前回の記録が previousLabel として返る" do
      token, user = signed_up
      routine = user.routines.kept.first
      vars = { id: SecureRandom.uuid, rid: routine.id, date: "2026-08-05",
               sets: [ a_set(reps: 12, weight: 55.0) ], total: 1 }
      post_graphql(RECORD_WORKOUT, variables: vars, token: token)

      entries = post_graphql(SESSION_QUERY, variables: { rid: routine.id }, token: token)
                .dig("data", "workoutSession", "exercises")

      expect(entries.size).to eq(4)
      expect(entries.first["previousLabel"]).to eq("55.0×12")
      # プランクは時間計測なので targetDurationSec が入る
      expect(entries.last["targetDurationSec"]).to eq(30)
    end

    it "記録が無ければ previousLabel は null" do
      token, user = signed_up

      entries = post_graphql(SESSION_QUERY, variables: { rid: user.routines.kept.first.id }, token: token)
                .dig("data", "workoutSession", "exercises")

      expect(entries.map { _1["previousLabel"] }).to all(be_nil)
    end
  end

  describe "遅延登録（importSnapshot）" do
    it "端末ローカルのデータを取り込める" do
      token, user = signed_up
      routines = [ {
        id: SecureRandom.uuid, name: "取り込んだルーティン", color: "#00B894", icon: "🏃",
        frequency_type: "daily", frequency_value: 1, frequency_days: [],
        is_active: true, sort_order: 1,
        created_at: "2026-08-01T00:00:00Z", updated_at: "2026-08-01T00:00:00Z"
      } ]
      query = <<~GQL
        mutation($routines: [JSON!]) {
          importSnapshot(routines: $routines) {
            imported { routines }
            userErrors { message }
          }
        }
      GQL

      body = post_graphql(query, variables: { routines: routines }, token: token)

      expect(body.dig("data", "importSnapshot", "userErrors")).to be_empty
      expect(user.routines.kept.pluck(:name)).to include("取り込んだルーティン")
    end
  end

  describe "進捗" do
    PROGRESS_QUERY = <<~GQL
      query($today: Date!) {
        progress(today: $today, timeZone: "Asia/Tokyo", rangeDays: 7) {
          overall { totalWorkouts thisWeekCount }
          streak { current }
          dailyStats { date completedCount }
          completedDates
          exercisesWithLogs { name }
        }
      }
    GQL

    it "記録前は空で、日別統計は指定日数ぶん返る" do
      token, = signed_up

      progress = post_graphql(PROGRESS_QUERY, variables: { today: "2026-08-05" }, token: token)
                 .dig("data", "progress")

      expect(progress.dig("overall", "totalWorkouts")).to eq(0)
      expect(progress["dailyStats"].size).to eq(7)
      expect(progress["completedDates"]).to be_empty
    end

    it "記録すると集計に反映される" do
      token, user = signed_up
      vars = { id: SecureRandom.uuid, rid: user.routines.kept.first.id,
               date: "2026-08-05", sets: [ a_set ], total: 1 }
      post_graphql(RECORD_WORKOUT, variables: vars, token: token)

      progress = post_graphql(PROGRESS_QUERY, variables: { today: "2026-08-05" }, token: token)
                 .dig("data", "progress")

      expect(progress.dig("overall", "totalWorkouts")).to eq(1)
      expect(progress["completedDates"]).to eq([ "2026-08-05" ])
      expect(progress["exercisesWithLogs"].map { _1["name"] }).to eq([ "腕立て伏せ" ])
    end
  end
end
