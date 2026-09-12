# The tray application entry point. `src/matter_media.cr` is the library: it is
# what the specs require, and it must stay loadable on a platform that has no
# tray to run.
require "./matter_media"

{% if flag?(:win32) %}
  require "./matter_media/windows"

  MatterMedia.setup_logging

  backend = MatterMedia::Windows::MediaBackend.new
  display = MatterMedia::Windows::CommissioningWindow.new
  device = MatterMedia::Matter::MediaDevice.new(backend, display)
  display.on_commissioning_closed = -> do
    device.shutdown!
    exit(0)
  end

  device.start
  MatterMedia::Windows::TrayApp.run
  device.shutdown!
{% else %}
  STDERR.puts "matter_media is only supported on Windows."
  exit 1
{% end %}
