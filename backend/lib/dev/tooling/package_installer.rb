# frozen_string_literal: true

# rubocop:disable Rails/Output

require_relative "shell"

module Dev
  module Tooling
    # Installs system packages across different platforms
    #
    # Detects the current platform (apt-based Linux, macOS with Homebrew, or other)
    # and installs required system packages accordingly.
    #
    # @example
    #   PackageInstaller.new.install_all
    class PackageInstaller
      PACKAGES = {
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

      def install_all
        case platform
        when :apt then install_apt_packages
        when :brew then install_brew_packages
        else show_manual_install_message
        end
      end

      private

      def platform
        return :apt if apt_based?
        return :brew if macos?

        :unknown
      end

      def apt_based?
        return false unless File.exist?("/etc/os-release")

        File.read("/etc/os-release").match?(/ID(_LIKE)?=.*(debian|ubuntu)/)
      rescue
        File.exist?("/etc/lsb-release") || File.exist?("/etc/debian_version")
      end

      def macos?
        RUBY_PLATFORM.include?("darwin")
      end

      def install_apt_packages
        PACKAGES.each_value do |config|
          next if apt_installed?(config[:apt])

          puts "\n== Installing #{config[:apt]} (#{config[:description]}) =="
          Shell.run!("sudo apt install -y #{config[:apt]}")
        end
      end

      def install_brew_packages
        PACKAGES.each_value do |config|
          next if brew_installed?(config[:brew])

          puts "\n== Installing #{config[:brew]} (#{config[:description]}) =="
          Shell.run!("brew install #{config[:brew]}")
        end
      end

      def apt_installed?(pkg)
        system("dpkg -s #{pkg}", %i[out err] => File::NULL)
      end

      def brew_installed?(pkg)
        system("brew list | grep -q #{pkg}")
      end

      def show_manual_install_message
        puts "\n== System packages (manual installation required) =="
        puts "Your system is not Ubuntu/Debian or macOS."
        puts "Please install these packages using your package manager:\n\n"
        PACKAGES.each do |name, config|
          puts "  - #{name} - #{config[:description]}"
        end
        puts "\nContinuing setup..."
      end
    end
  end
end

# rubocop:enable Rails/Output
