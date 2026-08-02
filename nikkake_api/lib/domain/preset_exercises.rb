# frozen_string_literal: true

require "json"

module Domain
  # プリセット種目。packages/contract/preset_exercises.json が唯一の正。
  #
  # 固定UUID (00000000-0000-4000-8000-{12桁連番}) は4クライアントにも
  # 埋め込まれている。端末ごとにランダムなUUIDを振ると、同期したときに
  # 同じ「腕立て伏せ」が複数生まれてしまう。
  #
  # ここでは JSON を読むだけにして、Ruby 側に値をコピーしない。
  # コピーするとまた5か所目のズレる場所が生まれる。
  module PresetExercises
    CONTRACT_PATH = File.expand_path(
      "../../../packages/contract/preset_exercises.json", __dir__
    )

    def self.all
      @all ||= JSON.parse(File.read(CONTRACT_PATH, encoding: "UTF-8"))
                   .fetch("exercises")
                   .map(&:freeze)
                   .freeze
    end

    def self.find(id) = all.find { _1["id"] == id }
  end
end
