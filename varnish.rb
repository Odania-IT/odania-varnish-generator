require 'fileutils'
require_relative 'generators/generate_backend_vcl'
require_relative 'generators/generate_default_vcl'
require_relative 'generators/generate_final_vcl'
require_relative 'generators/generate_general_vcl'
require_relative 'generators/generate_redirects_vcl'
require_relative 'generators/generate_services_vcl'
require_relative 'generators/generate_websocket_vcl'

module Varnish
	class Base
		def initialize(redis)
			@redis = redis
		end

		def generate(current_color, backends, out_dir)
			new_color = 'green'.eql?(current_color) ? 'blue' : 'green'
			FileUtils.mkdir_p out_dir unless File.directory? out_dir

			puts "Generate config for color: #{new_color}"

			# Generate catch all vcl
			gen = ::Varnish::GenerateGeneralVcl.new
			gen.write(out_dir)

			# Generate backend vcl
			gen = ::Varnish::GenerateBackendVcl.new(backends, new_color)
			gen.write(out_dir)

			# Load old redirect cfg
			redirects = YAML.load_file File.join(BASE_DIR, 'redirects.yml')

			# Generate global redirects
			gen = ::Varnish::GenerateRedirectsVcl.new(redirects)
			gen.write(out_dir)

			# Generate main vcl
			gen = ::Varnish::GenerateDefaultVcl.new
			gen.write(out_dir)

			# Generate final vcl
			gen = ::Varnish::GenerateFinalVcl.new
			gen.write(out_dir)

			# Generate websocket vcl
			gen = ::Varnish::GenerateWebsocketVcl.new
			gen.write(out_dir)

			# Generate services vcl
			services_content_file = File.join(BASE_DIR, 'services_content.vcl')
			services_content = ''
			services_content = File.read services_content_file if File.exist? services_content_file
			gen = ::Varnish::GenerateServicesVcl.new(services_content)
			gen.write(out_dir)

			@redis.set $live_color_key, new_color
			puts
			new_color
		end

		def reload_config(varnish_servers)
			$logger.info 'Updating varnish config'
			$varnish_version += 1

			$logger.info "Setting redis octopress-varnish-version to #{$varnish_version}"
			@redis.set $varnish_version_key, $varnish_version

			varnish_servers.each do |host_ip|
				cmd = "varnishadm -T #{host_ip}:9876 -S /srv/varnish-secret vcl.load reload#{$varnish_version} /etc/varnish/default.vcl"
				$logger.info "CMD: #{cmd}"
				$logger.info `#{cmd}`
				cmd = "varnishadm -T #{host_ip}:9876 -S /srv/varnish-secret vcl.use reload#{$varnish_version}"
				$logger.info "CMD: #{cmd}"
				$logger.info `#{cmd}`
			end

			handle_cleanup $varnish_version
		end

		def handle_cleanup(current_number)
			# Set current minimal
			@redis.set $varnish_version_min_keep_key, current_number - 2
		end

		def loaded_varnish_config_versions(varnish_servers)
			result = []
			varnish_servers.each do |host_ip|
				cmd = "varnishadm -T #{host_ip}:9876 -S /srv/varnish-secret vcl.list"
				$logger.info "CMD: #{cmd}"
				`#{cmd}`.split("\n").each do |config|
					config_name = config.split(' ').last
					result << config_name.gsub('reload', '').to_i if config_name.start_with? 'reload'
				end
			end

			result
		end

		def remove_varnish_config(varnish_servers, name)
			$logger.info "Removing varnish config #{name}"
			varnish_servers.each do |host_ip|
				cmd = "varnishadm -T #{host_ip}:9876 -S /srv/varnish-secret vcl.discard #{name}"
				$logger.info "CMD: #{cmd}"
				`#{cmd}`.split("\n").each do |config|
					config_name = config.split(' ').last
					result << config_name.gsub('reload', '').to_i if config_name.start_with? 'reload'
				end
			end
		end

		def remove_old_configs(varnish_servers, remove_up_to_version)
			config_versions = loaded_varnish_config_versions varnish_servers
			config_versions.each do |config_version|
				remove_varnish_config(varnish_servers, "reload#{config_version}") if remove_up_to_version > config_version
			end
		end
	end
end
