# frozen_string_literal: true

# rubocop:disable Rails/Output

module Dev
  module Tooling
    # Environment file management utilities
    #
    # Provides methods for creating, loading, and updating .env files.
    # Used by bin scripts that run before Rails is loaded.
    #
    # @example Create .env from sample
    #   Env.create("/path/to/app")
    #
    # @example Load environment variables
    #   Env.load("/path/to/app")
    #   ENV["RAILS_PORT"] #=> "3000"
    #
    # @example Update .env values
    #   Env.update("/path/to/app", { "PORT" => 3001 })
    module Env
      # Create .env file from .env.sample if it doesn't exist
      #
      # @param app_root [String] Path to application root directory
      # @return [void]
      def self.create(app_root)
        require "fileutils"

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
      # Bruno uses this file to configure API testing environment variables.
      #
      # @param app_root [String] Path to application root directory
      # @return [void]
      def self.create_bruno(app_root)
        require "fileutils"

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
      # Ensures dotenv gem is available before loading. Uses Bundler.inline
      # to bootstrap dotenv if needed (e.g., during initial setup).
      #
      # @param app_root [String] Path to application root directory
      # @return [void]
      def self.load(app_root)
        begin
          require "dotenv"
        rescue LoadError
          require "bundler/inline"
          gemfile do
            source "https://rubygems.org"
            gem "dotenv"
          end
        end

        env_file = File.join(app_root, ".env")
        Dotenv.load(env_file) if File.exist?(env_file)
      end

      # Update .env file with key-value pairs
      #
      # Updates or adds configuration to .env file. Can uncomment existing
      # commented lines or add new lines if they don't exist.
      #
      # @param app_root [String] Path to application root directory
      # @param key_values [Hash<String, Object>] Hash of environment variable names to values
      # @return [void]
      def self.update(app_root, key_values)
        env_file = File.join(app_root, ".env")

        env_content = if File.exist?(env_file)
          File.read(env_file)
        else
          ""
        end

        key_values.each do |key, value|
          commented_pattern = /^#\s*#{Regexp.escape(key)}=.*$/
          uncommented_pattern = /^#{Regexp.escape(key)}=.*$/

          if env_content.match?(uncommented_pattern)
            env_content.gsub!(uncommented_pattern, "#{key}=#{value}")
          elsif env_content.match?(commented_pattern)
            env_content.gsub!(commented_pattern, "#{key}=#{value}")
          else
            env_content += "\n" unless env_content.empty? || env_content.end_with?("\n")
            env_content += "#{key}=#{value}\n"
          end
        end

        File.write(env_file, env_content)
      end
    end
  end
end

# rubocop:enable Rails/Output
