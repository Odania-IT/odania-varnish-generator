module Varnish
	class GenerateRedirectsVcl
		attr_accessor :redirects, :template

		def initialize(redirects)
			self.redirects = redirects
			self.template = File.new("#{VARNISH_BASE_DIR}/templates/redirects.vcl.erb").read
		end

		def render
			Erubis::Eruby.new(self.template).result(binding)
		end

		def write(out_dir)
			File.write("#{out_dir}/redirects.vcl", self.render)
		end
	end
end
