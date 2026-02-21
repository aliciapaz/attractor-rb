# frozen_string_literal: true

require "spec_helper"

RSpec.describe Attractor::RetryExecutor do
  let(:event_emitter) { Attractor::EventEmitter.new }
  let(:registry) { Attractor::Handlers::HandlerRegistry.new }
  let(:context) { Attractor::Context.new }
  let(:graph) { Attractor::Graph.new("test", nodes: {}, edges: []) }
  let(:logs_root) { Dir.mktmpdir("attractor-retry-test") }

  subject(:executor) do
    described_class.new(handler_registry: registry, event_emitter: event_emitter)
  end

  after do
    FileUtils.rm_rf(logs_root)
  end

  def make_node(id, attrs = {})
    Attractor::Node.new(id, attrs)
  end

  def stub_handler(outcomes)
    handler = double("handler")
    call_count = 0
    allow(handler).to receive(:execute) do |_node, _ctx, _graph, _logs_root|
      result = outcomes[call_count] || outcomes.last
      call_count += 1
      result
    end
    handler
  end

  describe "#execute_with_retry" do
    it "returns success on first attempt when handler succeeds" do
      handler = stub_handler([
        Attractor::Outcome.new(status: Attractor::StageStatus::SUCCESS)
      ])
      registry.register("codergen", handler)
      node = make_node("A")
      policy = Attractor::RetryPolicy.new(max_attempts: 3, backoff: Attractor::Backoff.new(initial_delay_ms: 0, jitter: false))

      outcome = executor.execute_with_retry(node, context, graph, logs_root, policy)

      expect(outcome.success?).to be true
    end

    it "retries and succeeds within the limit" do
      handler = stub_handler([
        Attractor::Outcome.new(status: Attractor::StageStatus::FAIL, failure_reason: "transient"),
        Attractor::Outcome.new(status: Attractor::StageStatus::SUCCESS)
      ])
      registry.register("codergen", handler)
      node = make_node("A")
      policy = Attractor::RetryPolicy.new(max_attempts: 3, backoff: Attractor::Backoff.new(initial_delay_ms: 0, jitter: false))

      outcome = executor.execute_with_retry(node, context, graph, logs_root, policy)

      expect(outcome.success?).to be true
    end

    it "returns FAIL when retries are exhausted" do
      handler = stub_handler([
        Attractor::Outcome.new(status: Attractor::StageStatus::FAIL, failure_reason: "persistent error")
      ])
      registry.register("codergen", handler)
      node = make_node("A")
      policy = Attractor::RetryPolicy.new(max_attempts: 2, backoff: Attractor::Backoff.new(initial_delay_ms: 0, jitter: false))

      outcome = executor.execute_with_retry(node, context, graph, logs_root, policy)

      expect(outcome.status).to eq(Attractor::StageStatus::FAIL)
    end

    it "returns PARTIAL_SUCCESS when allow_partial is true and retries exhausted" do
      handler = stub_handler([
        Attractor::Outcome.new(status: Attractor::StageStatus::RETRY, failure_reason: "not quite")
      ])
      registry.register("codergen", handler)
      node = make_node("A", "allow_partial" => true)
      policy = Attractor::RetryPolicy.new(max_attempts: 2, backoff: Attractor::Backoff.new(initial_delay_ms: 0, jitter: false))

      outcome = executor.execute_with_retry(node, context, graph, logs_root, policy)

      expect(outcome.status).to eq(Attractor::StageStatus::PARTIAL_SUCCESS)
      expect(outcome.notes).to include("partial accepted")
    end

    it "returns SKIPPED immediately without retrying" do
      handler = stub_handler([
        Attractor::Outcome.new(status: Attractor::StageStatus::SKIPPED)
      ])
      registry.register("codergen", handler)
      node = make_node("A")
      policy = Attractor::RetryPolicy.new(max_attempts: 5, backoff: Attractor::Backoff.new(initial_delay_ms: 0, jitter: false))

      outcome = executor.execute_with_retry(node, context, graph, logs_root, policy)

      expect(outcome.status).to eq(Attractor::StageStatus::SKIPPED)
    end

    it "catches handler exceptions and converts to FAIL" do
      handler = double("handler")
      allow(handler).to receive(:execute).and_raise(RuntimeError, "unexpected crash")
      registry.register("codergen", handler)
      node = make_node("A")
      policy = Attractor::RetryPolicy.new(max_attempts: 1, backoff: Attractor::Backoff.new(initial_delay_ms: 0, jitter: false))

      outcome = executor.execute_with_retry(node, context, graph, logs_root, policy)

      expect(outcome.status).to eq(Attractor::StageStatus::FAIL)
      expect(outcome.failure_reason).to eq("unexpected crash")
    end

    it "emits StageRetrying events on retry" do
      events = []
      event_emitter.on_event { |e| events << e }

      handler = stub_handler([
        Attractor::Outcome.new(status: Attractor::StageStatus::FAIL, failure_reason: "err"),
        Attractor::Outcome.new(status: Attractor::StageStatus::SUCCESS)
      ])
      registry.register("codergen", handler)
      node = make_node("A")
      policy = Attractor::RetryPolicy.new(max_attempts: 3, backoff: Attractor::Backoff.new(initial_delay_ms: 0, jitter: false))

      executor.execute_with_retry(node, context, graph, logs_root, policy)

      retry_events = events.select { |e| e.is_a?(Attractor::Events::StageRetrying) }
      expect(retry_events.size).to eq(1)
      expect(retry_events.first.name).to eq("A")
    end
  end
end
