# frozen_string_literal: true

# 設計上の約束をコードレビュー任せにせず、機械的に守るためのテスト。
#
# ここが落ちたら、実装ではなく「約束を破った」ということ。
# 例外を認める場合は、理由をコメントで書いたうえで ALLOW リストに足す。
RSpec.describe "アーキテクチャの約束" do
  APP_ROOT = File.expand_path("..", __dir__)

  def ruby_files(*globs)
    globs.flat_map { Dir[File.join(APP_ROOT, _1)] }
         .reject { _1.include?("/vendor/") }
  end

  # コメントと文字列リテラルを落としてから検査する。
  # そうしないと「Date.today を使ってはいけない」という説明コメント自体にマッチする。
  def code_of(path)
    File.read(path, encoding: "UTF-8")
        .lines
        .reject { _1.lstrip.start_with?("#") }
        .join
        .gsub(/"(?:[^"\\]|\\.)*"/, '""')
        .gsub(/'(?:[^'\\]|\\.)*'/, "''")
  end

  describe "サーバは「今日」を計算しない" do
    # サーバが Date.today を使うと、日本の朝8時が UTC では前日23時なので即座に1日ずれる。
    # ストリークが1日ずれるのは、この習慣化アプリで最も致命的なバグ。
    # 「今日」は必ずクライアントが端末TZで決めて送る（schema.graphql の today 引数）。
    FORBIDDEN = /\b(Date\.today|Date\.current|Time\.current\.to_date|Time\.now\.to_date|Time\.zone\.today)\b/

    it "app/domain, app/services, app/graphql で今日を求めていない" do
      offenders = ruby_files("app/domain/**/*.rb", "app/services/**/*.rb", "app/graphql/**/*.rb")
                  .select { code_of(_1).match?(FORBIDDEN) }
                  .map { _1.delete_prefix("#{APP_ROOT}/") }

      expect(offenders).to be_empty, <<~MSG
        「今日」をサーバで計算しているファイルがあります:
          #{offenders.join("\n  ")}

        日付はクライアントが端末のタイムゾーンで決めて送ります。
        サーバで求めるとタイムゾーンで1日ずれ、ストリークが壊れます。
      MSG
    end
  end

  describe "所有者スコープを経由せずにレコードを引かない" do
    # PostgreSQL の RLS を捨てる代わりの防御。
    # current_user の association から辿らないと、他人のデータが取れてしまう。
    OWNED_MODELS = %w[Routine RoutineLog ExerciseLog RoutineExercise].freeze

    it "リゾルバ・ミューテーションがモデルクラスから直接 find/where していない" do
      pattern = /\b(#{OWNED_MODELS.join('|')})\.(find|find_by|where|all|first|last)\b/

      offenders = ruby_files("app/graphql/**/*.rb")
                  .select { code_of(_1).match?(pattern) }
                  .map { _1.delete_prefix("#{APP_ROOT}/") }

      expect(offenders).to be_empty, <<~MSG
        モデルクラスから直接引いているファイルがあります:
          #{offenders.join("\n  ")}

        必ず current_user.routines のように所有者から辿ってください。
      MSG
    end
  end

  describe "ドメイン層は ActiveRecord に依存しない" do
    # 依存すると packages/contract/domain_cases.json による
    # TypeScript / Dart / Kotlin との一致テストが書けなくなる。
    it "app/domain が ApplicationRecord やモデルを参照していない" do
      pattern = /\b(ApplicationRecord|ActiveRecord|Routine\b|RoutineLog\b|ExerciseLog\b)/

      offenders = ruby_files("app/domain/**/*.rb")
                  .select { code_of(_1).match?(pattern) }
                  .map { _1.delete_prefix("#{APP_ROOT}/") }

      expect(offenders).to be_empty, <<~MSG
        ドメイン層が ActiveRecord に依存しています:
          #{offenders.join("\n  ")}

        純粋関数のまま保ってください。DB を触る手続きは app/services/ に置きます。
      MSG
    end
  end
end
