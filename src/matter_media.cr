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
