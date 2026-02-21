# frozen_string_literal: true

module Attractor
  module Handlers
    class CodergenHandler < BaseHandler
      RESPONSE_TRUNCATION_LENGTH = 200

      def initialize(backend: nil)
        @backend = backend
      end

      def execute(node, context, graph, logs_root)
        prompt = build_prompt(node, graph, context)
        RunDirectory.write_prompt(logs_root, node.id, prompt)

        response_text = begin
          call_backend(node, prompt, context)
        rescue => e
          return Outcome.new(
            status: StageStatus::FAIL,
            failure_reason: "Backend error: #{e.message}"
          )
        end

        RunDirectory.write_response(logs_root, node.id, response_text)

        outcome = Outcome.new(
          status: StageStatus::SUCCESS,
          notes: "Stage completed: #{node.id}",
          context_updates: {
            "last_stage" => node.id,
            "last_response" => truncate(response_text)
          }
        )
        RunDirectory.write_status(logs_root, node.id, outcome)
        outcome
      end

      private

      def build_prompt(node, graph, context)
        prompt = node.prompt
        prompt = node.label if prompt.empty?
        expand_variables(prompt, graph, context)
      end

      def expand_variables(prompt, graph, _context)
        prompt.gsub("$goal", graph.goal)
      end

      def call_backend(node, prompt, context)
        if @backend
          @backend.run(node, prompt, context).to_s
        else
          "[Simulated] Response for stage: #{node.id}"
        end
      end

      def truncate(text)
        return text if text.length <= RESPONSE_TRUNCATION_LENGTH

        text[0, RESPONSE_TRUNCATION_LENGTH]
      end
    end
  end
end
