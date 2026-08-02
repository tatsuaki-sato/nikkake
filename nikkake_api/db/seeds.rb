# frozen_string_literal: true

# プリセット種目の投入。冪等なのでデプロイのたびに実行してよい。
count = PresetSyncer.call
puts "プリセット種目を同期しました: #{count}件"
