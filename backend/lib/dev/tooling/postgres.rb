# frozen_string_literal: true

# rubocop:disable Rails/Output

module Dev
  module Tooling
    # PostgreSQL service status utilities
    #
    # Provides methods for checking if PostgreSQL is running via Docker Compose.
    # Used by bin scripts to verify database availability before operations.
    #
    # @example Check if postgres is running
    #   if Postgres.running?
    #     # proceed with database operations
    #   else
    #     Postgres.warn_not_running
    #     exit 1
    #   end
    module Postgres
      # Check if PostgreSQL service is running via docker compose
      #
      # @return [Boolean] true if postgres service is running, false otherwise
      def self.running?
        system("docker compose ps -q postgres 2>/dev/null | grep -q .")
      end

      # Warn user that PostgreSQL is not running
      #
      # Displays a helpful message instructing the user to start the postgres
      # service using 'bin/services'.
      #
      # @return [void]
      def self.warn_not_running
        puts "\n\u274C PostgreSQL service is not running."
        puts ""
        puts "Please run 'bin/services' in another terminal first, then try again."
        puts ""
      end
    end
  end
end

# rubocop:enable Rails/Output
