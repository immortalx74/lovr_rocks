App = require("App")

function lovr.conf(t)
	-- t.headset.drivers = { 'openxr', 'oculus', 'openvr', 'desktop' }
	-- t.headset.drivers = { 'desktop'}
	-- t.headset.drivers = { 'oculus'}
	-- t.window.width = 1296
	-- t.window.height = 720
	-- t.window.vsync = 0
	App.driver = t.headset.drivers
end
