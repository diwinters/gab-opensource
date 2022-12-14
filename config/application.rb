require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

require_relative '../lib/exceptions'
require_relative '../lib/paperclip/lazy_thumbnail'
require_relative '../lib/paperclip/gif_transcoder'
require_relative '../lib/paperclip/video_transcoder'
require_relative '../lib/paperclip/type_corrector'
require_relative '../lib/gabsocial/snowflake'
require_relative '../lib/gabsocial/version'
require_relative '../lib/devise/ldap_authenticatable'

Dotenv::Railtie.load

Bundler.require(:pam_authentication) if ENV['PAM_ENABLED'] == 'true'

require_relative '../lib/gabsocial/redis_config'

module GabSocial
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.0
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # All translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    config.i18n.available_locales = [
      :en,
      :ar,
      :ast,
      :bg,
      :bn,
      :ca,
      :co,
      :cs,
      :cy,
      :da,
      :de,
      :el,
      :eo,
      :es,
      :eu,
      :fa,
      :fi,
      :fr,
      :ga,
      :gl,
      :he,
      :hi,
      :hr,
      :hu,
      :hy,
      :id,
      :io,
      :it,
      :ja,
      :ka,
      :kk,
      :ko,
      :lt,
      :lv,
      :ms,
      :nl,
      :no,
      :oc,
      :pl,
      :pt,
      :'pt-BR',
      :ro,
      :ru,
      :sk,
      :sl,
      :sq,
      :sr,
      :'sr-Latn',
      :sv,
      :ta,
      :te,
      :th,
      :tr,
      :uk,
      :'zh-CN',
      :'zh-HK',
      :'zh-TW',
    ]

    config.i18n.default_locale = ENV['DEFAULT_LOCALE']&.to_sym

    unless config.i18n.available_locales.include?(config.i18n.default_locale)
      config.i18n.default_locale = :en
    end

    # config.paths.add File.join('app', 'api'), glob: File.join('**', '*.rb')
    # config.autoload_paths += Dir[Rails.root.join('app', 'api', '*')]

    config.active_job.queue_adapter = :sidekiq

    config.to_prepare do
      Doorkeeper::AuthorizationsController.layout 'modal'
      Doorkeeper::AuthorizedApplicationsController.layout 'admin'
      Doorkeeper::Application.send :include, ApplicationExtension
      Devise::FailureApp.send :include, AbstractController::Callbacks
      Devise::FailureApp.send :include, HttpAcceptLanguage::EasyAccess
      Devise::FailureApp.send :include, Localized
    end
  end
end
