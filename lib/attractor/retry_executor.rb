# frozen_string_literal: true

module Attractor
  class RetryExecutor
    def initialize(handler_registry:, event_emitter: nil)
      @handler_registry = handler_registry
      @event_emitter = event_emitter
    end

    def execute_with_retry(node, context, graph, logs_root, retry_policy)
      handler = @handler_registry.resolve(node)

      (1..retry_policy.max_attempts).each do |attempt|
        outcome = safe_execute(handler, node, context, graph, logs_root)

        return outcome if outcome.success?
        return outcome if outcome.status == StageStatus::SKIPPED

        if attempt < retry_policy.max_attempts && retryable_status?(outcome)
          delay = retry_policy.backoff.delay_for_attempt(attempt)
          sleep(delay / 1000.0) if delay > 0
          @event_emitter&.emit(Events::StageRetrying.new(
            name: node.id,
            index: 0,
            attempt: attempt,
            delay: delay
          ))
          next
        end

        if attempt == retry_policy.max_attempts
          if node.allow_partial
            return Outcome.new(
              status: StageStatus::PARTIAL_SUCCESS,
              notes: "retries exhausted, partial accepted"
            )
          end

          return outcome
        end

        return outcome
      end
    end

    private

    def safe_execute(handler, node, context, graph, logs_root)
      handler.execute(node, context, graph, logs_root)
    rescue => e
      Outcome.new(status: StageStatus::FAIL, failure_reason: e.message)
    end

    def retryable_status?(outcome)
      outcome.status == StageStatus::RETRY || outcome.status == StageStatus::FAIL
    end
  end
end
