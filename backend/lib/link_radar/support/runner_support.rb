# frozen_string_literal: true

# rubocop:disable Rails/Output, Rails/Exit

require "fileutils"
require_relative "one_password_client"

module LinkRadar
  module Support
    # Shared utilities for bin runner scripts
    #
    # Provides helper methods for environment file management, 1Password CLI
    # integration, and service verification. Used by bin/setup, bin/dev, and
    # bin/services scripts.
    #
    # @example Load environment file
    #   RunnerSupport.load_env_file("/path/to/app")
    #
    # @example Update environment file
    #   RunnerSupport.update_env_file("/app", { "PORT" => 3001, "DEBUG" => "true" })
    module RunnerSupport
      # Create .env file from .env.sample if it doesn't exist
      #
      # Copies .env.sample to .env if .env doesn't exist. Outputs warnings if
      # neither file exists.
      #
      # @param app_root [String] Path to application root directory
      # @return [void]
      #
      # @example
      #   RunnerSupport.create_env_file_if_missing("/path/to/app")
      def self.create_env_file_if_missing(app_root)
        env_file = File.join(app_root, ".env")
        sample_file = File.join(app_root, ".env.sample")

        if !File.exist?(env_file) && File.exist?(sample_file)
          puts "Creating .env from .env.sample..."
          FileUtils.cp sample_file, env_file
        elsif !File.exist?(env_file)
          puts "Warning: No .env or .env.sample file found. Using defaults."
        end
      end

      # Load environment variables from .env file using dotenv gem
      #
      # Uses bundler/inline to load the dotenv gem and parse the .env file.
      # This allows environment variables to be available in the current process.
      #
      # @param app_root [String] Path to application root directory
      # @return [void]
      #
      # @example
      #   RunnerSupport.load_env_file("/path/to/app")
      #   ENV["PORT"] #=> "3000"
      def self.load_env_file(app_root)
        require "bundler/inline"

        gemfile do
          source "https://rubygems.org"
          gem "dotenv"
        end

        env_file = File.join(app_root, ".env")
        Dotenv.load(env_file) if File.exist?(env_file)
      end

      # Update .env file with key-value pairs
      #
      # Updates or adds configuration to .env file. Can uncomment existing
      # commented lines or add new lines if they don't exist. This is a generic
      # utility for updating any environment variables.
      #
      # @param app_root [String] Path to application root directory
      # @param key_values [Hash<String, Object>] Hash of environment variable names to values
      # @return [void]
      #
      # @example
      #   RunnerSupport.update_env_file(
      #     "/path/to/app",
      #     { "POSTGRES_PORT" => 5433, "DEBUG" => "true", "API_KEY" => "secret" }
      #   )
      def self.update_env_file(app_root, key_values)
        env_file = File.join(app_root, ".env")

        # Read existing .env content
        env_content = if File.exist?(env_file)
          File.read(env_file)
        else
          ""
        end

        # Update or add each key-value pair
        key_values.each do |key, value|
          # Check for commented or uncommented line
          commented_pattern = /^#\s*#{Regexp.escape(key)}=.*$/
          uncommented_pattern = /^#{Regexp.escape(key)}=.*$/

          if env_content.match?(uncommented_pattern)
            # Update existing uncommented line
            env_content.gsub!(uncommented_pattern, "#{key}=#{value}")
          elsif env_content.match?(commented_pattern)
            # Uncomment and update the line
            env_content.gsub!(commented_pattern, "#{key}=#{value}")
          else
            # Add new line if it doesn't exist at all
            env_content += "\n" unless env_content.empty? || env_content.end_with?("\n")
            env_content += "#{key}=#{value}\n"
          end
        end

        # Write back to file
        File.write(env_file, env_content)
      end

      # Get singleton instance of OnePasswordClient
      #
      # Returns a cached instance of OnePasswordClient for fetching secrets
      # from 1Password CLI.
      #
      # @return [OnePasswordClient] Singleton instance of OnePasswordClient
      #
      # @example
      #   client = RunnerSupport.onepassword_client
      #   secret = client.fetch_by_id(item_id: "abc", field: "password", vault: "Dev")
      def self.onepassword_client
        @onepassword_client ||= OnePasswordClient.new
      end

      # Check if PostgreSQL service is running via docker compose
      #
      # @return [Boolean] true if postgres service is running, false otherwise
      #
      # @example
      #   RunnerSupport.postgres_running? #=> true
      def self.postgres_running?
        system("docker compose ps -q postgres 2>/dev/null | grep -q .")
      end

      # Check if PostgreSQL is running, exit with error message if not
      #
      # Verifies that the postgres docker compose service is running. If not,
      # displays an error message and exits the process.
      #
      # @param suggest_command [String] Command to suggest running (default: "bin/services")
      # @return [void]
      #
      # @example
      #   RunnerSupport.check_postgres_or_exit("bin/services")
      def self.check_postgres_or_exit(suggest_command = "bin/services")
        return if postgres_running?

        puts "\n❌ PostgreSQL service is not running."
        puts ""
        puts "Please run '#{suggest_command}' in another terminal first, then try again."
        puts ""
        exit 1
      end
    end
  end
end

# rubocop:enable Rails/Output, Rails/Exit
