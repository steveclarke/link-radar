# frozen_string_literal: true

# rubocop:disable Rails/Output

require "open3"

module LinkRadar
  module Tooling
    # Client for interacting with 1Password CLI to fetch secrets
    #
    # Usage:
    #   client = LinkRadar::Tooling::OnePasswordClient.new
    #
    #   if client.available?
    #     secret = client.fetch(
    #       item: "abc123",
    #       field: "password",
    #       vault: "MyVault"
    #     )
    #   end
    #
    # The client automatically handles:
    # - Finding the op CLI in common Homebrew locations
    # - Interactive biometric authentication prompts
    # - Graceful fallback when 1Password isn't available
    class OnePasswordClient
      # Fetch a secret from 1Password by item ID or item name
      #
      # Note: Using item IDs is recommended over item names for stability,
      # as IDs won't break if the item is renamed in 1Password.
      #
      # @param item [String] The 1Password item ID or item name
      # @param field [String] The field name to fetch (e.g., "password", "credential")
      # @param vault [String] The vault name
      # @return [String, nil] The secret value or nil if not found/failed
      def fetch(item:, field:, vault:)
        return nil unless available?

        # Use Open3.capture3 with array args to prevent shell injection
        stdout, _stderr, status = Open3.capture3(
          cli_path, "item", "get", item,
          "--vault", vault,
          "--fields", field,
          "--reveal",
          err: "/dev/tty"
        )

        (status.success? && !stdout.strip.empty?) ? stdout.strip : nil
      rescue => e
        warn "OnePasswordClient error: #{e.message}" if ENV["DEBUG"]
        nil
      end

      # Check if 1Password CLI is available
      #
      # @return [Boolean] true if op CLI is installed
      def available?
        !cli_path.nil?
      end

      private

      # Find the 1Password CLI executable path
      #
      # @return [String, nil] Path to op executable or nil if not found
      def cli_path
        @cli_path ||= find_cli_path
      end

      # Find op CLI in common locations
      #
      # @return [String, nil] Path to op executable or nil if not found
      def find_cli_path
        # Check Homebrew locations first (works even without Homebrew in PATH)
        homebrew_paths = [
          "/opt/homebrew/bin/op",                    # Apple Silicon Mac
          "/usr/local/bin/op",                       # Intel Mac
          "/home/linuxbrew/.linuxbrew/bin/op"        # Linux Homebrew
        ]

        homebrew_paths.each do |path|
          return path if File.executable?(path)
        end

        # Fall back to PATH
        op_path = `which op 2>/dev/null`.strip
        op_path.empty? ? nil : op_path
      end
    end
  end
end

# rubocop:enable Rails/Output
