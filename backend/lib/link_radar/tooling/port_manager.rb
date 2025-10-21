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
    #   ports = manager.auto_discover_and_set_ports
    #   #=> { "POSTGRES_PORT" => 5432, "REDIS_PORT" => 6379, ... }
    #
    # @example Check for port conflicts
    #   manager = PortManager.new(app_root, services: :rails_server)
    #   manager.check_for_port_conflicts #=> exits if conflicts found
    class PortManager
      # Service configurations with all metadata
      SERVICES = {
        "RAILS_PORT" => {port: 3000, name: "Rails Server", group: :rails_server},
        "POSTGRES_PORT" => {port: 5432, name: "PostgreSQL", group: :backend_services},
        "REDIS_PORT" => {port: 6379, name: "Redis", group: :backend_services},
        "MAILDEV_WEB_PORT" => {port: 1080, name: "MailDev Web", group: :backend_services},
        "MAILDEV_SMTP_PORT" => {port: 1025, name: "MailDev SMTP", group: :backend_services}
      }.freeze

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
      # @param services [Symbol] Service preset (:backend_services or :rails_server)
      #
      # @example Using backend services preset
      #   PortManager.new("/app", services: :backend_services)
      #
      # @example Using rails server preset
      #   PortManager.new("/app", services: :rails_server)
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
      #   ports = manager.auto_discover_and_set_ports
      #   #=> { "POSTGRES_PORT" => 5433, "REDIS_PORT" => 6380, ... }
      def auto_discover_and_set_ports
        puts "🔍 Discovering available ports..."
        discovered_ports = find_available_port_set!(services)
        RunnerSupport.update_env_file(app_root, discovered_ports)
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
      #   manager.check_for_port_conflicts # exits with error if port 3000 is in use
      def check_for_port_conflicts
        RunnerSupport.load_env_file(app_root)

        conflicts = []
        services.each do |env_var, default_port|
          port = ENV[env_var] || default_port.to_s
          service_name = format_service_name(env_var)
          conflicts << "  • #{service_name}: port #{port}" if self.class.port_in_use?(port.to_i)
        end

        return if conflicts.empty?

        display_port_conflict_error(conflicts)
        exit 1
      end

      private

      attr_reader :app_root, :services

      # Resolve services parameter to a hash
      #
      # @param services [Symbol] Service preset (:backend_services or :rails_server)
      # @return [Hash<String, Integer>] Resolved service configuration
      def resolve_services(services)
        unless %i[backend_services rails_server].include?(services)
          raise ArgumentError, "services must be :backend_services or :rails_server"
        end

        # Filter SERVICES by group and extract env_var => port pairs
        SERVICES.select { |_key, meta| meta[:group] == services }
          .transform_values { |meta| meta[:port] }
      end

      # Find an available set of ports by trying offsets from base ports
      #
      # This method finds ALL ports as a cohesive set - they must all be available together.
      # It does NOT find ports individually. This ensures that when running multiple dev
      # environments (e.g., git worktrees), each environment gets a consistent port offset.
      #
      # Algorithm:
      # - Try offset 0: If ALL base ports are free, use them
      # - Try offset 1: Add 1 to ALL ports, check if ALL are free
      # - Try offset 2: Add 2 to ALL ports, check if ALL are free
      # - Continue up to max_attempts
      #
      # Example: For {POSTGRES_PORT: 5432, REDIS_PORT: 6379}
      # - Offset 0: 5432, 6379 (both must be free)
      # - Offset 1: 5433, 6380 (both must be free)
      # - Offset 2: 5434, 6381 (both must be free)
      #
      # @param base_ports [Hash<String, Integer>] Hash of env var names to base port numbers
      # @param max_attempts [Integer] Maximum number of offsets to try (default: 50)
      # @return [Hash<String, Integer>] Hash of available ports (all with same offset applied)
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
        SERVICES.dig(env_var, :name) ||
          env_var.sub("_PORT", "").split("_").map(&:capitalize).join(" ")
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
