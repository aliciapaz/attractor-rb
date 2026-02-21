# frozen_string_literal: true

RSpec.describe Attractor::Dot::Parser do
  def parse(source)
    described_class.parse(source)
  end

  describe ".parse" do
    context "simple linear workflow" do
      let(:source) do
        <<~DOT
          digraph Simple {
              graph [goal="Run tests and report"]
              rankdir=LR

              start [shape=Mdiamond, label="Start"]
              exit  [shape=Msquare, label="Exit"]

              run_tests [label="Run Tests", prompt="Run the test suite and report results"]
              report    [label="Report", prompt="Summarize the test results"]

              start -> run_tests -> report -> exit
          }
        DOT
      end

      let(:graph) { parse(source) }

      it "parses successfully" do
        expect(graph).to be_a(Attractor::Graph)
      end

      it "extracts the graph name" do
        expect(graph.name).to eq("Simple")
      end

      it "extracts graph-level attributes" do
        expect(graph.goal).to eq("Run tests and report")
        expect(graph.attrs["rankdir"]).to eq("LR")
      end

      it "has the correct number of nodes" do
        expect(graph.nodes.size).to eq(4)
      end

      it "extracts node attributes" do
        start_node = graph.nodes["start"]
        expect(start_node.shape).to eq("Mdiamond")
        expect(start_node.label).to eq("Start")

        exit_node = graph.nodes["exit"]
        expect(exit_node.shape).to eq("Msquare")
        expect(exit_node.label).to eq("Exit")

        run_tests = graph.nodes["run_tests"]
        expect(run_tests.label).to eq("Run Tests")
        expect(run_tests.prompt).to eq("Run the test suite and report results")
      end

      it "expands chained edges correctly" do
        expect(graph.edges.size).to eq(3)

        edge_pairs = graph.edges.map { |e| [e.from, e.to] }
        expect(edge_pairs).to contain_exactly(
          ["start", "run_tests"],
          ["run_tests", "report"],
          ["report", "exit"]
        )
      end
    end

    context "branching workflow" do
      let(:source) do
        <<~DOT
          digraph Branch {
              graph [goal="Implement and validate a feature"]
              rankdir=LR
              node [shape=box, timeout="900s"]

              start     [shape=Mdiamond, label="Start"]
              exit      [shape=Msquare, label="Exit"]
              plan      [label="Plan", prompt="Plan the implementation"]
              implement [label="Implement", prompt="Implement the plan"]
              validate  [label="Validate", prompt="Run tests"]
              gate      [shape=diamond, label="Tests passing?"]

              start -> plan -> implement -> validate -> gate
              gate -> exit      [label="Yes", condition="outcome=success"]
              gate -> implement [label="No", condition="outcome!=success"]
          }
        DOT
      end

      let(:graph) { parse(source) }

      it "parses successfully" do
        expect(graph).to be_a(Attractor::Graph)
      end

      it "has the correct graph name" do
        expect(graph.name).to eq("Branch")
      end

      it "extracts graph attributes" do
        expect(graph.goal).to eq("Implement and validate a feature")
        expect(graph.attrs["rankdir"]).to eq("LR")
      end

      it "has the correct number of nodes" do
        expect(graph.nodes.size).to eq(6)
      end

      it "applies node defaults" do
        plan = graph.nodes["plan"]
        # "900s" is coerced to milliseconds by AttributeTypes
        expect(plan.attrs["timeout"]).to eq(900_000)
        expect(plan.shape).to eq("box")

        implement = graph.nodes["implement"]
        expect(implement.attrs["timeout"]).to eq(900_000)
      end

      it "lets explicit attributes override defaults" do
        start_node = graph.nodes["start"]
        expect(start_node.shape).to eq("Mdiamond")

        gate = graph.nodes["gate"]
        expect(gate.shape).to eq("diamond")
      end

      it "has the correct number of edges" do
        # 4 from chain + 2 individual = 6
        expect(graph.edges.size).to eq(6)
      end

      it "expands chained edges" do
        chain_edges = graph.edges.select { |e| e.label == "" }
        chain_pairs = chain_edges.map { |e| [e.from, e.to] }
        expect(chain_pairs).to contain_exactly(
          ["start", "plan"],
          ["plan", "implement"],
          ["implement", "validate"],
          ["validate", "gate"]
        )
      end

      it "captures edge attributes on conditional edges" do
        yes_edge = graph.edges.find { |e| e.label == "Yes" }
        expect(yes_edge).not_to be_nil
        expect(yes_edge.from).to eq("gate")
        expect(yes_edge.to).to eq("exit")
        expect(yes_edge.condition).to eq("outcome=success")

        no_edge = graph.edges.find { |e| e.label == "No" }
        expect(no_edge).not_to be_nil
        expect(no_edge.from).to eq("gate")
        expect(no_edge.to).to eq("implement")
        expect(no_edge.condition).to eq("outcome!=success")
      end
    end

    context "human gate workflow" do
      let(:source) do
        <<~DOT
          digraph Review {
              rankdir=LR

              start [shape=Mdiamond, label="Start"]
              exit  [shape=Msquare, label="Exit"]

              review_gate [
                  shape=hexagon,
                  label="Review Changes",
                  type="wait.human"
              ]

              start -> review_gate
              review_gate -> ship_it [label="[A] Approve"]
              review_gate -> fixes   [label="[F] Fix"]
              ship_it -> exit
              fixes -> review_gate
          }
        DOT
      end

      let(:graph) { parse(source) }

      it "parses successfully" do
        expect(graph).to be_a(Attractor::Graph)
      end

      it "has the correct graph name" do
        expect(graph.name).to eq("Review")
      end

      it "has the correct number of nodes" do
        # start, exit, review_gate, ship_it, fixes
        expect(graph.nodes.size).to eq(5)
      end

      it "extracts multi-line node attributes" do
        review = graph.nodes["review_gate"]
        expect(review.shape).to eq("hexagon")
        expect(review.label).to eq("Review Changes")
        expect(review.type).to eq("wait.human")
      end

      it "auto-creates nodes from edge references" do
        expect(graph.nodes).to have_key("ship_it")
        expect(graph.nodes).to have_key("fixes")
      end

      it "has the correct number of edges" do
        expect(graph.edges.size).to eq(5)
      end

      it "captures edge labels" do
        approve_edge = graph.edges.find { |e| e.label == "[A] Approve" }
        expect(approve_edge).not_to be_nil
        expect(approve_edge.from).to eq("review_gate")
        expect(approve_edge.to).to eq("ship_it")

        fix_edge = graph.edges.find { |e| e.label == "[F] Fix" }
        expect(fix_edge).not_to be_nil
        expect(fix_edge.from).to eq("review_gate")
        expect(fix_edge.to).to eq("fixes")
      end

      it "creates back-edge (cycle)" do
        back_edge = graph.edges.find { |e| e.from == "fixes" && e.to == "review_gate" }
        expect(back_edge).not_to be_nil
      end
    end

    context "chained edges with attributes" do
      let(:source) do
        <<~DOT
          digraph Chain {
              A -> B -> C [label="next"]
          }
        DOT
      end

      let(:graph) { parse(source) }

      it "creates an edge for each pair" do
        expect(graph.edges.size).to eq(2)
      end

      it "applies attributes to all edges in the chain" do
        graph.edges.each do |edge|
          expect(edge.label).to eq("next")
        end
      end

      it "creates edges in order" do
        expect(graph.edges[0].from).to eq("A")
        expect(graph.edges[0].to).to eq("B")
        expect(graph.edges[1].from).to eq("B")
        expect(graph.edges[1].to).to eq("C")
      end
    end

    context "node defaults" do
      let(:source) do
        <<~DOT
          digraph Defaults {
              node [shape=box, timeout="600s"]

              plain_node [label="Plain"]
              override_node [label="Override", shape=diamond]
          }
        DOT
      end

      let(:graph) { parse(source) }

      it "applies defaults to nodes without explicit overrides" do
        plain = graph.nodes["plain_node"]
        expect(plain.shape).to eq("box")
        expect(plain.attrs["timeout"]).to eq(600_000)
      end

      it "lets explicit attributes override defaults" do
        override = graph.nodes["override_node"]
        expect(override.shape).to eq("diamond")
        expect(override.attrs["timeout"]).to eq(600_000)
      end
    end

    context "edge defaults" do
      let(:source) do
        <<~DOT
          digraph EdgeDef {
              edge [weight=5]

              A -> B
              C -> D [weight=10]
          }
        DOT
      end

      let(:graph) { parse(source) }

      it "applies edge defaults" do
        ab_edge = graph.edges.find { |e| e.from == "A" && e.to == "B" }
        expect(ab_edge.attrs["weight"]).to eq(5)
      end

      it "lets explicit edge attributes override defaults" do
        cd_edge = graph.edges.find { |e| e.from == "C" && e.to == "D" }
        expect(cd_edge.attrs["weight"]).to eq(10)
      end
    end

    context "graph-level attributes" do
      let(:source) do
        <<~DOT
          digraph Attrs {
              graph [goal="Test goal"]
              rankdir=LR
              custom_key="custom_value"
          }
        DOT
      end

      let(:graph) { parse(source) }

      it "extracts graph block attributes" do
        expect(graph.goal).to eq("Test goal")
      end

      it "extracts top-level key=value as graph attrs" do
        expect(graph.attrs["rankdir"]).to eq("LR")
        expect(graph.attrs["custom_key"]).to eq("custom_value")
      end
    end

    context "qualified keys" do
      let(:source) do
        <<~DOT
          digraph QKey {
              A [style.color="red", config.retry.max=3]
          }
        DOT
      end

      let(:graph) { parse(source) }

      it "concatenates qualified keys with dots" do
        a = graph.nodes["A"]
        expect(a.attrs["style.color"]).to eq("red")
        expect(a.attrs["config.retry.max"]).to eq("3")
      end
    end

    context "subgraph flattening" do
      let(:source) do
        <<~DOT
          digraph Sub {
              start [shape=Mdiamond, label="Start"]

              subgraph cluster_loop {
                  label = "Loop A"
                  node [thread_id="loop-a", timeout="900s"]

                  Plan      [label="Plan next step"]
                  Implement [label="Implement", timeout="1800s"]

                  Plan -> Implement
              }

              start -> Plan
          }
        DOT
      end

      let(:graph) { parse(source) }

      it "flattens subgraph nodes into the parent graph" do
        expect(graph.nodes).to have_key("Plan")
        expect(graph.nodes).to have_key("Implement")
      end

      it "applies subgraph node defaults" do
        plan = graph.nodes["Plan"]
        expect(plan.attrs["thread_id"]).to eq("loop-a")
        expect(plan.attrs["timeout"]).to eq(900_000)
      end

      it "lets explicit attrs override subgraph defaults" do
        impl = graph.nodes["Implement"]
        expect(impl.attrs["timeout"]).to eq(1_800_000)
        expect(impl.attrs["thread_id"]).to eq("loop-a")
      end

      it "derives CSS class from subgraph label" do
        plan = graph.nodes["Plan"]
        expect(plan.attrs["class"]).to eq("loop-a")
      end

      it "flattens subgraph edges into the parent graph" do
        inner_edge = graph.edges.find { |e| e.from == "Plan" && e.to == "Implement" }
        expect(inner_edge).not_to be_nil
      end

      it "connects subgraph nodes to outer nodes" do
        outer_edge = graph.edges.find { |e| e.from == "start" && e.to == "Plan" }
        expect(outer_edge).not_to be_nil
      end

      it "restores node defaults after subgraph" do
        # Nodes declared after the subgraph should not have subgraph defaults
        # start was declared before, so it should not have thread_id
        start_node = graph.nodes["start"]
        expect(start_node.attrs).not_to have_key("thread_id")
      end
    end

    context "subgraph class derivation" do
      it "lowercases and replaces spaces with hyphens" do
        source = <<~DOT
          digraph CD {
              subgraph cluster_x {
                  label = "My Special Phase"
                  node [shape=box]
                  task_a [label="Task A"]
              }
          }
        DOT

        graph = parse(source)
        task = graph.nodes["task_a"]
        expect(task.attrs["class"]).to eq("my-special-phase")
      end

      it "strips non-alphanumeric characters except hyphens" do
        source = <<~DOT
          digraph CD2 {
              subgraph cluster_y {
                  label = "Phase #1 (test!)"
                  node [shape=box]
                  task_b [label="Task B"]
              }
          }
        DOT

        graph = parse(source)
        task = graph.nodes["task_b"]
        expect(task.attrs["class"]).to eq("phase-1-test")
      end
    end

    context "optional semicolons" do
      it "parses with semicolons" do
        source = <<~DOT
          digraph Semi {
              graph [goal="test"];
              A [label="A"];
              A -> B;
          }
        DOT

        graph = parse(source)
        expect(graph.nodes.size).to eq(2)
        expect(graph.edges.size).to eq(1)
      end

      it "parses without semicolons" do
        source = <<~DOT
          digraph NoSemi {
              graph [goal="test"]
              A [label="A"]
              A -> B
          }
        DOT

        graph = parse(source)
        expect(graph.nodes.size).to eq(2)
        expect(graph.edges.size).to eq(1)
      end
    end

    context "auto-creating nodes from edges" do
      let(:source) do
        <<~DOT
          digraph AutoNode {
              node [shape=box]
              A -> B -> C
          }
        DOT
      end

      let(:graph) { parse(source) }

      it "creates nodes that appear only in edge statements" do
        expect(graph.nodes).to have_key("A")
        expect(graph.nodes).to have_key("B")
        expect(graph.nodes).to have_key("C")
      end

      it "applies current node defaults to auto-created nodes" do
        expect(graph.nodes["A"].shape).to eq("box")
        expect(graph.nodes["B"].shape).to eq("box")
        expect(graph.nodes["C"].shape).to eq("box")
      end
    end

    context "value types" do
      let(:source) do
        <<~DOT
          digraph Types {
              A [
                  str="hello",
                  bare_id=box,
                  int_val=42,
                  float_val=3.14,
                  bool_val=true
              ]
          }
        DOT
      end

      let(:graph) { parse(source) }

      it "parses string values" do
        expect(graph.nodes["A"].attrs["str"]).to eq("hello")
      end

      it "parses bare identifier values" do
        expect(graph.nodes["A"].attrs["bare_id"]).to eq("box")
      end

      it "parses integer values (stored as string, coerced by AttributeTypes)" do
        # Only TYPED_KEYS are coerced; arbitrary attrs stay as strings
        expect(graph.nodes["A"].attrs["int_val"]).to eq("42")
      end

      it "parses float values" do
        expect(graph.nodes["A"].attrs["float_val"]).to eq("3.14")
      end

      it "parses boolean values" do
        expect(graph.nodes["A"].attrs["bool_val"]).to eq("true")
      end
    end

    context "comments are ignored" do
      let(:source) do
        <<~DOT
          digraph Comments {
              // This is a line comment
              A [label="Test"]
              /* This is a
                 block comment */
              A -> B
          }
        DOT
      end

      let(:graph) { parse(source) }

      it "parses despite comments" do
        expect(graph.nodes).to have_key("A")
        expect(graph.edges.size).to eq(1)
      end
    end

    context "error reporting" do
      it "raises ParseError with line and column for unexpected tokens" do
        source = <<~DOT
          digraph Bad {
              A [label = ]
          }
        DOT

        expect { parse(source) }.to raise_error(Attractor::Dot::ParseError) do |error|
          expect(error.line).to be_a(Integer)
          expect(error.column).to be_a(Integer)
        end
      end

      it "raises ParseError for missing digraph keyword" do
        expect { parse("graph G { }") }.to raise_error(
          Attractor::Dot::ParseError,
          /Expected DIGRAPH/
        )
      end

      it "raises ParseError for undirected edges" do
        source = "digraph G { A -- B }"
        expect { parse(source) }.to raise_error(
          Attractor::Dot::ParseError,
          /Undirected edges/
        )
      end

      it "raises ParseError for missing closing brace" do
        source = "digraph G { A -> B"
        expect { parse(source) }.to raise_error(Attractor::Dot::ParseError)
      end

      it "includes the source line in the error" do
        source = "digraph G {\n  A [label = ]\n}"
        begin
          parse(source)
          raise "Expected ParseError"
        rescue Attractor::Dot::ParseError => e
          expect(e.message).to include("A [label = ]")
        end
      end
    end

    context "empty graph" do
      it "parses an empty digraph" do
        graph = parse("digraph Empty { }")
        expect(graph.name).to eq("Empty")
        expect(graph.nodes).to be_empty
        expect(graph.edges).to be_empty
      end
    end

    context "bare node statement" do
      it "creates a node with no explicit attributes" do
        graph = parse("digraph B { my_node }")
        expect(graph.nodes).to have_key("my_node")
      end
    end

    context "multiple node default blocks" do
      let(:source) do
        <<~DOT
          digraph Multi {
              node [shape=box]
              A [label="First"]

              node [shape=diamond]
              B [label="Second"]
          }
        DOT
      end

      let(:graph) { parse(source) }

      it "applies the latest defaults" do
        expect(graph.nodes["A"].shape).to eq("box")
        expect(graph.nodes["B"].shape).to eq("diamond")
      end
    end
  end
end
