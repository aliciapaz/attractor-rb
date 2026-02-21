# frozen_string_literal: true

module Attractor
  module Transforms
    class StylesheetApplication < BaseTransform
      def apply(graph)
        Stylesheet::Applicator.new.apply(graph)
      end
    end
  end
end
