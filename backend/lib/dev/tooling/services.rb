# frozen_string_literal: true

# rubocop:disable Rails/Output

require "fileutils"
require "optparse"
require_relative "env"
require_relative "shell"
require_relative "port_manager"

module Dev
  module Tooling
    # Docker Compose services orchestration
    #
    # Manages Docker services required by the Rails application:
    # - PostgreSQL (database)
    # - Redis (caching/background jobs)
    # - MailDev (email testing)
    #
    # Handles:
    # - Environment file creation (.env) if it doesn't exist
    # - Port configuration (manual or auto-discovery for multiple dev environments)
    # - Port conflict detection before starting services
    # - Docker Compose command execution with proper options
    #
    # @example Start services
    #   Services.new("/path/to/app").run(ARGV)
    #
    # @example Start in daemon mode
    #   Services.new("/path/to/app").run(["-d"])
    class Services
      attr_reader :app_root

      def initialize(app_root)
        @app_root = app_root
      end

      def run(argv)
        FileUtils.chdir(app_root) do
          options = parse_arguments(argv)

          Env.create(app_root)

          if options[:command] == "up"
            check_for_port_conflicts
          end

          execute_docker_command(options)
        end
      end

      private

      def parse_arguments(argv)
        options = {
          daemon_mode: [],
          command: "up"
        }

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: #{File.basename($0)} [OPTIONS] [COMMAND]"
          opts.separator ""
          opts.separator "Manage Docker Compose services for #{app_root}."
          opts.separator ""
          opts.separator "Options:"

          opts.on("-d", "--daemon", "Run in daemon mode (detached)") do
            options[:daemon_mode] = ["-d"]
          end

          opts.on("-h", "--help", "Show this help message") do
            puts opts
            show_additional_help
            exit 0
          end

          opts.separator ""
          opts.separator "Commands:"
          opts.separator "  up            Start services (default)"
          opts.separator "  down          Stop and remove services"
          opts.separator "  logs          View service logs"
          opts.separator "  restart       Restart services"
          opts.separator "  ps            List running services"
          opts.separator "  [any]         Pass any docker compose command"
        end

        parser.parse!(argv)

        if argv.any?
          known_commands = %w[up down logs restart ps stop start]
          if known_commands.include?(argv.first)
            options[:command] = argv.shift
          else
            options[:command] = argv.join(" ")
          end
        end

        options
      end

      def check_for_port_conflicts
        Env.load(app_root)

        port_manager = PortManager.new(
          app_root,
          services: :backend_services
        )
        port_manager.check_for_port_conflicts
      end

      def execute_docker_command(options)
        if options[:command] == "up"
          Shell.run!("docker", "compose", "up", *options[:daemon_mode])
        else
          exec "docker compose #{options[:command]}"
        end
      end

      def show_additional_help
        puts <<~HELP

          Port Configuration:
            All service ports can be configured via .env file:
              POSTGRES_PORT (default: 5432)
              REDIS_PORT (default: 6379)
              MAILDEV_WEB_PORT (default: 1080)
              MAILDEV_SMTP_PORT (default: 1025)

            If you encounter port conflicts, run:
              bin/configure-ports   # Interactive port configuration tool

            This will:
              1. Show which ports are in use
              2. Suggest available alternative ports
              3. Optionally update your .env file

          Examples:
            #{File.basename($0)}            # Start services in interactive mode
            #{File.basename($0)} -d         # Start services in daemon mode
            #{File.basename($0)} down       # Stop and remove services
            #{File.basename($0)} logs -f    # Follow service logs

          Git Worktrees:
            When working with multiple worktrees, run bin/configure-ports in each
            worktree to set unique ports and avoid conflicts.
        HELP
      end
    end
  end
end

# rubocop:enable Rails/Output
