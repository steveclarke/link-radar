# frozen_string_literal: true

# rubocop:disable Rails/Output, Rails/Exit

module Dev
  module Tooling
    # Port management for development services
    #
    # Handles port conflict detection for development services. Used by
    # bin/services and bin/dev to ensure services can start without conflicts.
    # For interactive port configuration, use bin/configure-ports instead.
    #
    # @example Check if a port is in use
    #   PortManager.port_in_use?(3000) #=> true or false
    #
    # @example Check for port conflicts
    #   manager = PortManager.new(app_root, services: :backend_services)
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
        require "socket"

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

      # Check for port conflicts and exit if any are found
      #
      # Expects environment variables to already be loaded.
      # Checks each configured port for conflicts and displays an error message
      # with resolution options if conflicts are detected.
      #
      # @return [void]
      # @raise [SystemExit] If any configured ports are already in use
      #
      # @example
      #   RunnerSupport.load_env_file(app_root)
      #   manager = PortManager.new(app_root, services: :rails_server)
      #   manager.check_for_port_conflicts # exits with error if port 3000 is in use
      def check_for_port_conflicts
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

      # Find the next available port starting from a base port
      #
      # Uses a simple linear search to find the next port that is not in use.
      # If no port is found in the initial range, tries the next thousand boundary.
      #
      # @param starting_port [Integer] The port to start searching from
      # @param max_attempts [Integer] Maximum number of ports to try (default: 100)
      # @return [Integer] The next available port number
      #
      # @example
      #   manager = PortManager.new(app_root, services: :backend_services)
      #   available_port = manager.find_next_available_port(5432)
      #   #=> 5433 (if 5432 is in use)
      def find_next_available_port(starting_port, max_attempts: 100)
        # Simple linear search starting from the base port
        (starting_port...(starting_port + max_attempts)).each do |port|
          return port unless self.class.port_in_use?(port)
        end

        # Fallback: start from next thousand boundary
        next_boundary = ((starting_port / 1000) + 1) * 1000
        (next_boundary...(next_boundary + max_attempts)).each do |port|
          return port unless self.class.port_in_use?(port)
        end

        starting_port # Give up and return original
      end

      # Load current port configuration from environment
      #
      # Expects environment variables to already be loaded.
      # Returns a hash with detailed information about each port including
      # current value, default value, source (.env or default), and metadata.
      #
      # @return [Hash<String, Hash>] Hash mapping env var names to port configuration
      #
      # @example
      #   RunnerSupport.load_env_file(app_root)
      #   manager = PortManager.new(app_root, services: :backend_services)
      #   config = manager.load_current_config
      #   #=> {
      #     "POSTGRES_PORT" => {
      #       name: "PostgreSQL",
      #       port: 5432,
      #       default: 5432,
      #       from_env: false
      #     },
      #     ...
      #   }
      def load_current_config
        config = {}
        SERVICES.each do |env_var, meta|
          current_port = ENV[env_var] || meta[:port].to_s
          config[env_var] = {
            name: meta[:name],
            port: current_port.to_i,
            default: meta[:port],
            from_env: !ENV[env_var].nil?
          }
        end
        config
      end

      # Get list of environment variables with port conflicts
      #
      # Checks the current configuration and returns a list of environment
      # variable names where the configured port is already in use.
      #
      # @param config [Hash] Optional configuration hash from load_current_config.
      #                      If not provided, loads current config automatically.
      # @return [Array<String>] Array of environment variable names with conflicts
      #
      # @example
      #   manager = PortManager.new(app_root, services: :backend_services)
      #   conflicts = manager.get_conflicts
      #   #=> ["POSTGRES_PORT", "REDIS_PORT"]
      def get_conflicts(config = nil)
        config ||= load_current_config

        conflicts = []
        config.each do |env_var, data|
          conflicts << env_var if self.class.port_in_use?(data[:port])
        end
        conflicts
      end

      # Generate port suggestions for conflicting ports
      #
      # For each conflicting port, finds the next available port and returns
      # a hash suitable for updating the .env file.
      #
      # @param conflicts [Array<String>] Array of env var names with conflicts
      # @param config [Hash] Optional configuration hash from load_current_config.
      #                      If not provided, loads current config automatically.
      # @return [Hash<String, Integer>] Hash mapping env var names to suggested ports
      #
      # @example
      #   manager = PortManager.new(app_root, services: :backend_services)
      #   conflicts = ["POSTGRES_PORT"]
      #   suggestions = manager.suggest_ports(conflicts)
      #   #=> { "POSTGRES_PORT" => 5433 }
      def suggest_ports(conflicts, config = nil)
        config ||= load_current_config

        suggestions = {}
        conflicts.each do |env_var|
          data = config[env_var]
          suggestions[env_var] = find_next_available_port(data[:port])
        end
        suggestions
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

      # Format environment variable name to human-readable service name
      #
      # @param env_var [String] Environment variable name (e.g., "POSTGRES_PORT")
      # @return [String] Formatted service name (e.g., "PostgreSQL")
      def format_service_name(env_var)
        SERVICES.dig(env_var, :name) ||
          env_var.sub("_PORT", "").split("_").map(&:capitalize).join(" ")
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
        puts "  2. Run 'bin/configure-ports' to find and configure available ports"
        puts "  3. Run 'bin/services down' if you have containers from a previous run"
        puts "  4. Manually change the ports in your .env file"
        puts ""
      end
    end
  end
end

# rubocop:enable Rails/Output, Rails/Exit
