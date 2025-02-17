# frozen_string_literal: true

module Mjml
  class Parser
    class ParseError < StandardError; end

    attr_reader :input

    # Create new parser
    #
    # @param input [String] The string to transform in html
    def initialize(input)
      raise Mjml.mjml_binary_error_string unless Mjml.valid_mjml_binary

      @input = input
    end

    # Render mjml template
    #
    # @return [String]
    def render
      input.gsub!(/<!--mj-raw$.*?^mj-raw-->/m, "") # Prevent injection
      input.gsub!(/<mj-raw>(.*?)<\/mj-raw>/m, "<!--mj-raw\n\\+\nmj-raw-->")

      in_tmp_file = Tempfile.open(['in', '.mjml']) do |file|
        file.write(input)
        file # return tempfile from block so #unlink works later
      end

      output = run(in_tmp_file.path, Mjml.beautify, Mjml.minify, Mjml.validation_level)
      output.gsub(/<!--mj-raw$(.*?)^mj-raw-->/m, "\\+")
    rescue StandardError
      raise if Mjml.raise_render_exception

      ''
    ensure
      in_tmp_file&.unlink
    end

    # Exec mjml command
    #
    # @return [String] The result as string
    # rubocop:disable Style/OptionalBooleanParameter: Fixing this offense would imply a change in the public API.
    def run(in_tmp_file, beautify = true, minify = false, validation_level = 'strict')
      command = "#{in_tmp_file} render"
      stdout, stderr, status = Mjml.run_mjml(command)

      unless status.success?
        # The process status ist quite helpful in case of dying processes without STDERR output.
        # Node exit codes are documented here: https://node.readthedocs.io/en/latest/api/process/#exit-codes
        raise ParseError, "#{stderr.chomp}\n(process status: #{status})"
      end

      Mjml.logger.warn(stderr.chomp) if stderr.present?
      stdout
    end
    # rubocop:enable Style/OptionalBooleanParameter
  end
end
