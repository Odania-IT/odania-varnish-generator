module Varnish
	class GenerateGeneralVcl
		attr_accessor :template

		def initialize
			self.template = File.new("#{VARNISH_BASE_DIR}/templates/general.vcl.erb").read
		end

		def render
			Erubis::Eruby.new(self.template).result(binding)
		end

		def write(out_dir)
			File.write("#{out_dir}/general.vcl", self.render)
		end
	end
end
