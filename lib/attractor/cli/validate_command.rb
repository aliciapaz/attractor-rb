# frozen_string_literal: true

module Attractor
  module Cli
    class ValidateCommand
      def initialize(dotfile)
        @dotfile = dotfile
      end

      def execute
        source = read_dotfile

        graph = Dot::Parser.parse(source)

        transforms = [
          Transforms::VariableExpansion.new,
          Transforms::StylesheetApplication.new
        ]
        transforms.each { |t| graph = t.apply(graph) }

        validator = Validator.new
        diagnostics = validator.validate(graph)

        if diagnostics.empty?
          $stdout.puts "Validation passed: no issues found."
          return
        end

        errors = diagnostics.select(&:error?)
        warnings = diagnostics.select(&:warning?)
        infos = diagnostics.select(&:info?)

        if errors.any?
          warn "Errors (#{errors.size}):"
          errors.each { |d| warn "  [ERROR] #{d.message}" }
        end

        if warnings.any?
          $stdout.puts "Warnings (#{warnings.size}):"
          warnings.each { |d| $stdout.puts "  [WARN]  #{d.message}" }
        end

        if infos.any?
          $stdout.puts "Info (#{infos.size}):"
          infos.each { |d| $stdout.puts "  [INFO]  #{d.message}" }
        end

        if errors.any?
          warn "Validation failed with #{errors.size} error(s)."
          exit 1
        else
          $stdout.puts "Validation passed with #{warnings.size + infos.size} diagnostic(s)."
        end
      rescue Dot::ParseError => e
        warn "Parse error: #{e.message}"
        exit 1
      rescue Error => e
        warn "Error: #{e.message}"
        exit 1
      end

      private

      def read_dotfile
        unless File.exist?(@dotfile)
          raise Error, "DOT file not found: #{@dotfile}"
        end

        File.read(@dotfile)
      end
    end
  end
end
