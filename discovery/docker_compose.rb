module Discovery
	class DockerCompose
		def get_backends
			{
				green: [
					{
						name: 'nginx-green',
						ip: 'nginx',
						port: 8080,
						uuid: 'uuid1'
					}
				],
				blue: [
					{
						name: 'nginx-blue',
						ip: 'nginx',
						port: 8080,
						uuid: 'uuid2'
					}
				]
			}.merge $environment_config['extra_backends']
		end

		def varnish_servers
			['varnish']
		end
	end
end
