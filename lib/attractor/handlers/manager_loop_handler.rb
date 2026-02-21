# frozen_string_literal: true

module Attractor
  module Handlers
    class ManagerLoopHandler < BaseHandler
      DEFAULT_POLL_INTERVAL = 45
      DEFAULT_MAX_CYCLES = 1000

      def execute(node, context, graph, _logs_root)
        poll_interval = parse_poll_interval(node)
        max_cycles = node.attrs.fetch("manager.max_cycles", DEFAULT_MAX_CYCLES).to_i
        stop_condition = node.attrs.fetch("manager.stop_condition", "")

        (1..max_cycles).each do |cycle|
          child_status = context.get_string("context.stack.child.status")

          if child_status == "completed"
            child_outcome = context.get_string("context.stack.child.outcome")
            if child_outcome == "success"
              return Outcome.new(
                status: StageStatus::SUCCESS,
                notes: "Child completed successfully at cycle #{cycle}",
                context_updates: {"manager.cycles_completed" => cycle}
              )
            end
          end

          if child_status == "failed"
            return Outcome.new(
              status: StageStatus::FAIL,
              failure_reason: "Child failed at cycle #{cycle}",
              context_updates: {"manager.cycles_completed" => cycle}
            )
          end

          if !stop_condition.empty? && evaluate_stop_condition(stop_condition, context)
            return Outcome.new(
              status: StageStatus::SUCCESS,
              notes: "Stop condition satisfied at cycle #{cycle}",
              context_updates: {"manager.cycles_completed" => cycle}
            )
          end

          sleep(poll_interval) if poll_interval > 0
        end

        Outcome.new(
          status: StageStatus::FAIL,
          failure_reason: "Max cycles (#{max_cycles}) exceeded",
          context_updates: {"manager.cycles_completed" => max_cycles}
        )
      end

      private

      def parse_poll_interval(node)
        raw = node.attrs.fetch("manager.poll_interval", nil)
        return DEFAULT_POLL_INTERVAL if raw.nil?

        return DEFAULT_POLL_INTERVAL unless raw.is_a?(Numeric)

        # AttributeTypes coerces duration strings to milliseconds.
        # Convert to seconds for sleep.
        raw / 1000.0
      end

      def evaluate_stop_condition(condition, context)
        # Simple key=value condition evaluation
        match = condition.match(/\A(\S+)\s*=\s*"?([^"]*)"?\z/)
        return false unless match

        key = match[1]
        expected = match[2]
        context.get_string(key) == expected
      end
    end
  end
end
