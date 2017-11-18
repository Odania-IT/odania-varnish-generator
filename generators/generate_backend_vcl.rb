module Varnish
	class GenerateBackendVcl
		attr_accessor :backends, :live_color, :template

		def initialize(backends, live_color)
			self.backends = backends
			self.live_color = live_color
			self.template = File.new("#{VARNISH_BASE_DIR}/templates/backend.vcl.erb").read
		end

		def sanitize_name(name)
			name.gsub(/[^0-9a-zA-Z_]/, '_')[0, 60]
		end

		def default_backend
			backends[live_color.to_sym].first
		end

		def director_name(color_or_service)
			return color_or_service.to_s.eql?(live_color) ? 'live' : 'staging' if [:blue, :green].include? color_or_service
			color_or_service
		end

		def render
			Erubis::Eruby.new(self.template).result(binding)
		end

		def write(out_dir)
			File.write("#{out_dir}/backend.vcl", self.render)
		end
	end
end
