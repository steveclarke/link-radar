# frozen_string_literal: true

# rubocop:disable Rails/Output

module Dev
  module Tooling
    # Shell command execution utilities
    #
    # Provides helpers for running system commands with proper error handling.
    # Used by bin scripts that run before Rails is loaded.
    #
    # @example Run a command that must succeed
    #   Shell.run!("bundle", "install")
    #
    # @example Run a command that may fail
    #   Shell.run("bin/rails", "db:seed")  # returns true/false
    module Shell
      # Execute a system command with error handling
      #
      # Runs a system command and raises an exception if it fails.
      # Displays a formatted error message on failure.
      #
      # @param args [Array<String>] Command and arguments to execute
      # @return [void]
      # @raise [RuntimeError] If the command fails
      def self.run!(*args)
        system(*args, exception: true)
      rescue
        puts "\n\u274C Command failed: #{args.join(" ")}"
        raise
      end

      # Execute a system command without raising on failure
      #
      # @param args [Array<String>] Command and arguments to execute
      # @return [Boolean] true if command succeeded, false otherwise
      def self.run(*args)
        system(*args)
      end
    end
  end
end

# rubocop:enable Rails/Output
