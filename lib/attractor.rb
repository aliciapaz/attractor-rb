# frozen_string_literal: true

require "json"
require "fileutils"
require "open3"
require "timeout"

require_relative "attractor/version"

module Attractor
  class Error < StandardError; end
  class ValidationError < Error; end
end

# DOT Parsing
require_relative "attractor/dot/parse_error"
require_relative "attractor/dot/lexer"
require_relative "attractor/dot/parser"

# Graph Model
require_relative "attractor/attribute_types"
require_relative "attractor/node"
require_relative "attractor/edge"
require_relative "attractor/graph"

# State
require_relative "attractor/stage_status"
require_relative "attractor/outcome"
require_relative "attractor/context"
require_relative "attractor/checkpoint"
require_relative "attractor/artifact_store"
require_relative "attractor/fidelity"
require_relative "attractor/run_directory"

# Validation
require_relative "attractor/diagnostic"
require_relative "attractor/lint_rules/base_rule"
require_relative "attractor/lint_rules/start_node_rule"
require_relative "attractor/lint_rules/terminal_node_rule"
require_relative "attractor/lint_rules/reachability_rule"
require_relative "attractor/lint_rules/edge_target_exists_rule"
require_relative "attractor/lint_rules/start_no_incoming_rule"
require_relative "attractor/lint_rules/exit_no_outgoing_rule"
require_relative "attractor/lint_rules/condition_syntax_rule"
require_relative "attractor/lint_rules/stylesheet_syntax_rule"
require_relative "attractor/lint_rules/type_known_rule"
require_relative "attractor/lint_rules/fidelity_valid_rule"
require_relative "attractor/lint_rules/retry_target_exists_rule"
require_relative "attractor/lint_rules/goal_gate_has_retry_rule"
require_relative "attractor/lint_rules/prompt_on_llm_nodes_rule"
require_relative "attractor/validator"

# Condition Language
require_relative "attractor/condition/parser"
require_relative "attractor/condition/evaluator"

# Model Stylesheet
require_relative "attractor/stylesheet/rule"
require_relative "attractor/stylesheet/parser"
require_relative "attractor/stylesheet/applicator"

# Transforms
require_relative "attractor/transforms/base_transform"
require_relative "attractor/transforms/variable_expansion"
require_relative "attractor/transforms/stylesheet_application"
require_relative "attractor/transforms/preamble"

# Human-in-the-Loop
require_relative "attractor/question"
require_relative "attractor/answer"
require_relative "attractor/interviewer/base"
require_relative "attractor/interviewer/console"
require_relative "attractor/interviewer/auto_approve"
require_relative "attractor/interviewer/callback"
require_relative "attractor/interviewer/queue"
require_relative "attractor/interviewer/recording"

# Process Management
require_relative "attractor/process_helper"

# Handlers
require_relative "attractor/handlers/base_handler"
require_relative "attractor/handlers/handler_registry"
require_relative "attractor/handlers/start_handler"
require_relative "attractor/handlers/exit_handler"
require_relative "attractor/handlers/codergen_handler"
require_relative "attractor/handlers/wait_human_handler"
require_relative "attractor/handlers/conditional_handler"
require_relative "attractor/handlers/parallel_handler"
require_relative "attractor/handlers/fan_in_handler"
require_relative "attractor/handlers/tool_handler"
require_relative "attractor/handlers/manager_loop_handler"

# Backends
require_relative "attractor/codergen_backend"
require_relative "attractor/backends/claude_code_backend"
require_relative "attractor/backends/codex_backend"
require_relative "attractor/backends/simulation_backend"

# Execution Engine
require_relative "attractor/backoff"
require_relative "attractor/retry_policy"
require_relative "attractor/retry_executor"
require_relative "attractor/edge_selector"
require_relative "attractor/goal_gate_checker"
require_relative "attractor/events"
require_relative "attractor/event_emitter"
require_relative "attractor/engine"

# CLI
require_relative "attractor/cli"
