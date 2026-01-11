require "log"
require "./win32"
require "./media_control"

module MatterMedia
  module Windows
    module TrayApp
      TRAY_UID     = 1_u32
      TRAY_MESSAGE = Win32::WM_USER + 1_u32

      ID_PLAY_PAUSE = 1001_u16
      ID_NEXT       = 1002_u16
      ID_PREV       = 1003_u16
      ID_STOP       = 1004_u16
      ID_VOL_LEVEL  = 1100_u16
      ID_VOL_UP     = 1101_u16
      ID_VOL_DOWN   = 1102_u16
      ID_MUTE       = 1103_u16
      ID_EXIT       = 1999_u16

      TIMER_ID         =   1_u32
      POLL_INTERVAL_MS = 500_u32

      @@class_name = Win32::WString.new("MatterMediaTray")
      @@window_name = Win32::WString.new("MatterMediaTray")
      @@tooltip = "Matter Media Controls"

      @@tray_data = Win32::NOTIFYICONDATAW.new
      @@tray_data_set = false
      @@menu_handle : Win32::HMENU = Pointer(Void).null
      @@menu_owner : Win32::HWND = Pointer(Void).null
      @@timer_proc : Win32::TimerProc? = nil

      Log = ::Log.for(self)

      {% if flag?(:x86_64) %}
        LRESULT_OK = 0_i64
      {% else %}
        LRESULT_OK = 0_i32
      {% end %}

      WNDPROC = ->(hwnd : Win32::HWND, msg : Win32::UINT, wparam : Win32::WPARAM, lparam : Win32::LPARAM) : Win32::LRESULT {
        case msg
        when TRAY_MESSAGE
          msg_code = (lparam.to_u64 & 0xFFFF_u64).to_u32
          Log.debug { "tray: lparam=0x#{lparam.to_u32.to_s(16)} wparam=#{wparam} msg_code=0x#{msg_code.to_s(16)}" }
          case msg_code
          when Win32::WM_RBUTTONDOWN, Win32::WM_RBUTTONUP, Win32::WM_CONTEXTMENU, Win32::NIN_SELECT, Win32::NIN_KEYSELECT
            show_context_menu(hwnd)
            return LRESULT_OK
          when Win32::WM_LBUTTONDBLCLK
            MediaControl.toggle
            return LRESULT_OK
          else
            return LRESULT_OK
          end
        when Win32::WM_COMMAND
          cmd = Win32.loword(wparam)
          case cmd
          when ID_PLAY_PAUSE then MediaControl.play_pause
          when ID_NEXT       then MediaControl.next_track
          when ID_PREV       then MediaControl.previous_track
          when ID_STOP       then MediaControl.stop
          when ID_VOL_UP     then MediaControl.volume_up
          when ID_VOL_DOWN   then MediaControl.volume_down
          when ID_MUTE       then MediaControl.mute_toggle
          when ID_EXIT       then Win32::LibUser32.DestroyWindow(hwnd)
          else
          end
          return LRESULT_OK
        when Win32::WM_CLOSE
          Win32::LibUser32.DestroyWindow(hwnd)
          return LRESULT_OK
        when Win32::WM_DESTROY
          if @@tray_data_set
            data = @@tray_data
            Win32::LibShell32.Shell_NotifyIconW(Win32::NIM_DELETE, pointerof(data))
          end
          Win32::LibUser32.KillTimer(hwnd, TIMER_ID)
          Win32::LibUser32.PostQuitMessage(0)
          return LRESULT_OK
        else
        end

        Win32::LibUser32.DefWindowProcW(hwnd, msg, wparam, lparam)
      }

      def self.run : Nil
        hinstance = Win32::LibKernel32.GetModuleHandleW(Pointer(UInt16).null)
        Log.debug { "tray: started pid=#{Process.pid}" }

        MediaControl.on_mute_state do |muted|
          update_mute_menu_label(muted)
        end

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

        hwnd = Win32::LibUser32.CreateWindowExW(
          Win32::WS_EX_TOOLWINDOW,
          @@class_name.to_unsafe,
          @@window_name.to_unsafe,
          Win32::WS_POPUP,
          0, 0, 0, 0,
          Pointer(Void).null,
          Pointer(Void).null,
          hinstance,
          Pointer(Void).null
        )
        raise "CreateWindowExW failed" if hwnd.null?

        Win32::LibUser32.ShowWindow(hwnd, Win32::SW_HIDE)
        Win32::LibUser32.UpdateWindow(hwnd)

        add_tray_icon(hwnd, wc.hIcon)
        @@timer_proc = ->(handle : Win32::HWND, _msg : Win32::UINT, _id : Win32::UINT_PTR, _time : Win32::DWORD) do
          MediaControl.poll
        end
        Win32::LibUser32.SetTimer(hwnd, TIMER_ID, POLL_INTERVAL_MS, @@timer_proc.not_nil!)
        Log.debug { "tray: icon added" }

        msg = uninitialized Win32::MSG
        loop do
          while Win32::LibUser32.PeekMessageW(pointerof(msg), Pointer(Void).null, 0_u32, 0_u32, Win32::PM_REMOVE) > 0
            if msg.message == Win32::WM_QUIT
              return
            end
            Win32::LibUser32.TranslateMessage(pointerof(msg))
            Win32::LibUser32.DispatchMessageW(pointerof(msg))
          end
          sleep 10.milliseconds
        end

        nil
      end

      private def self.add_tray_icon(hwnd : Win32::HWND, hicon : Win32::HICON) : Nil
        data = Win32::NOTIFYICONDATAW.new

        data.cbSize = sizeof(Win32::NOTIFYICONDATAW).to_u32
        data.hWnd = hwnd
        data.uID = TRAY_UID
        data.uFlags = (Win32::NIF_MESSAGE | Win32::NIF_ICON | Win32::NIF_TIP)
        data.uCallbackMessage = TRAY_MESSAGE
        data.hIcon = hicon
        tip = data.szTip
        Win32.copy_wstr(pointerof(tip).as(Pointer(UInt16)), 128, @@tooltip)
        data.szTip = tip

        ok = Win32::LibShell32.Shell_NotifyIconW(Win32::NIM_ADD, pointerof(data))
        raise "Shell_NotifyIconW(NIM_ADD) failed" if ok == 0

        data.uTimeoutOrVersion = Win32::NOTIFYICON_VERSION_4
        Win32::LibShell32.Shell_NotifyIconW(Win32::NIM_SETVERSION, pointerof(data))
        Log.debug { "tray: set version 4" }

        @@tray_data = data
        @@tray_data_set = true
        nil
      end

      private def self.show_context_menu(hwnd : Win32::HWND) : Nil
        pt = uninitialized Win32::POINT
        Win32::LibUser32.GetCursorPos(pointerof(pt))

        menu = Win32::LibUser32.CreatePopupMenu
        raise "CreatePopupMenu failed" if menu.null?
        @@menu_handle = menu
        @@menu_owner = hwnd

        append_menu(menu, ID_PLAY_PAUSE, playback_label)
        append_menu(menu, ID_NEXT, "Next")
        append_menu(menu, ID_PREV, "Previous")
        append_menu(menu, ID_STOP, "Stop")
        Win32::LibUser32.AppendMenuW(menu, Win32::MF_SEPARATOR, 0_u64, Pointer(UInt16).null)
        append_menu(menu, ID_VOL_LEVEL, volume_label, Win32::MF_STRING | Win32::MF_DISABLED | Win32::MF_GRAYED)
        append_menu(menu, ID_VOL_UP, "Volume Up")
        append_menu(menu, ID_VOL_DOWN, "Volume Down")
        append_menu(menu, ID_MUTE, mute_label)
        Win32::LibUser32.AppendMenuW(menu, Win32::MF_SEPARATOR, 0_u64, Pointer(UInt16).null)
        append_menu(menu, ID_EXIT, "Exit")

        Win32::LibUser32.SetForegroundWindow(hwnd)
        Win32::LibUser32.TrackPopupMenu(menu, Win32::TPM_RIGHTBUTTON, pt.x, pt.y, 0, hwnd, Pointer(Win32::RECT).null)
        Win32::LibUser32.PostMessageW(hwnd, Win32::WM_NULL, 0, 0)
        @@menu_handle = Pointer(Void).null
        @@menu_owner = Pointer(Void).null
        Win32::LibUser32.DestroyMenu(menu)
        nil
      end

      private def self.append_menu(menu : Win32::HMENU, id : UInt16, label : String, flags : UInt32 = Win32::MF_STRING) : Nil
        w = Win32::WString.new(label)
        Win32::LibUser32.AppendMenuW(menu, flags, id.to_u64, w.to_unsafe)
        nil
      end

      private def self.playback_label : String
        case MediaControl.playback_state
        when MediaControl::PlaybackState::Playing
          "Pause"
        when MediaControl::PlaybackState::Paused, MediaControl::PlaybackState::Stopped, MediaControl::PlaybackState::Opened
          "Play"
        else
          "Play/Pause"
        end
      end

      private def self.volume_label : String
        "Volume: #{MediaControl.volume_percent}%"
      end

      private def self.mute_label : String
        MediaControl.mute? ? "Unmute" : "Mute"
      end

      private def self.update_mute_menu_label(muted : Bool) : Nil
        menu = @@menu_handle
        return if menu.null?
        label = muted ? "Unmute" : "Mute"
        w = Win32::WString.new(label)
        Win32::LibUser32.ModifyMenuW(
          menu,
          ID_MUTE.to_u32,
          Win32::MF_BYCOMMAND | Win32::MF_STRING,
          ID_MUTE.to_u64,
          w.to_unsafe
        )
        owner = @@menu_owner
        return if owner.null?
        Win32::LibUser32.DrawMenuBar(owner)
        Win32::LibUser32.InvalidateRect(owner, Pointer(Win32::RECT).null, 1)
      end
    end
  end
end
