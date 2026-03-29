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
          context_updates: context_updates(node, prompt, response_text)
        )
        RunDirectory.write_status(logs_root, node.id, outcome)
        outcome
      end

      private

      def build_prompt(node, graph, context)
        prompt = node.prompt
        prompt = node.label if prompt.empty?
        task_prompt = expand_variables(prompt, graph, context)
        assemble_prompt(node, context, graph, task_prompt)
      end

      def assemble_prompt(node, context, graph, task_prompt)
        sections = []
        preamble = Transforms::Preamble.new.build_preamble(node, context, graph)
        sections << "## Context from prior stages\n#{preamble}" if preamble && !preamble.empty?

        file_listing = context.get("file_listing")
        sections << "## Current project files\n#{file_listing}" if file_listing && !file_listing.empty?

        sections << "## Current task\n#{task_prompt}"
        sections.join("\n\n")
      end

      def expand_variables(prompt, graph, _context)
        prompt.gsub("$goal", graph.goal)
      end

      def context_updates(node, prompt, response_text)
        {
          "last_stage" => node.id,
          "last_response" => truncate(response_text),
          "last_codergen_node" => node.id,
          "last_codergen_prompt_summary" => prompt[0, 500]
        }
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
