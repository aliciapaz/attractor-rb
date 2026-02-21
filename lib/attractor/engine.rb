# frozen_string_literal: true

module Attractor
  class Engine
    attr_reader :event_emitter

    def initialize(
      backend: nil,
      interviewer: nil,
      event_emitter: nil,
      transforms: [],
      extra_rules: []
    )
      @backend = backend
      @interviewer = interviewer || Interviewer::AutoApprove.new
      @event_emitter = event_emitter || EventEmitter.new
      @transforms = transforms
      @extra_rules = extra_rules
      @handler_registry = build_registry
      @edge_selector = EdgeSelector.new
      @goal_gate_checker = GoalGateChecker.new
      @validator = Validator.new
      @retry_executor = RetryExecutor.new(
        handler_registry: @handler_registry,
        event_emitter: @event_emitter
      )
    end

    def run(source_or_graph, logs_root:, resume: false)
      # Phase 1: Parse
      graph = parse_graph(source_or_graph)

      # Phase 2: Transform
      graph = apply_transforms(graph)

      # Phase 3: Validate
      @validator.validate_or_raise(graph, extra_rules: @extra_rules)

      execute_loop(graph, source_or_graph, logs_root, resume)
    end

    private

    def execute_loop(graph, source_or_graph, logs_root, resume)
      loop do
        result = execute_once(graph, logs_root, resume)
        return result unless result == :restart

        # Re-parse and re-transform for a clean restart
        graph = parse_graph(source_or_graph)
        graph = apply_transforms(graph)
        resume = false
      end
    end

    def execute_once(graph, logs_root, resume)
      context, completed_nodes, node_outcomes, node_retries = initialize_run(graph, logs_root, resume)
      @event_emitter.emit(Events::PipelineStarted.new(name: graph.name, id: logs_root))
      start_time = Time.now
      current_node = determine_start(graph, completed_nodes, resume)
      last_outcome = nil
      stage_index = completed_nodes.size

      loop do
        node = fetch_node!(graph, current_node)

        if node.exit?
          last_outcome = run_exit_node(node, context, graph, logs_root, node_outcomes)
          redirect = check_goal_gates(graph, node_outcomes)
          if redirect
            current_node = redirect
            next
          end
          completed_nodes << node.id
          break
        end

        last_outcome = run_and_record_stage(
          node, context, graph, logs_root, completed_nodes, node_outcomes, node_retries, stage_index
        )
        stage_index += 1

        result = advance_pipeline(node, last_outcome, context, graph)
        return :restart if result == :restart
        break unless result
        current_node = result
      end

      finalize_run(logs_root, start_time, completed_nodes, node_retries, context, node_outcomes)
      last_outcome
    end

    def fetch_node!(graph, node_id)
      graph.nodes.fetch(node_id) { raise Error, "Node '#{node_id}' not found in graph" }
    end

    def resolve_handler!(node)
      handler = @handler_registry.resolve(node)
      raise Error, "No handler for node '#{node.id}' (type=#{node.type}, shape=#{node.shape})" unless handler
      handler
    end

    def run_exit_node(node, context, graph, logs_root, node_outcomes)
      handler = resolve_handler!(node)
      outcome = handler.execute(node, context, graph, logs_root)
      RunDirectory.write_status(logs_root, node.id, outcome)
      node_outcomes[node.id] = outcome
      outcome
    end

    def check_goal_gates(graph, node_outcomes)
      ok, failed_gate = @goal_gate_checker.check(graph, node_outcomes)
      return nil if ok

      target = @goal_gate_checker.retry_target(failed_gate, graph)
      return target if target && graph.nodes.key?(target)

      raise Error, "Goal gate '#{failed_gate.id}' unsatisfied and no retry target"
    end

    def run_and_record_stage(node, context, graph, logs_root, completed_nodes, node_outcomes, node_retries, stage_index)
      context.set("current_node", node.id)
      @event_emitter.emit(Events::StageStarted.new(name: node.id, index: stage_index))
      stage_start = Time.now

      outcome = execute_node_with_retry(node, context, graph, logs_root)
      RunDirectory.write_status(logs_root, node.id, outcome)
      record_stage_completion(node, outcome, completed_nodes, node_outcomes, stage_index, stage_start)
      apply_stage_outcome(outcome, context)
      save_checkpoint(logs_root, node.id, completed_nodes, node_retries, context, node_outcomes)
      outcome
    end

    def execute_node_with_retry(node, context, graph, logs_root)
      retry_policy = RetryPolicy.for_node(node, graph)
      @retry_executor.execute_with_retry(node, context, graph, logs_root, retry_policy)
    end

    def record_stage_completion(node, outcome, completed_nodes, node_outcomes, stage_index, stage_start)
      completed_nodes << node.id
      node_outcomes[node.id] = outcome
      emit_stage_event(node, outcome, stage_index, Time.now - stage_start)
    end

    def emit_stage_event(node, outcome, stage_index, duration)
      if outcome.success?
        @event_emitter.emit(Events::StageCompleted.new(name: node.id, index: stage_index, duration: duration))
      else
        @event_emitter.emit(Events::StageFailed.new(
          name: node.id, index: stage_index, error: outcome.failure_reason, will_retry: false
        ))
      end
    end

    def apply_stage_outcome(outcome, context)
      context.apply_updates(outcome.context_updates)
      context.set("outcome", outcome.status)
      return unless outcome.preferred_label && !outcome.preferred_label.empty?
      context.set("preferred_label", outcome.preferred_label)
    end

    def advance_pipeline(node, outcome, context, graph)
      next_edge = @edge_selector.select(node, outcome, context, graph)
      unless next_edge
        return nil if outcome.success?
        raise Error, "Stage '#{node.id}' failed with no outgoing edge"
      end
      return :restart if next_edge.loop_restart
      next_edge.to
    end

    def finalize_run(logs_root, start_time, completed_nodes, node_retries, context, node_outcomes)
      duration = Time.now - start_time
      save_checkpoint(logs_root, completed_nodes.last, completed_nodes, node_retries, context, node_outcomes)
      @event_emitter.emit(Events::PipelineCompleted.new(duration: duration, artifact_count: 0))
    end

    def parse_graph(source_or_graph)
      return source_or_graph if source_or_graph.is_a?(Graph)

      Dot::Parser.parse(source_or_graph)
    end

    def apply_transforms(graph)
      all_transforms = default_transforms + @transforms
      all_transforms.reduce(graph) { |g, t| t.apply(g) }
    end

    def default_transforms
      [
        Transforms::VariableExpansion.new,
        Transforms::StylesheetApplication.new
      ]
    end

    def initialize_run(graph, logs_root, resume)
      FileUtils.mkdir_p(logs_root)

      if resume && Checkpoint.exists?(logs_root)
        cp = Checkpoint.load(Checkpoint.checkpoint_path(logs_root))
        context = Context.new(values: cp.context_values, logs: cp.logs)
        [context, cp.completed_nodes.dup, rebuild_outcomes(cp), cp.node_retries.dup]
      else
        context = Context.new
        mirror_graph_attrs(graph, context)
        RunDirectory.write_manifest(logs_root, graph)
        [context, [], {}, {}]
      end
    end

    def mirror_graph_attrs(graph, context)
      context.set("graph.goal", graph.goal)
    end

    def determine_start(graph, completed_nodes, resume)
      if resume && completed_nodes.any?
        last = completed_nodes.last
        edges = graph.outgoing_edges(last)
        return edges.first.to if edges.any?
      end

      start = graph.start_node
      raise Error, "No start node found" unless start

      start.id
    end

    def rebuild_outcomes(checkpoint)
      outcomes = {}
      checkpoint.completed_nodes.each do |nid|
        status = checkpoint.node_statuses.fetch(nid, StageStatus::SUCCESS)
        outcomes[nid] = Outcome.new(status: status)
      end
      outcomes
    end

    def save_checkpoint(logs_root, current_node, completed_nodes, node_retries, context, node_outcomes = {})
      cp = Checkpoint.new(
        current_node: current_node,
        completed_nodes: completed_nodes.dup,
        node_retries: node_retries.dup,
        context_values: context.snapshot,
        logs: context.logs,
        node_statuses: node_outcomes.transform_values(&:status)
      )
      cp.save(Checkpoint.checkpoint_path(logs_root))
      @event_emitter.emit(Events::CheckpointSaved.new(node_id: current_node))
    end

    def build_registry
      registry = Handlers::HandlerRegistry.new
      registry.register("start", Handlers::StartHandler.new)
      registry.register("exit", Handlers::ExitHandler.new)
      registry.register("codergen", Handlers::CodergenHandler.new(backend: @backend))
      registry.register("wait.human", Handlers::WaitHumanHandler.new(interviewer: @interviewer))
      registry.register("conditional", Handlers::ConditionalHandler.new)
      parallel = Handlers::ParallelHandler.new(handler_registry: registry)
      registry.register("parallel", parallel)
      registry.register("parallel.fan_in", Handlers::FanInHandler.new)
      registry.register("tool", Handlers::ToolHandler.new)
      registry.register("stack.manager_loop", Handlers::ManagerLoopHandler.new)
      registry
    end
  end
end
