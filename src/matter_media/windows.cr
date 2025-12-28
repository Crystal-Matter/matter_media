{% if flag?(:win32) %}
  require "./windows/win32"
  require "./windows/media_control"
  require "./windows/tray_app"
{% end %}
