module Varnish
	class GenerateWebsocketVcl
		attr_accessor :template

		def initialize
			self.template = File.new("#{VARNISH_BASE_DIR}/templates/websocket.vcl.erb").read
		end

		def render
			Erubis::Eruby.new(self.template).result(binding)
		end

		def write(out_dir)
			File.write("#{out_dir}/websocket.vcl", self.render)
		end
	end
end
