# frozen_string_literal: true

# rubocop:disable Rails/Output, Rails/Exit

require "fileutils"
require "io/console"
require_relative "runner_support"
require_relative "one_password_client"

module LinkRadar
  module Tooling
    # Idempotent setup runner for development environment
    #
    # Orchestrates the complete development environment setup process including:
    # - Installing Ruby dependencies
    # - Creating .env file from sample
    # - Fetching Rails master.key from 1Password
    # - Installing system packages (vips, ffmpeg)
    # - Preparing database (creating, migrating, seeding)
    # - Cleaning up logs and temp files
    #
    # Safe to run multiple times (idempotent) - will only perform actions if needed.
    #
    # @example Basic usage
    #   runner = SetupRunner.new("/path/to/app")
    #   runner.run
    #
    # @example With database reset
    #   runner = SetupRunner.new("/path/to/app")
    #   runner.run(reset: true)
    class SetupRunner
      APP_NAME = "link-radar"

      ONEPASSWORD_DEFAULTS = {
        item_id: "bnnbff4pii2cg6s6pp2mhn5f6a",
        vault: "LinkRadar",
        field: "credential"
      }.freeze

      SYSTEM_PACKAGES = {
        vips: {
          apt: "libvips-dev",
          brew: "vips",
          description: "Image processing library"
        },
        ffmpeg: {
          apt: "ffmpeg",
          brew: "ffmpeg",
          description: "Video/audio processing"
        }
      }.freeze

      # @return [String] Path to application root directory
      attr_reader :app_root

      # Initialize a new SetupRunner
      #
      # @param app_root [String] Path to application root directory
      #
      # @example
      #   runner = SetupRunner.new("/Users/steve/app")
      def initialize(app_root)
        @app_root = app_root
      end

      # Run the setup process
      #
      # Executes the complete setup sequence.
      # The process is idempotent and safe to run multiple times.
      #
      # @param reset [Boolean] If true, resets the database before preparing
      # @return [void]
      #
      # @example Run normal setup
      #   runner.run
      #
      # @example Reset database during setup
      #   runner.run(reset: true)
      def run(reset: false)
        FileUtils.chdir(app_root) do
          puts "== Setting up #{app_name} =="

          # Check PostgreSQL is running (needed for migrations)
          unless RunnerSupport.postgres_running?
            RunnerSupport.warn_postgres_not_running
            exit 1
          end

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

      def app_name
        APP_NAME
      end

      def install_dependencies
        puts "\n== Installing dependencies =="
        system("bundle check") || RunnerSupport.system!("bundle install")
      end

      def create_env_file
        puts "\n== Copying sample files =="
        RunnerSupport.create_env_file(app_root)
      end

      def check_master_key
        puts "\n== Checking for Rails credential keys =="
        master_key_path = File.join(app_root, "config/master.key")

        return if File.exist?(master_key_path)

        # Try to fetch from 1Password first
        key = fetch_master_key_from_onepassword

        # Fall back to environment variable
        key ||= ENV["RAILS_MASTER_KEY"]

        # If still no key, prompt for manual entry
        # rubocop:disable Rails/Blank -- Cannot use .blank? as Rails isn't loaded yet
        if key.nil? || key.empty?
          print "Enter your master.key: "
          key = $stdin.noecho(&:gets).chomp
          puts "" # newline after hidden input
        else
          puts "✓ Retrieved master.key from #{master_key_source}"
        end
        # rubocop:enable Rails/Blank

        # Write the key to file with secure permissions
        File.write(master_key_path, key)
        FileUtils.chmod(0o600, master_key_path)
        puts "✓ master.key saved with secure permissions (0600)"
      end

      def fetch_master_key_from_onepassword
        # Allow explicit skip for devs without 1Password
        if ENV["SKIP_ONEPASSWORD"]
          puts "  Skipping 1Password (SKIP_ONEPASSWORD is set)"
          return nil
        end

        # Allow customization via environment variables for testing/other developers
        # Defaults to LinkRadar project's 1Password configuration
        item_id = ENV["MASTER_KEY_OP_ITEM_ID"] || ONEPASSWORD_DEFAULTS[:item_id]
        vault = ENV["MASTER_KEY_OP_VAULT"] || ONEPASSWORD_DEFAULTS[:vault]
        field = ENV["MASTER_KEY_OP_FIELD"] || ONEPASSWORD_DEFAULTS[:field]

        client = OnePasswordClient.new
        unless client.available?
          puts "  1Password CLI not available, skipping..."
          return nil
        end

        key = client.fetch(item: item_id, field: field, vault: vault)
        @master_key_source = "1Password (#{vault})" if key
        key
      end

      def master_key_source
        @master_key_source || "environment variable"
      end

      def install_system_packages
        if has_apt?
          install_apt_packages
        elsif has_macos?
          install_brew_packages
        else
          show_manual_install_message
        end
      end

      def install_apt_packages
        SYSTEM_PACKAGES.each do |name, config|
          unless apt_package_installed?(config[:apt])
            puts "\n== Installing #{config[:apt]} (#{config[:description]}) =="
            RunnerSupport.system!("sudo apt install -y #{config[:apt]}")
          end
        end
      end

      def install_brew_packages
        SYSTEM_PACKAGES.each do |name, config|
          unless system("brew list | grep -q #{config[:brew]}")
            puts "\n== Installing #{config[:brew]} (#{config[:description]}) =="
            RunnerSupport.system!("brew install #{config[:brew]}")
          end
        end
      end

      def show_manual_install_message
        puts "\n== System packages (manual installation required) =="
        puts "Your system is not Ubuntu/Debian or macOS."
        puts "Please install these packages using your package manager:\n\n"

        SYSTEM_PACKAGES.each do |name, config|
          puts "  • #{name} - #{config[:description]}"
          puts "    (apt: #{config[:apt]}, brew: #{config[:brew]})"
        end

        puts "\nContinuing setup..."
      end

      def prepare_database(reset = false)
        puts "\n== Preparing database =="

        if reset
          RunnerSupport.system! "bin/rails db:reset"
        else
          RunnerSupport.system! "bin/rails db:prepare"
        end
      end

      def cleanup_logs
        puts "\n== Removing old logs and tempfiles =="
        RunnerSupport.system! "bin/rails log:clear tmp:clear"
      end

      def has_apt?
        return false unless File.exist?("/etc/os-release")

        os_release = File.read("/etc/os-release")
        # Check if distro uses apt (Debian, Ubuntu, Linux Mint, Pop!_OS, etc.)
        os_release.match?(/ID(_LIKE)?=.*(debian|ubuntu)/)
      rescue
        # Fallback to legacy detection for older systems
        File.exist?("/etc/lsb-release") || File.exist?("/etc/debian_version")
      end

      def has_macos?
        RUBY_PLATFORM.include?("darwin")
      end

      def apt_package_installed?(pkg)
        # Don't show output. We just want the return value to see if it is installed.
        system("dpkg -s #{pkg}", %i[out err] => File::NULL)
      end
    end
  end
end

# rubocop:enable Rails/Output, Rails/Exit
