# frozen_string_literal: true

FactoryBot.define do
  factory :node, class: "Attractor::Node" do
    transient do
      id { "node_1" }
      attrs { {} }
    end

    initialize_with { new(id, attrs) }

    trait :start do
      id { "start" }
      attrs { {"shape" => "Mdiamond", "label" => "Start"} }
    end

    trait :exit do
      id { "exit" }
      attrs { {"shape" => "Msquare", "label" => "Exit"} }
    end

    trait :codergen do
      attrs { {"shape" => "box", "prompt" => "Do something"} }
    end

    trait :human_gate do
      attrs { {"shape" => "hexagon", "type" => "wait.human", "label" => "Review"} }
    end

    trait :conditional do
      attrs { {"shape" => "diamond", "label" => "Check"} }
    end

    trait :parallel do
      attrs { {"shape" => "component", "label" => "Parallel"} }
    end

    trait :fan_in do
      attrs { {"shape" => "tripleoctagon", "label" => "Fan In"} }
    end

    trait :tool do
      attrs { {"shape" => "parallelogram", "tool_command" => "echo hello"} }
    end

    trait :goal_gate do
      attrs { {"shape" => "box", "goal_gate" => true, "prompt" => "Critical task"} }
    end
  end

  factory :edge, class: "Attractor::Edge" do
    transient do
      from { "a" }
      to { "b" }
      attrs { {} }
    end

    initialize_with { new(from, to, attrs) }

    trait :conditional do
      attrs { {"condition" => "outcome=success"} }
    end

    trait :labeled do
      attrs { {"label" => "Next"} }
    end

    trait :weighted do
      attrs { {"weight" => 10} }
    end
  end

  factory :graph, class: "Attractor::Graph" do
    transient do
      name { "TestPipeline" }
      nodes { {} }
      edges { [] }
      attrs { {} }
    end

    initialize_with { new(name, nodes: nodes, edges: edges, attrs: attrs) }

    trait :minimal do
      transient do
        nodes do
          {
            "start" => Attractor::Node.new("start", "shape" => "Mdiamond", "label" => "Start"),
            "exit" => Attractor::Node.new("exit", "shape" => "Msquare", "label" => "Exit")
          }
        end
        edges { [Attractor::Edge.new("start", "exit")] }
      end
    end

    trait :linear do
      transient do
        nodes do
          {
            "start" => Attractor::Node.new("start", "shape" => "Mdiamond", "label" => "Start"),
            "step_a" => Attractor::Node.new("step_a", "shape" => "box", "prompt" => "Do A"),
            "step_b" => Attractor::Node.new("step_b", "shape" => "box", "prompt" => "Do B"),
            "exit" => Attractor::Node.new("exit", "shape" => "Msquare", "label" => "Exit")
          }
        end
        edges do
          [
            Attractor::Edge.new("start", "step_a"),
            Attractor::Edge.new("step_a", "step_b"),
            Attractor::Edge.new("step_b", "exit")
          ]
        end
      end
    end

    trait :branching do
      transient do
        nodes do
          {
            "start" => Attractor::Node.new("start", "shape" => "Mdiamond"),
            "work" => Attractor::Node.new("work", "shape" => "box", "prompt" => "Do work"),
            "gate" => Attractor::Node.new("gate", "shape" => "diamond"),
            "exit" => Attractor::Node.new("exit", "shape" => "Msquare")
          }
        end
        edges do
          [
            Attractor::Edge.new("start", "work"),
            Attractor::Edge.new("work", "gate"),
            Attractor::Edge.new("gate", "exit", "condition" => "outcome=success"),
            Attractor::Edge.new("gate", "work", "condition" => "outcome!=success")
          ]
        end
      end
    end

    trait :with_goal do
      attrs { {"goal" => "Test the pipeline"} }
    end
  end
end
