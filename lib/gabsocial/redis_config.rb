# frozen_string_literal: true

def setup_redis_env_url(prefix = nil, defaults = true)
  prefix = prefix.to_s.upcase + '_' unless prefix.nil?
  prefix = '' if prefix.nil?

  return if ENV[prefix + 'REDIS_URL'].present?

  password  = ENV.fetch(prefix + 'REDIS_PASSWORD') { '' if defaults }
  host      = ENV.fetch(prefix + 'REDIS_HOST') { 'localhost' if defaults }
  port      = ENV.fetch(prefix + 'REDIS_PORT') { 6379 if defaults }
  db        = ENV.fetch(prefix + 'REDIS_DB') { 0 if defaults }

  ENV[prefix + 'REDIS_URL'] = if [password, host, port, db].all?(&:nil?)
                                ENV['REDIS_URL']
                              else
                                "redis://#{password.blank? ? '' : ":#{password}@"}#{host}:#{port}/#{db}"
                              end
end

setup_redis_env_url
setup_redis_env_url(:cache, false)

namespace       = ENV.fetch('REDIS_NAMESPACE') { nil }
cache_namespace = namespace ? namespace + '_cache' : 'cache'
pool_size = ENV.fetch('REDIS_POOL_SIZE') { 5 }

REDIS_CACHE_PARAMS = {
  expires_in: 10.minutes,
  namespace: cache_namespace,
  pool_size: pool_size,
}.freeze
