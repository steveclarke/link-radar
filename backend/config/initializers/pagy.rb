# frozen_string_literal: true

# Pagy initializer file (43.0.0)
# See https://ddnexus.github.io/pagy/resources/initializer/

############ Global Options ################################################################
# See https://ddnexus.github.io/pagy/toolbox/options/ for details.
# Add your global options below. They will be applied globally.
# For example:
#
# Pagy.options[:limit] = 10               # Limit the items per page
# Pagy.options[:client_max_limit] = 100   # The client can request a limit up to 100
# Pagy.options[:max_pages] = 200          # Allow only 200 pages
# Pagy.options[:jsonapi] = true           # Use JSON:API compliant URLs

############ JavaScript ####################################################################
# See https://ddnexus.github.io/pagy/resources/javascript/ for details.
# Examples for Rails:
# For apps with an assets pipeline
# Rails.application.config.assets.paths << Pagy::ROOT.join('javascripts')
#
# For apps with a javascript builder (e.g. esbuild, webpack, etc.)
# javascript_dir = Rails.root.join('app/javascript')
# Pagy.sync_javascript(javascript_dir, 'pagy.mjs') if Rails.env.development?

############# Overriding Pagy::I18n Lookup #################################################
# Refer to https://ddnexus.github.io/pagy/resources/i18n/ for details.
# Override the dictionary lookup for customization by dropping your customized
# Example for Rails:
#
# Pagy::I18n.pathnames << Rails.root.join('config/locales')

############# I18n Gem Translation #########################################################
# See https://ddnexus.github.io/pagy/resources/i18n/ for details.
#
# Pagy.translate_with_the_slower_i18n_gem!

############# Calendar Localization for non-en locales ####################################
# See https://ddnexus.github.io/pagy/toolbox/paginators/calendar#localization for details.
# Add your desired locales to the list and uncomment the following line to enable them,
# regardless of whether you use the I18n gem for translations or not, whether with
# Rails or not.
#
# Pagy::Calendar.localize_with_rails_i18n_gem(*your_locales)

############# Pagination Options ###############################################
# Configure default pagination behavior and client-customizable page sizes.
# IMPORTANT: client_max_limit is required to allow clients to customize page
# size via URL params.  Without it, the limit_key parameter will be completely
# ignored.

# Maximum page size clients can request. If falsey/nil, clients cannot customize page size at all.
Pagy.options[:client_max_limit] = 1000

# Default number of items per page (used when client doesn't specify a page size)
Pagy.options[:limit] = 10

# URL parameter name that clients use to customize page size (e.g., ?page_size=100)
Pagy.options[:limit_key] = "page_size"
