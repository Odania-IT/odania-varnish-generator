module Varnish
	class GenerateServicesVcl
		attr_accessor :template, :services_content

		def initialize(services_content)
			self.template = File.new("#{VARNISH_BASE_DIR}/templates/services.vcl.erb").read
			self.services_content = services_content
		end

		def render
			Erubis::Eruby.new(self.template).result(binding)
		end

		def write(out_dir)
			File.write("#{out_dir}/services.vcl", self.render)
		end
	end
end
