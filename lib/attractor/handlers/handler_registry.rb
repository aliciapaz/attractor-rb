# frozen_string_literal: true

module Attractor
  module Handlers
    class HandlerRegistry
      SHAPE_TO_TYPE = {
        "Mdiamond" => "start",
        "Msquare" => "exit",
        "box" => "codergen",
        "hexagon" => "wait.human",
        "diamond" => "conditional",
        "component" => "parallel",
        "tripleoctagon" => "parallel.fan_in",
        "parallelogram" => "tool",
        "house" => "stack.manager_loop"
      }.freeze

      attr_reader :default_handler

      def initialize(default_handler: nil)
        @handlers = {}
        @default_handler = default_handler
      end

      def register(type_string, handler)
        @handlers[type_string] = handler
      end

      def resolve(node)
        # 1. Explicit type attribute
        if !node.type.empty? && @handlers.key?(node.type)
          return @handlers[node.type]
        end

        # 2. Shape-based resolution
        handler_type = SHAPE_TO_TYPE[node.shape]
        if handler_type && @handlers.key?(handler_type)
          return @handlers[handler_type]
        end

        # 3. Default handler
        @default_handler
      end
    end
  end
end
