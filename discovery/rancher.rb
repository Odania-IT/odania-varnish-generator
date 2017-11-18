#!/usr/bin/env ruby
require 'rancher/api'

Rancher::Api.setup!
$rancher_environment = ENV['RANCHER_ENVIRONMENT']

module Discovery
	class Rancher
		def get_backends
			backends = Hash.new {|k, v| k[v] = []}
			sorted_instances.each_pair do |color, instances|
				#puts "Color: #{color}"
				instances.each do |instance|
					#puts "Instance Name: #{instance.name}"

					backends[color.to_sym] << {
						name: instance.name,
						ip: instance.primaryIpAddress,
						port: 8080,
						uuid: instance.uuid
					}
				end
			end

			backends.merge production_services
		end

		def production_services
			result = Hash.new {|k, v| k[v] = []}
			environment = find_environment 'production-services-all'
			return result if environment.nil?

			environment.services.each do |service|
				service.instances.each do |instance|
					result[service.name] << {
						name: instance.name,
						ip: instance.primaryIpAddress,
						port: 8080,
						uuid: instance.uuid
					}
				end
			end

			result
		end

		def varnish_servers
			result = []

			environment = find_environment 'octopress-varnish-all'

			#puts "Environment: #{environment}"
			environment.services.each do |service|
				#puts service.name
				next unless 'varnish'.eql? service.name

				service.instances.each do |instance|
					result << instance.primaryIpAddress
				end
			end

			result
		end

		private

		def find_environment(name)
			Rancher::Api::Project.all.each do |project|
				#puts "Project: #{project.name}"
				next if !ENV['RANCHER_ENVIRONMENT'].nil? && !ENV['RANCHER_ENVIRONMENT'].eql?(project.name)

				project.environments.each do |environment|
					#puts " -> Environment: #{environment.name}"
					return environment if environment.name.to_s.eql? name
				end
			end

			nil
		end

		def sorted_instances
			sorted_instances = Hash.new {|k, v| k[v] = []}
			environment = find_environment('octopress-all')

			#puts "Environment: #{environment}"
			environment.services.each do |service|
				#puts service.name
				sorted_instances[service.name] += service.instances
			end

			sorted_instances
		end
	end
end
