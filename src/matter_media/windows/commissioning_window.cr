require "goban"

require "./win32"
require "../matter/commissioning_display"

module MatterMedia
  module Windows
    class CommissioningWindow
      include MatterMedia::Matter::CommissioningDisplay

      TITLE = "Matter Media Pairing"

      BORDER_MODULES =  4
      MODULE_SIZE    =  6
      PADDING        = 16
      HEADER_HEIGHT  = 32
      FOOTER_HEIGHT  = 96

      @@class_name = Win32::WString.new("MatterMediaCommissioning")
      @@window_name = Win32::WString.new(TITLE)
      @@registered = false
      @@instance : CommissioningWindow? = nil

      @hwnd : Win32::HWND
      @info : MatterMedia::Matter::CommissioningInfo?
      @qr_canvas : Goban::Canvas(UInt8)?
      @qr_size : Int32
      @qr_pixel_size : Int32
      @window_width : Int32
      @window_height : Int32
      @qr_origin_x : Int32
      @qr_origin_y : Int32
      @header_rect : Win32::RECT
      @footer_rect : Win32::RECT
      @commissioning_active : Bool
      @on_commissioning_closed : Proc(Nil)?

      {% if flag?(:x86_64) %}
        LRESULT_OK = 0_i64
      {% else %}
        LRESULT_OK = 0_i32
      {% end %}

      WNDPROC = ->(hwnd : Win32::HWND, msg : Win32::UINT, wparam : Win32::WPARAM, lparam : Win32::LPARAM) : Win32::LRESULT {
        case msg
        when Win32::WM_PAINT
          CommissioningWindow.paint(hwnd)
          return LRESULT_OK
        when Win32::WM_CLOSE
          CommissioningWindow.handle_close
          return LRESULT_OK
        else
        end

        Win32::LibUser32.DefWindowProcW(hwnd, msg, wparam, lparam)
      }

      def initialize
        @hwnd = Pointer(Void).null
        @info = nil
        @qr_canvas = nil
        @qr_size = 0
        @qr_pixel_size = 0
        @window_width = 0
        @window_height = 0
        @qr_origin_x = 0
        @qr_origin_y = 0
        @header_rect = Win32::RECT.new
        @footer_rect = Win32::RECT.new
        @commissioning_active = false
        @on_commissioning_closed = nil
      end

      def on_commissioning_closed=(callback : Proc(Nil)?) : Nil
        @on_commissioning_closed = callback
      end

      def show(info : MatterMedia::Matter::CommissioningInfo) : Nil
        @@instance = self
        @info = info
        @commissioning_active = true

        qr = Goban::QR.encode_string(info.qr_code_payload, Goban::ECC::Level::Low)
        @qr_canvas = qr.canvas
        @qr_size = qr.size

        update_layout
        ensure_window

        Win32::LibUser32.MoveWindow(@hwnd, 0, 0, @window_width, @window_height, 1)
        Win32::LibUser32.ShowWindow(@hwnd, Win32::SW_SHOW)
        Win32::LibUser32.SetForegroundWindow(@hwnd)
        Win32::LibUser32.UpdateWindow(@hwnd)
        Win32::LibUser32.InvalidateRect(@hwnd, Pointer(Win32::RECT).null, 1)
      end

      def hide : Nil
        return if @hwnd.null?
        Win32::LibUser32.ShowWindow(@hwnd, Win32::SW_HIDE)
        @commissioning_active = false
      end

      def self.paint(hwnd : Win32::HWND) : Nil
        @@instance.try &.paint_window(hwnd)
      end

      def self.hide_window : Nil
        @@instance.try &.hide
      end

      def self.handle_close : Nil
        @@instance.try &.handle_close
      end

      private def ensure_window : Nil
        return unless @hwnd.null?

        hinstance = Win32::LibKernel32.GetModuleHandleW(Pointer(UInt16).null)
        register_class(hinstance)

        @hwnd = Win32::LibUser32.CreateWindowExW(
          Win32::WS_EX_TOPMOST | Win32::WS_EX_DLGMODALFRAME,
          @@class_name.to_unsafe,
          @@window_name.to_unsafe,
          Win32::WS_OVERLAPPEDWINDOW,
          0, 0, @window_width, @window_height,
          Pointer(Void).null,
          Pointer(Void).null,
          hinstance,
          Pointer(Void).null
        )
        raise "CreateWindowExW failed" if @hwnd.null?
      end

      def handle_close : Nil
        if @commissioning_active
          if callback = @on_commissioning_closed
            callback.call
          else
            exit(0)
          end
        else
          hide
        end
      end

      private def register_class(hinstance : Win32::HINSTANCE) : Nil
        return if @@registered

        wc = Win32::WNDCLASSEXW.new
        wc.cbSize = sizeof(Win32::WNDCLASSEXW).to_u32
        wc.style = (Win32::CS_HREDRAW | Win32::CS_VREDRAW)
        wc.lpfnWndProc = WNDPROC
        wc.hInstance = hinstance
        wc.hIcon = Win32::LibUser32.LoadIconW(Pointer(Void).null, Win32.make_int_resource(Win32::IDI_APPLICATION))
        wc.hIconSm = wc.hIcon
        wc.lpszClassName = @@class_name.to_unsafe

        atom = Win32::LibUser32.RegisterClassExW(pointerof(wc))
        raise "RegisterClassExW failed" if atom == 0
        @@registered = true
      end

      private def update_layout : Nil
        @qr_pixel_size = (@qr_size + (BORDER_MODULES * 2)) * MODULE_SIZE
        @window_width = @qr_pixel_size + (PADDING * 2)
        @window_height = @qr_pixel_size + (PADDING * 2) + HEADER_HEIGHT + FOOTER_HEIGHT
        @qr_origin_x = PADDING
        @qr_origin_y = PADDING + HEADER_HEIGHT

        @header_rect = Win32::RECT.new
        @header_rect.left = PADDING
        @header_rect.top = PADDING
        @header_rect.right = PADDING + @qr_pixel_size
        @header_rect.bottom = PADDING + HEADER_HEIGHT

        @footer_rect = Win32::RECT.new
        @footer_rect.left = PADDING
        @footer_rect.top = @qr_origin_y + @qr_pixel_size
        @footer_rect.right = PADDING + @qr_pixel_size
        @footer_rect.bottom = @footer_rect.top + FOOTER_HEIGHT
      end

      def paint_window(hwnd : Win32::HWND) : Nil
        info = @info
        canvas = @qr_canvas
        return unless info && canvas

        paint = uninitialized Win32::PAINTSTRUCT
        hdc = Win32::LibUser32.BeginPaint(hwnd, pointerof(paint))

        client = uninitialized Win32::RECT
        Win32::LibUser32.GetClientRect(hwnd, pointerof(client))

        white_brush = Win32::LibGdi32.CreateSolidBrush(Win32.rgb(255_u8, 255_u8, 255_u8))
        Win32::LibUser32.FillRect(hdc, pointerof(client), white_brush)
        Win32::LibGdi32.DeleteObject(white_brush)

        Win32::LibGdi32.SetBkMode(hdc, Win32::TRANSPARENT)
        Win32::LibGdi32.SetTextColor(hdc, Win32.rgb(0_u8, 0_u8, 0_u8))

        draw_text(hdc, "#{info.device_name} Pairing", @header_rect)

        draw_qr(hdc, canvas)

        footer_text = "Scan the QR code with your Matter controller app.\nManual Code: #{info.manual_code}"
        draw_text(hdc, footer_text, @footer_rect)

        Win32::LibUser32.EndPaint(hwnd, pointerof(paint))
      end

      private def draw_qr(hdc : Win32::HDC, canvas : Goban::Canvas(UInt8)) : Nil
        black_brush = Win32::LibGdi32.CreateSolidBrush(Win32.rgb(0_u8, 0_u8, 0_u8))
        start_x = @qr_origin_x + (BORDER_MODULES * MODULE_SIZE)
        start_y = @qr_origin_y + (BORDER_MODULES * MODULE_SIZE)
        rect = Win32::RECT.new
        size = canvas.size
        module_size = MODULE_SIZE

        size.times do |y|
          size.times do |x|
            next unless (canvas[x, y] & 1) == 1
            rect.left = start_x + x * module_size
            rect.top = start_y + y * module_size
            rect.right = rect.left + module_size
            rect.bottom = rect.top + module_size
            Win32::LibUser32.FillRect(hdc, pointerof(rect), black_brush)
          end
        end

        Win32::LibGdi32.DeleteObject(black_brush)
      end

      private def draw_text(hdc : Win32::HDC, text : String, rect : Win32::RECT) : Nil
        local = rect
        wstr = Win32::WString.new(text)
        Win32::LibUser32.DrawTextW(
          hdc,
          wstr.to_unsafe,
          -1,
          pointerof(local),
          Win32::DT_CENTER | Win32::DT_WORDBREAK | Win32::DT_NOPREFIX
        )
      end
    end
  end
end
