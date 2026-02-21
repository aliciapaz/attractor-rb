# frozen_string_literal: true

module Attractor
  module Handlers
    class ParallelHandler < BaseHandler
      def initialize(handler_registry: nil)
        @handler_registry = handler_registry
      end

      def execute(node, context, graph, logs_root)
        branches = graph.outgoing_edges(node.id)

        if branches.empty?
          return Outcome.new(
            status: StageStatus::SUCCESS,
            notes: "No branches to execute"
          )
        end

        join_policy = node.attrs.fetch("join_policy", "wait_all")
        max_parallel = node.attrs.fetch("max_parallel", 4).to_i

        results = execute_branches(branches, context, graph, logs_root, max_parallel)

        outcome = evaluate_join_policy(join_policy, results)
        serialized = serialize_results(results)
        context.set("parallel.results", serialized)

        Outcome.new(
          status: outcome[:status],
          notes: outcome[:notes],
          context_updates: {"parallel.results" => serialized}
        )
      end

      private

      def execute_branches(branches, context, graph, logs_root, max_parallel)
        pool = Concurrent::FixedThreadPool.new(max_parallel)
        futures = []

        branches.each do |edge|
          target_node = graph.nodes[edge.to]
          next unless target_node

          branch_context = context.clone
          future = Concurrent::Future.execute(executor: pool) do
            execute_branch(target_node, branch_context, graph, logs_root)
          end
          futures << {node_id: edge.to, future: future}
        end

        futures.map do |entry|
          outcome = entry[:future].value # blocks until complete
          outcome ||= Outcome.new(status: StageStatus::FAIL, failure_reason: entry[:future].reason&.message || "unknown error")
          {node_id: entry[:node_id], outcome: outcome}
        end
      ensure
        pool&.shutdown
        pool&.wait_for_termination(30)
      end

      def execute_branch(target_node, branch_context, graph, logs_root)
        unless @handler_registry
          return Outcome.new(status: StageStatus::FAIL, failure_reason: "No handler registry")
        end

        handler = @handler_registry.resolve(target_node)
        unless handler
          return Outcome.new(status: StageStatus::FAIL, failure_reason: "No handler for node: #{target_node.id}")
        end

        handler.execute(target_node, branch_context, graph, logs_root)
      rescue => e
        Outcome.new(status: StageStatus::FAIL, failure_reason: e.message)
      end

      def evaluate_join_policy(policy, results)
        success_count = results.count { |r| r[:outcome].status == StageStatus::SUCCESS }
        fail_count = results.count { |r| r[:outcome].status == StageStatus::FAIL }

        case policy
        when "wait_all"
          if fail_count == 0
            {status: StageStatus::SUCCESS, notes: "All #{results.size} branches succeeded"}
          else
            {status: StageStatus::PARTIAL_SUCCESS, notes: "#{success_count}/#{results.size} branches succeeded"}
          end
        when "first_success"
          if success_count > 0
            {status: StageStatus::SUCCESS, notes: "At least one branch succeeded"}
          else
            {status: StageStatus::FAIL, notes: "No branches succeeded"}
          end
        else
          {status: StageStatus::SUCCESS, notes: "Branches completed with policy: #{policy}"}
        end
      end

      def serialize_results(results)
        results.map do |r|
          {
            "node_id" => r[:node_id],
            "status" => r[:outcome].status,
            "notes" => r[:outcome].notes,
            "failure_reason" => r[:outcome].failure_reason
          }
        end
      end
    end
  end
end
