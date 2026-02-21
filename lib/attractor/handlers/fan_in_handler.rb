# frozen_string_literal: true

module Attractor
  module Handlers
    class FanInHandler < BaseHandler
      OUTCOME_RANK = {
        StageStatus::SUCCESS => 0,
        StageStatus::PARTIAL_SUCCESS => 1,
        StageStatus::RETRY => 2,
        StageStatus::FAIL => 3
      }.freeze

      def execute(node, context, _graph, _logs_root)
        results = context.get("parallel.results")

        if results.nil? || (results.respond_to?(:empty?) && results.empty?)
          return Outcome.new(
            status: StageStatus::FAIL,
            failure_reason: "No parallel results to evaluate"
          )
        end

        best = heuristic_select(results)

        if best.nil?
          return Outcome.new(
            status: StageStatus::FAIL,
            failure_reason: "All parallel candidates failed"
          )
        end

        Outcome.new(
          status: StageStatus::SUCCESS,
          context_updates: {
            "parallel.fan_in.best_id" => best["node_id"],
            "parallel.fan_in.best_outcome" => best["status"]
          },
          notes: "Selected best candidate: #{best["node_id"]}"
        )
      end

      private

      def heuristic_select(results)
        sorted = results.sort_by do |r|
          rank = OUTCOME_RANK.fetch(r["status"], 3)
          node_id = r["node_id"].to_s
          [rank, node_id]
        end

        sorted.first
      end
    end
  end
end
