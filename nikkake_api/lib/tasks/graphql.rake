# frozen_string_literal: true

namespace :graphql do
  desc "実装から schema.graphql を書き出す"
  task dump: :environment do
    path = Rails.root.join("../packages/contract/schema.generated.graphql")
    File.write(path, NikkakeSchema.to_definition)
    puts "書き出しました: #{path}"
  end

  desc "実装と契約(packages/contract/schema.graphql)の操作が一致しているか検査する"
  task verify: :environment do
    require "graphql"

    contract = GraphQL::Schema.from_definition(
      File.read(Rails.root.join("../packages/contract/schema.graphql"), encoding: "UTF-8")
    )

    problems = []

    { "Query" => [ contract.query, NikkakeSchema.query ],
      "Mutation" => [ contract.mutation, NikkakeSchema.mutation ] }.each do |label, (want, got)|
      want_fields = want.fields.keys.sort
      got_fields = got.fields.keys.sort

      (want_fields - got_fields).each { problems << "#{label}.#{_1} が実装に無い" }
      (got_fields - want_fields).each { problems << "#{label}.#{_1} が契約に無い" }
    end

    if problems.any?
      warn "契約と実装がズレています:\n  #{problems.join("\n  ")}"
      exit 1
    end

    puts "契約と実装は一致しています " \
         "(Query #{NikkakeSchema.query.fields.size}本 / Mutation #{NikkakeSchema.mutation.fields.size}本)"
  end
end
