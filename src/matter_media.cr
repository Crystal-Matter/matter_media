module MatterMedia
  {% begin %}
    VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify.downcase }}
  {% end %}
end

{% if flag?(:win32) %}
  require "./matter_media/windows"
  MatterMedia::Windows::TrayApp.run
{% else %}
  STDERR.puts "matter_media_tray is only supported on Windows."
  exit 1
{% end %}
