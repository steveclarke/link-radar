# frozen_string_literal: true

# rubocop:disable Rails/Output, Rails/Exit

require "fileutils"
require "optparse"
require_relative "env"
require_relative "setup"

module Dev
  module Tooling
    # Development server orchestration
    #
    # Orchestrates starting the Rails development server with proper setup:
    # - Validates that required services (PostgreSQL) are running
    # - Runs Setup to ensure dependencies and database are ready
    # - Configures server port (manual, from .env, or auto-discovery)
    # - Starts the Rails server with optional debugging support
    #
    # @example Start dev server
    #   DevServer.new("/path/to/app").run(ARGV)
    #
    # @example Start with debug mode
    #   DevServer.new("/path/to/app").run(["--debug"])
    class DevServer
      attr_reader :app_root

      def initialize(app_root)
        @app_root = app_root
      end

      def run(argv)
        options = parse_arguments(argv)

        FileUtils.chdir(app_root) do
          run_setup(options)
          port = determine_port(options)
          bind = options[:bind]

          start_server(
            debug: options[:debug],
            bind: bind,
            port: port
          )
        end
      end

      private

      def run_setup(options)
        unless options[:skip_setup]
          puts "== Running setup ==\n"
          Setup.new(app_root).run(check_postgres: false)
          puts ""
        end
      end

      def determine_port(options)
        Env.load(app_root)
        options[:port] || ENV["RAILS_PORT"] || "3000"
      end

      def parse_arguments(argv)
        options = {
          debug: false,
          bind: "0.0.0.0",
          port: nil,
          skip_setup: false
        }

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: #{File.basename($0)} [OPTIONS]"
          opts.separator ""
          opts.separator "Start the Rails development server."
          opts.separator ""
          opts.separator "Options:"

          opts.on("-d", "--debug", "Run with rdbg debugger") do
            options[:debug] = true
          end

          opts.on("-b", "--bind ADDRESS", "Bind to ADDRESS (default: 0.0.0.0)") do |address|
            options[:bind] = address
          end

          opts.on("-p", "--port PORT", "Use PORT (default: from .env RAILS_PORT or 3000)") do |port|
            options[:port] = port
          end

          opts.on("-s", "--skip-setup", "Skip running bin/setup first") do
            options[:skip_setup] = true
          end

          opts.on("-h", "--help", "Show this help message") do
            puts opts
            puts ""
            puts "Examples:"
            puts "  #{File.basename($0)}         # Start server (runs setup first)"
            puts "  #{File.basename($0)} -s      # Start server without setup"
            puts "  #{File.basename($0)} -d      # Start with debugger"
            puts "  #{File.basename($0)} -p 3001 # Start on port 3001"
            puts ""
            puts "Port Configuration:"
            puts "  If port 3000 is in use, run bin/configure-ports to find an available port."
            exit 0
          end
        end

        parser.parse!(argv)
        options
      end

      def start_server(debug:, bind:, port:)
        puts "== Starting development server =="
        puts "   Bind: #{bind}"
        puts "   Port: #{port}"
        puts "   Debug: #{debug ? "enabled" : "disabled"}"
        puts ""

        $stdout.flush

        if debug
          exec "bundle", "exec", "rdbg", "--nonstop", "--open", "--command", "--",
            "bin/rails", "server", "-b", bind, "-p", port
        else
          exec "bin/rails", "server", "-b", bind, "-p", port
        end
      end
    end
  end
end

# rubocop:enable Rails/Output, Rails/Exit
