{% if flag?(:win32) %}
module MatterMedia
  module Windows
    # Minimal Win32 bindings needed for:
    # - Sending media key events (SendInput)
    # - Tray icon (Shell_NotifyIcon)
    # - Hidden window + message loop (CreateWindowEx, GetMessage, etc)

    alias BOOL = Int32
    alias UINT = UInt32
    alias DWORD = UInt32
    alias WORD = UInt16
    alias LONG = Int32
    alias ULONG = UInt32
    alias BYTE = UInt8

    {% if flag?(:x86_64) %}
      alias ULONG_PTR = UInt64
      alias WPARAM = UInt64
      alias LPARAM = Int64
      alias LRESULT = Int64
    {% else %}
      alias ULONG_PTR = UInt32
      alias WPARAM = UInt32
      alias LPARAM = Int32
      alias LRESULT = Int32
    {% end %}

    alias HANDLE = Void*
    alias HWND = Void*
    alias HINSTANCE = Void*
    alias HICON = Void*
    alias HCURSOR = Void*
    alias HBRUSH = Void*
    alias HMENU = Void*

    WM_NULL      = 0x0000_u32
    WM_DESTROY   = 0x0002_u32
    WM_CLOSE     = 0x0010_u32
    WM_COMMAND   = 0x0111_u32
    WM_APP       = 0x8000_u32

    WM_LBUTTONUP      = 0x0202_u32
    WM_RBUTTONUP      = 0x0205_u32
    WM_LBUTTONDBLCLK  = 0x0203_u32

    CS_HREDRAW = 0x0002_u32
    CS_VREDRAW = 0x0001_u32

    WS_POPUP         = 0x80000000_u32
    WS_EX_TOOLWINDOW = 0x00000080_u32

    SW_HIDE = 0

    TPM_RIGHTBUTTON = 0x0002_u32
    MF_STRING    = 0x0000_u32
    MF_SEPARATOR = 0x0800_u32

    INPUT_KEYBOARD = 1_u32
    KEYEVENTF_KEYUP = 0x0002_u32

    VK_MEDIA_NEXT_TRACK = 0xB0_u16
    VK_MEDIA_PREV_TRACK = 0xB1_u16
    VK_MEDIA_STOP       = 0xB2_u16
    VK_MEDIA_PLAY_PAUSE = 0xB3_u16

    VK_VOLUME_MUTE = 0xAD_u16
    VK_VOLUME_DOWN = 0xAE_u16
    VK_VOLUME_UP   = 0xAF_u16

    NIM_ADD    = 0_u32
    NIM_MODIFY = 1_u32
    NIM_DELETE = 2_u32

    NIF_MESSAGE = 0x00000001_u32
    NIF_ICON    = 0x00000002_u32
    NIF_TIP     = 0x00000004_u32

    IDI_APPLICATION = 32512_u16

    struct GUID
      data1 : UInt32
      data2 : UInt16
      data3 : UInt16
      data4 : StaticArray(UInt8, 8)
    end

    struct POINT
      x : LONG
      y : LONG
    end

    struct RECT
      left : LONG
      top : LONG
      right : LONG
      bottom : LONG
    end

    struct MSG
      hwnd : HWND
      message : UINT
      wParam : WPARAM
      lParam : LPARAM
      time : DWORD
      pt : POINT
    end

    alias WndProc = (HWND, UINT, WPARAM, LPARAM -> LRESULT)

    struct WNDCLASSEXW
      cbSize : UINT
      style : UINT
      lpfnWndProc : WndProc
      cbClsExtra : Int32
      cbWndExtra : Int32
      hInstance : HINSTANCE
      hIcon : HICON
      hCursor : HCURSOR
      hbrBackground : HBRUSH
      lpszMenuName : Pointer(UInt16)
      lpszClassName : Pointer(UInt16)
      hIconSm : HICON
    end

    struct KEYBDINPUT
      wVk : WORD
      wScan : WORD
      dwFlags : DWORD
      time : DWORD
      dwExtraInfo : ULONG_PTR
    end

    struct MOUSEINPUT
      dx : LONG
      dy : LONG
      mouseData : DWORD
      dwFlags : DWORD
      time : DWORD
      dwExtraInfo : ULONG_PTR
    end

    struct HARDWAREINPUT
      uMsg : DWORD
      wParamL : WORD
      wParamH : WORD
    end

    union INPUT_UNION
      mi : MOUSEINPUT
      ki : KEYBDINPUT
      hi : HARDWAREINPUT
    end

    struct INPUT
      type : DWORD
      u : INPUT_UNION
    end

    struct NOTIFYICONDATAW
      cbSize : DWORD
      hWnd : HWND
      uID : UINT
      uFlags : UINT
      uCallbackMessage : UINT
      hIcon : HICON
      szTip : StaticArray(UInt16, 128)
      dwState : DWORD
      dwStateMask : DWORD
      szInfo : StaticArray(UInt16, 256)
      uTimeoutOrVersion : UINT
      szInfoTitle : StaticArray(UInt16, 64)
      dwInfoFlags : DWORD
      guidItem : GUID
      hBalloonIcon : HICON
    end

    @[Link("kernel32")]
    lib LibKernel32
      fun GetModuleHandleW(lpModuleName : Pointer(UInt16)) : HINSTANCE
    end

    @[Link("user32")]
    lib LibUser32
      fun RegisterClassExW(lpWndClass : WNDCLASSEXW*) : WORD
      fun CreateWindowExW(dwExStyle : DWORD, lpClassName : Pointer(UInt16), lpWindowName : Pointer(UInt16), dwStyle : DWORD, x : Int32, y : Int32, nWidth : Int32, nHeight : Int32, hWndParent : HWND, hMenu : HMENU, hInstance : HINSTANCE, lpParam : Void*) : HWND
      fun DefWindowProcW(hWnd : HWND, msg : UINT, wParam : WPARAM, lParam : LPARAM) : LRESULT
      fun DestroyWindow(hWnd : HWND) : BOOL
      fun ShowWindow(hWnd : HWND, nCmdShow : Int32) : BOOL
      fun UpdateWindow(hWnd : HWND) : BOOL
      fun GetMessageW(lpMsg : MSG*, hWnd : HWND, wMsgFilterMin : UINT, wMsgFilterMax : UINT) : BOOL
      fun TranslateMessage(lpMsg : MSG*) : BOOL
      fun DispatchMessageW(lpMsg : MSG*) : LRESULT
      fun PostQuitMessage(nExitCode : Int32) : Nil
      fun LoadIconW(hInstance : HINSTANCE, lpIconName : Pointer(UInt16)) : HICON
      fun GetCursorPos(lpPoint : POINT*) : BOOL
      fun SetForegroundWindow(hWnd : HWND) : BOOL
      fun PostMessageW(hWnd : HWND, msg : UINT, wParam : WPARAM, lParam : LPARAM) : BOOL
      fun CreatePopupMenu : HMENU
      fun AppendMenuW(hMenu : HMENU, uFlags : UINT, uIDNewItem : UInt64, lpNewItem : Pointer(UInt16)) : BOOL
      fun TrackPopupMenu(hMenu : HMENU, uFlags : UINT, x : Int32, y : Int32, nReserved : Int32, hWnd : HWND, prcRect : RECT*) : BOOL
      fun DestroyMenu(hMenu : HMENU) : BOOL
      fun SendInput(cInputs : UINT, pInputs : INPUT*, cbSize : Int32) : UINT
    end

    @[Link("shell32")]
    lib LibShell32
      fun Shell_NotifyIconW(dwMessage : DWORD, lpData : NOTIFYICONDATAW*) : BOOL
    end

    class WString
      getter buf : Array(UInt16)

      def initialize(str : String)
        @buf = self.class.encode(str)
      end

      def to_unsafe : Pointer(UInt16)
        @buf.to_unsafe
      end

      def self.encode(str : String) : Array(UInt16)
        out = Array(UInt16).new(str.size + 1)
        str.each_char do |ch|
          codepoint = ch.ord
          if codepoint <= 0xFFFF
            out << codepoint.to_u16
          else
            codepoint -= 0x10000
            out << ((codepoint >> 10) + 0xD800).to_u16
            out << ((codepoint & 0x3FF) + 0xDC00).to_u16
          end
        end
        out << 0_u16
        out
      end
    end

    def self.make_int_resource(id : UInt16) : Pointer(UInt16)
      {% if flag?(:x86_64) %}
        Pointer(UInt16).new(id.to_u64)
      {% else %}
        Pointer(UInt16).new(id.to_u32)
      {% end %}
    end

    def self.loword(value : WPARAM) : UInt16
      (value & 0xFFFF).to_u16
    end

    def self.copy_wstr(dest : Pointer(UInt16), max_chars : Int32, str : String) : Nil
      w = WString.encode(str)
      to_copy = Math.min(max_chars - 1, w.size - 1)
      i = 0
      while i < to_copy
        dest[i] = w[i]
        i += 1
      end
      dest[to_copy] = 0_u16
    end
  end
end
{% end %}
