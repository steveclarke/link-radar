# frozen_string_literal: true

# Loader for LinkRadar development tooling
#
# Note: We use require_relative here (not Zeitwerk autoloading) because these
# utilities are used by bin scripts (bin/dev, bin/setup, bin/services) that run
# OUTSIDE the Rails environment. These scripts need to bootstrap the development
# environment before Rails is loaded, so Zeitwerk autoloading is not available.
require_relative "tooling/runner_support"
require_relative "tooling/one_password_client"
require_relative "tooling/setup_runner"
require_relative "tooling/port_manager"
