#!/usr/bin/env ruby
require 'active_support/all'
require 'em-hiredis'
require 'erubis'
require 'logger'
require 'yaml'
require_relative 'discovery'
require_relative 'varnish'

BASE_DIR = File.absolute_path File.join File.dirname(__FILE__)

trap(:INT) {puts; exit}

$environment = ENV['ENVIRONMENT'].nil? ? 'production' : ENV['ENVIRONMENT']
$local_test_mode = false
$out_dir = ENV['OUT_DIR'].nil? ? '/tmp/varnish-templates' : ENV['OUT_DIR']
$logger = Logger.new(STDOUT)
$varnish_version_key = 'production:varnish-version'
$live_color_key = 'production:live-color'
$varnish_version_min_keep_key = 'production:varnish-version-min-keep'
$config = YAML.load_file File.join(BASE_DIR, 'config.yml')
$environment_config = $config['environments'][$environment]

redis_url = $environment_config['redis_url']
redis_url = ENV['REDIS_URL'].nil? ? redis_url : "redis://#{ENV['REDIS_URL']}"

$logger.info "Starting Varnish Generator [Environment: #{$environment}]"
discovery_helper = "Discovery::#{$environment_config['discovery_helper']}".constantize.new

def update_varnish_config(current_color, discovery_helper, redis)
	varnish_helper = Varnish::Base.new redis

	current_color = current_color.nil? ? 'blue' : current_color
	$logger.info "Updating Varnish Config [Current Color: #{current_color}]"
	varnish_helper.generate current_color, $backends, $out_dir

	varnish_servers = discovery_helper.varnish_servers
	$logger.info "Detected Varnish Servers: #{varnish_servers}"

	varnish_helper.reload_config varnish_servers
end

# Create first varnish config
$backends = discovery_helper.get_backends
$varnish_version = 0

EventMachine.run do
	redis = EM::Hiredis.connect redis_url
	pubsub = redis.pubsub
	pubsub.subscribe('octopress').callback {$logger.info 'Subscribed to redis channel'}

	pubsub.on(:message) do |channel, message|
		p [:message, channel, message]
	end

	response_deferrable = redis.get($varnish_version_key)
	response_deferrable.callback do |value|
		$varnish_version = value.to_i
		$logger.info "Varnish Version #{$varnish_version}"

		$logger.info "Updating Varnish with current backends: #{$backends.inspect}"
		redis.get($live_color_key) do |current_color|
			update_varnish_config(current_color, discovery_helper, redis)
		end
	end
	response_deferrable.errback do |e|
		$logger.error "Error redis get: #{e}"

		$logger.info "Updating Varnish with current backends: #{$backends.inspect}"
		redis.get($live_color_key) do |current_color|
			update_varnish_config(current_color, discovery_helper, redis)
		end
	end

	EM.add_periodic_timer(60) do
		begin
			$logger.info 'Looking for new Servers in Rancher'

			new_backends = discovery_helper.get_backends
			unless $backends.eql? new_backends
				$logger.info "Backends changed! Reloading! #{$backends.inspect}"
				$backends = new_backends
				redis.get($live_color_key) do |current_color|
					update_varnish_config(current_color, discovery_helper, redis)
				end
			end
		rescue => e
			$logger.error "Error occurect during server check: #{e}"
			$logger.error e.backtrace.join("\n")
		end
	end

	EM.add_periodic_timer(300) do
		begin
			redis.get($varnish_version_min_keep_key) do |value|
				varnish_helper = Varnish::Base.new redis
				varnish_helper.remove_old_configs discovery_helper.varnish_servers, value.to_i
			end
		rescue => e
			$logger.error "Error occurect during varnish config cleanup: #{e}"
			$logger.error e.backtrace.join("\n")
		end
	end
end
