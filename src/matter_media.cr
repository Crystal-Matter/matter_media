require "log"
require "./matter_media/matter"

module MatterMedia
  {% begin %}
    VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify.downcase }}
  {% end %}

  def self.setup_logging : Nil
    log_path = ENV["MATTER_MEDIA_LOG_FILE"]?
    io = if log_path && !log_path.empty?
           begin
             File.open(log_path, "a")
           rescue
             STDOUT
           end
         else
           STDOUT
         end
    backend = Log::IOBackend.new(io)
    Log.setup_from_env(default_level: :error, backend: backend)
  end
end

{% if flag?(:win32) %}
  require "./matter_media/windows"
  MatterMedia.setup_logging

  backend = MatterMedia::Windows::MediaBackend.new
  display = MatterMedia::Windows::CommissioningWindow.new
  device = MatterMedia::Matter::MediaDevice.new(backend, display)
  display.on_commissioning_closed = -> do
    device.stop
    exit(0)
  end

  device.start
  MatterMedia::Windows::TrayApp.run
  device.stop
{% else %}
  STDERR.puts "matter_media_tray is only supported on Windows."
  exit 1
{% end %}
