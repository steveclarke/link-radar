# frozen_string_literal: true

# rubocop:disable Rails/Output, Rails/Exit

require_relative "env"
require_relative "shell"
require_relative "postgres"
require_relative "package_installer"
require_relative "one_password_client"

module Dev
  module Tooling
    # Idempotent setup for development environment
    #
    # Orchestrates the complete development environment setup process including:
    # - Installing Ruby dependencies
    # - Creating .env file from sample
    # - Creating bruno/.env file from example (for API testing)
    # - Fetching Rails master.key from 1Password
    # - Installing system packages (vips, ffmpeg)
    # - Preparing database (creating, migrating, seeding)
    # - Cleaning up logs and temp files
    #
    # Safe to run multiple times (idempotent) - will only perform actions if needed.
    #
    # @example Basic usage
    #   setup = Setup.new("/path/to/app")
    #   setup.run
    #
    # @example With database reset
    #   setup = Setup.new("/path/to/app")
    #   setup.run(reset: true)
    class Setup
      APP_NAME = "link-radar"

      ONEPASSWORD_DEFAULTS = {
        item_id: "bnnbff4pii2cg6s6pp2mhn5f6a",
        vault: "LinkRadar",
        field: "credential"
      }.freeze

      attr_reader :app_root

      # @param app_root [String] Path to application root directory
      def initialize(app_root)
        @app_root = app_root
      end

      # Run the setup process
      #
      # @param reset [Boolean] If true, resets the database before preparing
      # @param check_postgres [Boolean] If true, checks PostgreSQL is running before setup
      def run(reset: false, check_postgres: true)
        require "fileutils"

        if check_postgres && !Postgres.running?
          Postgres.warn_not_running
          exit 1
        end

        FileUtils.chdir(app_root) do
          puts "== Setting up #{APP_NAME} =="

          install_dependencies
          create_env_file
          check_master_key
          install_system_packages
          prepare_database(reset)
          cleanup_logs

          puts "\n✅ Setup complete!"
        end
      end

      private

      def install_dependencies
        puts "\n== Installing dependencies =="
        system("bundle check") || Shell.run!("bundle install")
      end

      def create_env_file
        puts "\n== Copying sample files =="
        Env.create(app_root)
        Env.create_bruno(app_root)
      end

      def check_master_key
        require "fileutils"
        require "io/console"

        puts "\n== Checking for Rails credential keys =="
        master_key_path = File.join(app_root, "config/master.key")
        return if File.exist?(master_key_path)

        key = resolve_master_key
        write_master_key(master_key_path, key)
      end

      def resolve_master_key
        key = fetch_master_key_from_onepassword || ENV["RAILS_MASTER_KEY"]

        if key.to_s.empty?
          prompt_for_master_key
        else
          puts "✓ Retrieved master.key from #{master_key_source}"
          key
        end
      end

      def prompt_for_master_key
        print "Enter your master.key: "
        key = $stdin.noecho(&:gets).chomp
        puts ""
        key
      end

      def write_master_key(path, key)
        File.write(path, key)
        FileUtils.chmod(0o600, path)
        puts "✓ master.key saved with secure permissions (0600)"
      end

      def fetch_master_key_from_onepassword
        return skip_onepassword("SKIP_ONEPASSWORD is set") if ENV["SKIP_ONEPASSWORD"]

        client = OnePasswordClient.new
        return skip_onepassword("1Password CLI not available") unless client.available?

        config = onepassword_config
        key = client.fetch(item: config[:item_id], field: config[:field], vault: config[:vault])
        @master_key_source = "1Password (#{config[:vault]})" if key
        key
      end

      def skip_onepassword(reason)
        puts "  Skipping 1Password (#{reason})"
        nil
      end

      def onepassword_config
        {
          item_id: ENV["MASTER_KEY_OP_ITEM_ID"] || ONEPASSWORD_DEFAULTS[:item_id],
          vault: ENV["MASTER_KEY_OP_VAULT"] || ONEPASSWORD_DEFAULTS[:vault],
          field: ENV["MASTER_KEY_OP_FIELD"] || ONEPASSWORD_DEFAULTS[:field]
        }
      end

      def master_key_source
        @master_key_source || "environment variable"
      end

      def install_system_packages
        PackageInstaller.new.install_all
      end

      def prepare_database(reset)
        puts "\n== Preparing database =="
        command = reset ? "db:reset" : "db:prepare"
        Shell.run! "bin/rails #{command}"
        load_llm_models
      end

      def load_llm_models
        puts "\n== Loading LLM models =="
        Shell.run "bin/rails ruby_llm:load_models"
      rescue => e
        warn "\n⚠️  Failed to load LLM models: #{e.message}"
        warn "You can run manually later: bin/rails ruby_llm:load_models"
      end

      def cleanup_logs
        puts "\n== Removing old logs and tempfiles =="
        Shell.run! "bin/rails log:clear tmp:clear"
      end
    end
  end
end

# rubocop:enable Rails/Output, Rails/Exit
