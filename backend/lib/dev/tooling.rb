# frozen_string_literal: true

# Loader for development tooling
#
# Note: We use require_relative here (not Zeitwerk autoloading) because these
# utilities are used by bin scripts (bin/dev, bin/setup, bin/services) that run
# OUTSIDE the Rails environment. These scripts need to bootstrap the development
# environment before Rails is loaded, so Zeitwerk autoloading is not available.

# Utility modules
require_relative "tooling/env"
require_relative "tooling/shell"
require_relative "tooling/postgres"

# Service wrappers
require_relative "tooling/one_password_client"
require_relative "tooling/port_manager"
require_relative "tooling/package_installer"

# Orchestrators
require_relative "tooling/setup"
require_relative "tooling/dev_server"
require_relative "tooling/services"
