# frozen_string_literal: true

# nikkake のスキーマ。Supabase に本番データが無いので最終形1本で切っている。
#
# 移行前（Supabase + ローカルファースト）からの主な変更:
#   1. 全テーブルに user_id を非正規化して NOT NULL 化
#      移行前は RLS が親を辿って所有者を確認していたが、サーバ主導だと
#      毎クエリで JOIN が必要になりインデックスも効きにくい
#   2. user_id = null を廃止
#      匿名ユーザーも実在レコードなので「ローカル専用データ」の状態が無くなる
#   3. routines.lock_version を追加
#      updated_at による last-write-wins を Rails の楽観ロックに置き換える
#   4. mutation_receipts を新設（オフライン再送の冪等性）
#
# ID はすべてクライアント生成の UUID を受け取る。サーバ採番にすると
# オフラインでレコードを作れなくなり、冪等性の土台も失われる。
class CreateNikkakeSchema < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")
    enable_extension "citext" unless extension_enabled?("citext")

    create_table :users, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.citext   :email                        # 匿名のうちは NULL
      t.string   :password_digest
      t.string   :display_name
      t.datetime :email_verified_at
      # 通知やGCなどリクエストの無い処理で使うフォールバック。
      # 「今日」の判定には使わない（常にリクエストの値を優先する）
      t.string   :time_zone, null: false, default: "Asia/Tokyo"
      t.datetime :last_seen_at
      t.timestamps

      t.index :email, unique: true, where: "email IS NOT NULL"
      t.index :last_seen_at, where: "email IS NULL"   # 未昇格アカウントのGC用
    end

    create_table :api_tokens, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      # 生トークンは発行時にしか存在しない。DB には SHA-256 ダイジェストのみ
      t.string   :token_digest, null: false
      t.string   :device_label
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.timestamps

      t.index :token_digest, unique: true
    end

    create_table :exercises, id: :uuid do |t|
      t.string  :name,     null: false
      t.string  :category, null: false
      t.text    :description
      t.string  :icon
      t.boolean :is_preset, null: false, default: false
      t.references :created_by, type: :uuid, foreign_key: { to_table: :users }
      t.datetime :deleted_at
      t.timestamps

      t.check_constraint "category IN ('strength','cardio','game','custom')",
                         name: "exercises_category_check"
      t.index :updated_at
      t.index :is_preset
    end

    create_table :routines, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string  :name, null: false
      t.text    :description
      t.string  :color, null: false, default: "#6C5CE7"
      t.string  :icon,  null: false, default: "💪"
      t.string  :frequency_type,  null: false, default: "daily"
      t.integer :frequency_value, null: false, default: 1
      t.integer :frequency_days,  array: true, null: false, default: []
      t.time    :preferred_time
      t.boolean :is_active,  null: false, default: true
      t.integer :sort_order, null: false, default: 0
      t.integer :lock_version, null: false, default: 0
      t.datetime :deleted_at
      t.timestamps

      t.check_constraint "frequency_type IN ('daily','every_n_days','weekly')",
                         name: "routines_frequency_type_check"
      t.index [ :user_id, :updated_at ]
      t.index [ :user_id, :sort_order ], where: "deleted_at IS NULL"
    end

    create_table :routine_exercises, id: :uuid do |t|
      t.references :user,     type: :uuid, null: false, foreign_key: true
      t.references :routine,  type: :uuid, null: false, foreign_key: true
      t.references :exercise, type: :uuid, null: false, foreign_key: true
      t.integer :sort_order,  null: false, default: 0
      t.integer :target_sets, null: false, default: 3
      t.integer :target_reps
      t.float   :target_weight
      t.integer :target_duration_sec
      t.integer :rest_sec
      t.text    :notes
      t.datetime :deleted_at
      t.timestamps

      t.index [ :routine_id, :sort_order ], where: "deleted_at IS NULL"
      t.index [ :user_id, :updated_at ]
    end

    create_table :routine_logs, id: :uuid do |t|
      t.references :user,    type: :uuid, null: false, foreign_key: true
      t.references :routine, type: :uuid, null: false, foreign_key: true
      # クライアントが端末のタイムゾーンで決めて送る。サーバは UTC から導出しない
      t.date    :log_date, null: false
      t.string  :status,   null: false
      t.integer :duration_sec
      t.text    :notes
      t.datetime :started_at
      t.datetime :completed_at
      # 記録時のTZ。日付がずれる事故が起きたときに検証・救済するために残す
      t.string  :client_time_zone
      t.integer :client_utc_offset_minutes
      t.datetime :deleted_at
      t.timestamps

      t.check_constraint "status IN ('completed','partial','skipped')",
                         name: "routine_logs_status_check"
      t.index [ :user_id, :log_date ], where: "deleted_at IS NULL"
      t.index [ :user_id, :routine_id, :log_date ]
      t.index [ :user_id, :updated_at ]
    end

    create_table :exercise_logs, id: :uuid do |t|
      t.references :user,        type: :uuid, null: false, foreign_key: true
      t.references :routine_log, type: :uuid, null: false, foreign_key: true
      # ルーティン編集で routine_exercises は作り直されるので、
      # 参照が切れてもログ自体は残す
      t.references :routine_exercise, type: :uuid,
                                      foreign_key: { on_delete: :nullify }
      # 履歴グラフはこちらで辿る。routine_exercise_id 経由だと編集で途切れる
      t.references :exercise, type: :uuid, null: false, foreign_key: true
      t.integer :set_number, null: false
      t.integer :actual_reps
      t.float   :actual_weight
      t.integer :actual_duration_sec
      t.text    :notes
      t.datetime :deleted_at
      t.timestamps

      t.index [ :user_id, :exercise_id ]
      t.index [ :user_id, :updated_at ]
    end

    # オフラインキューの再送で「サーバは処理したが応答が失われた」場合に、
    # 同じ応答を返すためのレシート。主キー衝突による冪等性の補助機構。
    create_table :mutation_receipts, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string  :key,      null: false     # clientMutationId
      t.string  :mutation, null: false
      t.jsonb   :response, null: false
      t.datetime :created_at, null: false

      t.index [ :user_id, :key ], unique: true
      t.index :created_at                  # 30日で GC
    end
  end
end
