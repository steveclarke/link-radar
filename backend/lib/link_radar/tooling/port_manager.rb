# frozen_string_literal: true

# rubocop:disable Rails/Output, Rails/Exit

require "socket"
require_relative "runner_support"

module LinkRadar
  module Tooling
    # Custom exception for port discovery failures
    class PortDiscoveryError < StandardError; end

    # Port management for development services
    #
    # Handles port conflict detection, auto-discovery of available ports,
    # and port configuration management for development services. Used by
    # bin/services and bin/dev to ensure services can start without conflicts.
    #
    # @example Check if a port is in use
    #   PortManager.port_in_use?(3000) #=> true or false
    #
    # @example Auto-discover ports for backend services
    #   manager = PortManager.new(app_root, services: :backend_services)
    #   ports = manager.auto_discover_and_assign
    #   #=> { "POSTGRES_PORT" => 5432, "REDIS_PORT" => 6379, ... }
    #
    # @example Check for port conflicts
    #   manager = PortManager.new(app_root, services: :rails_server)
    #   manager.check_for_conflicts #=> exits if conflicts found
    class PortManager
      # Preset service configurations
      BACKEND_SERVICES = {
        "POSTGRES_PORT" => 5432,
        "REDIS_PORT" => 6379,
        "MAILDEV_WEB_PORT" => 1080,
        "MAILDEV_SMTP_PORT" => 1025
      }.freeze

      RAILS_SERVER = {
        "PORT" => 3000
      }.freeze

      SERVICE_NAMES = {
        "PORT" => "Rails Server",
        "POSTGRES_PORT" => "PostgreSQL",
        "REDIS_PORT" => "Redis",
        "MAILDEV_WEB_PORT" => "MailDev Web",
        "MAILDEV_SMTP_PORT" => "MailDev SMTP"
      }.freeze

      attr_reader :app_root, :services

      # Check if a TCP port is currently in use
      #
      # This is a convenience class method for quick port checks without
      # needing to instantiate a PortManager.
      #
      # @param port [Integer] The port number to check
      # @return [Boolean] true if port is in use, false if available
      #
      # @example
      #   PortManager.port_in_use?(3000)  #=> false
      #   PortManager.port_in_use?(5432)  #=> true
      def self.port_in_use?(port)
        server = nil
        server = TCPServer.new("0.0.0.0", port)
        false
      rescue Errno::EADDRINUSE
        true
      rescue Errno::EACCES
        warn "Permission denied checking port #{port}" if ENV["DEBUG"]
        true # Assume in use if we can't check due to permissions
      rescue => e
        warn "Error checking port #{port}: #{e.message}" if ENV["DEBUG"]
        false
      ensure
        server&.close
      end

      # Initialize a new PortManager
      #
      # @param app_root [String] Path to application root directory
      # @param services [Symbol, Hash] Either a preset symbol (:backend_services, :rails_server)
      #   or a custom hash of service names to port numbers
      #
      # @example Using preset
      #   PortManager.new("/app", services: :backend_services)
      #
      # @example Using custom services
      #   PortManager.new("/app", services: { "API_PORT" => 4000, "WEB_PORT" => 3000 })
      def initialize(app_root, services:)
        @app_root = app_root
        @services = resolve_services(services)
      end

      # Auto-discover available ports and assign them
      #
      # Finds an available set of ports (where all ports in the set are free),
      # updates the .env file with the discovered ports, and returns the port
      # configuration.
      #
      # @return [Hash<String, Integer>] Hash of environment variable names to assigned ports
      # @raise [SystemExit] If no available port set can be found after 50 attempts
      #
      # @example
      #   manager = PortManager.new(app_root, services: :backend_services)
      #   ports = manager.auto_discover_and_assign
      #   #=> { "POSTGRES_PORT" => 5433, "REDIS_PORT" => 6380, ... }
      def auto_discover_and_assign
        display_port_discovery_start
        discovered_ports = find_available_port_set!(@services)
        RunnerSupport.update_env_file(@app_root, discovered_ports)
        display_assigned_ports(discovered_ports)
        discovered_ports
      rescue PortDiscoveryError => e
        puts "❌ #{e.message}"
        puts "Please manually configure ports in your .env file."
        exit 1
      end

      # Check for port conflicts and exit if any are found
      #
      # Loads current port configuration from environment, checks each port
      # for conflicts, and displays an error message with resolution options
      # if conflicts are detected.
      #
      # @return [void]
      # @raise [SystemExit] If any configured ports are already in use
      #
      # @example
      #   manager = PortManager.new(app_root, services: :rails_server)
      #   manager.check_for_conflicts # exits with error if port 3000 is in use
      def check_for_conflicts
        RunnerSupport.load_env_file(@app_root)

        conflicts = []
        @services.each do |env_var, default_port|
          port = ENV[env_var] || default_port.to_s
          service_name = format_service_name(env_var)
          conflicts << "  • #{service_name}: port #{port}" if self.class.port_in_use?(port.to_i)
        end

        return if conflicts.empty?

        display_port_conflict_error(conflicts)
        exit 1
      end

      private

      # Resolve services parameter to a hash
      #
      # @param services [Symbol, Hash] Service preset or custom hash
      # @return [Hash<String, Integer>] Resolved service configuration
      def resolve_services(services)
        case services
        when :backend_services
          BACKEND_SERVICES
        when :rails_server
          RAILS_SERVER
        when Hash
          services
        else
          raise ArgumentError, "services must be :backend_services, :rails_server, or a Hash"
        end
      end

      # Find an available set of ports by trying offsets from base ports
      #
      # Attempts to find a set of ports where all ports in the set are available.
      # Tries multiple offsets, incrementing each port by the offset.
      #
      # @param base_ports [Hash<String, Integer>] Hash of env var names to base port numbers
      # @param max_attempts [Integer] Maximum number of offsets to try (default: 50)
      # @return [Hash<String, Integer>] Hash of available ports
      # @raise [PortDiscoveryError] If no available port set can be found
      def find_available_port_set!(base_ports, max_attempts: 50)
        (0...max_attempts).each do |offset|
          candidate_ports = base_ports.transform_values { |port| port + offset }

          # Check if all ports in this set are available
          all_available = candidate_ports.values.all? { |port| !self.class.port_in_use?(port) }

          return candidate_ports if all_available
        end

        raise PortDiscoveryError, "Could not find available ports after checking #{max_attempts} offsets."
      end

      # Format environment variable name to human-readable service name
      #
      # @param env_var [String] Environment variable name (e.g., "POSTGRES_PORT")
      # @return [String] Formatted service name (e.g., "PostgreSQL")
      def format_service_name(env_var)
        SERVICE_NAMES[env_var] ||
          env_var.sub("_PORT", "").split("_").map(&:capitalize).join(" ")
      end

      # Display port discovery start message
      #
      # @return [void]
      def display_port_discovery_start
        puts "🔍 Discovering available ports..."
      end

      # Display assigned ports
      #
      # @param ports [Hash<String, Integer>] Hash of environment variable names to assigned ports
      # @return [void]
      def display_assigned_ports(ports)
        puts "📍 Assigned ports:"
        ports.each do |env_var, port|
          service_name = format_service_name(env_var)
          puts "   #{service_name}: #{port}"
        end
        puts ""
      end

      # Display port conflict error message with resolution options
      #
      # @param conflicts [Array<String>] Array of conflict messages
      # @return [void]
      def display_port_conflict_error(conflicts)
        puts "\n❌ Port conflict detected!\n\n"
        puts "The following ports are already in use:"
        conflicts.each { |c| puts c }
        puts "\nOptions:"
        puts "  1. Stop the service using those ports"
        puts "  2. Change the ports in your .env file"
        puts "  3. Run 'bin/services down' if you have containers from a previous run"
        puts "  4. Use --auto-ports (bin/services) or --auto-port (bin/dev) to find available ports"
        puts ""
      end
    end
  end
end

# rubocop:enable Rails/Output, Rails/Exit
