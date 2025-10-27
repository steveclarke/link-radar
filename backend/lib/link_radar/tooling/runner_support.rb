# frozen_string_literal: true

# rubocop:disable Rails/Output, Rails/Exit

require "fileutils"
require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "dotenv"
end

module LinkRadar
  module Tooling
    # Shared utilities for bin runner scripts
    #
    # Provides helper methods for environment file management and service
    # verification. Used by bin/setup, bin/dev, and bin/services scripts.
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
      #   RunnerSupport.create_env_file("/path/to/app")
      def self.create_env_file(app_root)
        env_file = File.join(app_root, ".env")
        sample_file = File.join(app_root, ".env.sample")

        if !File.exist?(env_file) && File.exist?(sample_file)
          puts "Creating .env from .env.sample..."
          FileUtils.cp sample_file, env_file
        elsif !File.exist?(env_file)
          puts "Warning: No .env or .env.sample file found. Using defaults."
        end
      end

      # Create Bruno .env file from .env.example if it doesn't exist
      #
      # Copies bruno/.env.example to bruno/.env if bruno/.env doesn't exist.
      # Bruno uses this file to configure API testing environment variables.
      #
      # @param app_root [String] Path to application root directory
      # @return [void]
      #
      # @example
      #   RunnerSupport.create_bruno_env_file("/path/to/app")
      def self.create_bruno_env_file(app_root)
        bruno_dir = File.join(app_root, "bruno")
        return unless File.directory?(bruno_dir)

        env_file = File.join(bruno_dir, ".env")
        example_file = File.join(bruno_dir, ".env.example")

        if !File.exist?(env_file) && File.exist?(example_file)
          puts "Creating bruno/.env from bruno/.env.example..."
          FileUtils.cp example_file, env_file
        elsif !File.exist?(env_file)
          puts "Warning: No bruno/.env.example file found."
        end
      end

      # Load environment variables from .env file using dotenv gem
      #
      # Parses the .env file and makes environment variables available in the
      # current process.
      #
      # @param app_root [String] Path to application root directory
      # @return [void]
      #
      # @example
      #   RunnerSupport.load_env_file("/path/to/app")
      #   ENV["RAILS_PORT"] #=> "3000"
      def self.load_env_file(app_root)
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

      # Check if PostgreSQL service is running via docker compose
      #
      # @return [Boolean] true if postgres service is running, false otherwise
      #
      # @example
      #   RunnerSupport.postgres_running? #=> true
      def self.postgres_running?
        system("docker compose ps -q postgres 2>/dev/null | grep -q .")
      end

      # Warn user that PostgreSQL is not running
      #
      # Displays a helpful message instructing the user to start the postgres
      # service using 'bin/services'.
      #
      # @return [void]
      #
      # @example
      #   unless RunnerSupport.postgres_running?
      #     RunnerSupport.warn_postgres_not_running
      #     exit 1
      #   end
      def self.warn_postgres_not_running
        puts "\n❌ PostgreSQL service is not running."
        puts ""
        puts "Please run 'bin/services' in another terminal first, then try again."
        puts ""
      end

      # Execute a system command with error handling
      #
      # Runs a system command and raises an exception if it fails. Displays
      # a formatted error message on failure.
      #
      # @param args [Array<String>] Command and arguments to execute
      # @return [void]
      # @raise [RuntimeError] If the command fails
      #
      # @example
      #   RunnerSupport.system!("bundle", "install")
      #   RunnerSupport.system!("bin/rails", "db:migrate")
      def self.system!(*args)
        system(*args, exception: true)
      rescue
        puts "\n❌ Command failed: #{args.join(" ")}"
        raise
      end
    end
  end
end

# rubocop:enable Rails/Output, Rails/Exit
