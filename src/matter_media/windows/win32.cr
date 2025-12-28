module MatterMedia
  module Windows
    module Win32
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
      alias HRESULT = Int32
      alias HSTRING = Void*
      alias TrustLevel = Int32
      alias BOOLEAN = UInt8

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

      alias UINT_PTR = ULONG_PTR

      alias HANDLE = Void*
      alias HWND = Void*
      alias HINSTANCE = Void*
      alias HICON = Void*
      alias HCURSOR = Void*
      alias HBRUSH = Void*
      alias HMENU = Void*

      WM_NULL          = 0x0000_u32
      WM_DESTROY       = 0x0002_u32
      WM_CLOSE         = 0x0010_u32
      WM_COMMAND       = 0x0111_u32
      WM_USER          = 0x0400_u32
      WM_CONTEXTMENU   = 0x007B_u32
      WM_TIMER         = 0x0113_u32
      WM_APP           = 0x8000_u32
      WM_LBUTTONUP     = 0x0202_u32
      WM_RBUTTONUP     = 0x0205_u32
      WM_RBUTTONDOWN   = 0x0204_u32
      WM_LBUTTONDBLCLK = 0x0203_u32

      CS_HREDRAW = 0x0002_u32
      CS_VREDRAW = 0x0001_u32

      WS_POPUP         = 0x80000000_u32
      WS_EX_TOOLWINDOW = 0x00000080_u32

      SW_HIDE = 0

      TPM_RIGHTBUTTON = 0x0002_u32
      MF_STRING       = 0x0000_u32
      MF_GRAYED       = 0x0001_u32
      MF_DISABLED     = 0x0002_u32
      MF_SEPARATOR    = 0x0800_u32

      COINIT_MULTITHREADED  =  0x0_u32
      RO_INIT_MULTITHREADED =    1_u32
      CLSCTX_ALL            = 0x17_u32

      INPUT_KEYBOARD  =      1_u32
      KEYEVENTF_KEYUP = 0x0002_u32

      VK_MEDIA_NEXT_TRACK = 0xB0_u16
      VK_MEDIA_PREV_TRACK = 0xB1_u16
      VK_MEDIA_STOP       = 0xB2_u16
      VK_MEDIA_PLAY_PAUSE = 0xB3_u16

      VK_VOLUME_MUTE = 0xAD_u16
      VK_VOLUME_DOWN = 0xAE_u16
      VK_VOLUME_UP   = 0xAF_u16

      NIM_ADD        = 0_u32
      NIM_MODIFY     = 1_u32
      NIM_DELETE     = 2_u32
      NIM_SETVERSION = 4_u32

      NOTIFYICON_VERSION_4 = 4_u32

      NIF_MESSAGE = 0x00000001_u32
      NIF_ICON    = 0x00000002_u32
      NIF_TIP     = 0x00000004_u32

      NIN_SELECT    = 0x0400_u32
      NIN_KEYSELECT = 0x0401_u32

      IDI_APPLICATION = 32512_u16

      enum EDataFlow : Int32
        Render  = 0
        Capture = 1
        All     = 2
      end

      enum ERole : Int32
        Console        = 0
        Multimedia     = 1
        Communications = 2
      end

      enum AsyncStatus : Int32
        Started   = 0
        Completed = 1
        Canceled  = 2
        Error     = 3
      end

      enum GSMTCPlaybackStatus : Int32
        Closed   = 0
        Opened   = 1
        Changing = 2
        Stopped  = 3
        Playing  = 4
        Paused   = 5
      end

      lib Types
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

        struct EventRegistrationToken
          value : Int64
        end

        struct IUnknownVtbl
          query_interface : (IUnknown*, GUID*, Void**) -> HRESULT
          add_ref : (IUnknown*) -> UInt32
          release : (IUnknown*) -> UInt32
        end

        struct IUnknown
          lpVtbl : IUnknownVtbl*
        end

        struct IInspectableVtbl
          query_interface : (IInspectable*, GUID*, Void**) -> HRESULT
          add_ref : (IInspectable*) -> UInt32
          release : (IInspectable*) -> UInt32
          get_iids : (IInspectable*, UInt32*, GUID**) -> HRESULT
          get_runtime_class_name : (IInspectable*, HSTRING*) -> HRESULT
          get_trust_level : (IInspectable*, TrustLevel*) -> HRESULT
        end

        struct IInspectable
          lpVtbl : IInspectableVtbl*
        end

        struct IAsyncOperationGSMTCSessionManagerVtbl
          query_interface : (IAsyncOperationGSMTCSessionManager*, GUID*, Void**) -> HRESULT
          add_ref : (IAsyncOperationGSMTCSessionManager*) -> UInt32
          release : (IAsyncOperationGSMTCSessionManager*) -> UInt32
          get_iids : (IAsyncOperationGSMTCSessionManager*, UInt32*, GUID**) -> HRESULT
          get_runtime_class_name : (IAsyncOperationGSMTCSessionManager*, HSTRING*) -> HRESULT
          get_trust_level : (IAsyncOperationGSMTCSessionManager*, TrustLevel*) -> HRESULT
          get_id : (IAsyncOperationGSMTCSessionManager*, UInt32*) -> HRESULT
          get_status : (IAsyncOperationGSMTCSessionManager*, AsyncStatus*) -> HRESULT
          get_error_code : (IAsyncOperationGSMTCSessionManager*, HRESULT*) -> HRESULT
          cancel : (IAsyncOperationGSMTCSessionManager*) -> HRESULT
          close : (IAsyncOperationGSMTCSessionManager*) -> HRESULT
          put_completed : (IAsyncOperationGSMTCSessionManager*, Void*) -> HRESULT
          get_completed : (IAsyncOperationGSMTCSessionManager*, Void**) -> HRESULT
          get_results : (IAsyncOperationGSMTCSessionManager*, IGlobalSystemMediaTransportControlsSessionManager**) -> HRESULT
        end

        struct IAsyncOperationGSMTCSessionManager
          lpVtbl : IAsyncOperationGSMTCSessionManagerVtbl*
        end

        struct IAsyncOperationBooleanVtbl
          query_interface : (IAsyncOperationBoolean*, GUID*, Void**) -> HRESULT
          add_ref : (IAsyncOperationBoolean*) -> UInt32
          release : (IAsyncOperationBoolean*) -> UInt32
          get_iids : (IAsyncOperationBoolean*, UInt32*, GUID**) -> HRESULT
          get_runtime_class_name : (IAsyncOperationBoolean*, HSTRING*) -> HRESULT
          get_trust_level : (IAsyncOperationBoolean*, TrustLevel*) -> HRESULT
          get_id : (IAsyncOperationBoolean*, UInt32*) -> HRESULT
          get_status : (IAsyncOperationBoolean*, AsyncStatus*) -> HRESULT
          get_error_code : (IAsyncOperationBoolean*, HRESULT*) -> HRESULT
          cancel : (IAsyncOperationBoolean*) -> HRESULT
          close : (IAsyncOperationBoolean*) -> HRESULT
          put_completed : (IAsyncOperationBoolean*, Void*) -> HRESULT
          get_completed : (IAsyncOperationBoolean*, Void**) -> HRESULT
          get_results : (IAsyncOperationBoolean*, BOOLEAN*) -> HRESULT
        end

        struct IAsyncOperationBoolean
          lpVtbl : IAsyncOperationBooleanVtbl*
        end

        struct IGlobalSystemMediaTransportControlsSessionPlaybackInfoVtbl
          query_interface : (IGlobalSystemMediaTransportControlsSessionPlaybackInfo*, GUID*, Void**) -> HRESULT
          add_ref : (IGlobalSystemMediaTransportControlsSessionPlaybackInfo*) -> UInt32
          release : (IGlobalSystemMediaTransportControlsSessionPlaybackInfo*) -> UInt32
          get_iids : (IGlobalSystemMediaTransportControlsSessionPlaybackInfo*, UInt32*, GUID**) -> HRESULT
          get_runtime_class_name : (IGlobalSystemMediaTransportControlsSessionPlaybackInfo*, HSTRING*) -> HRESULT
          get_trust_level : (IGlobalSystemMediaTransportControlsSessionPlaybackInfo*, TrustLevel*) -> HRESULT
          get_controls : (IGlobalSystemMediaTransportControlsSessionPlaybackInfo*, Void**) -> HRESULT
          get_playback_status : (IGlobalSystemMediaTransportControlsSessionPlaybackInfo*, GSMTCPlaybackStatus*) -> HRESULT
          get_playback_type : (IGlobalSystemMediaTransportControlsSessionPlaybackInfo*, Void**) -> HRESULT
          get_auto_repeat_mode : (IGlobalSystemMediaTransportControlsSessionPlaybackInfo*, Void**) -> HRESULT
          get_playback_rate : (IGlobalSystemMediaTransportControlsSessionPlaybackInfo*, Void**) -> HRESULT
          get_is_shuffle_active : (IGlobalSystemMediaTransportControlsSessionPlaybackInfo*, Void**) -> HRESULT
        end

        struct IGlobalSystemMediaTransportControlsSessionPlaybackInfo
          lpVtbl : IGlobalSystemMediaTransportControlsSessionPlaybackInfoVtbl*
        end

        struct IGlobalSystemMediaTransportControlsSessionVtbl
          query_interface : (IGlobalSystemMediaTransportControlsSession*, GUID*, Void**) -> HRESULT
          add_ref : (IGlobalSystemMediaTransportControlsSession*) -> UInt32
          release : (IGlobalSystemMediaTransportControlsSession*) -> UInt32
          get_iids : (IGlobalSystemMediaTransportControlsSession*, UInt32*, GUID**) -> HRESULT
          get_runtime_class_name : (IGlobalSystemMediaTransportControlsSession*, HSTRING*) -> HRESULT
          get_trust_level : (IGlobalSystemMediaTransportControlsSession*, TrustLevel*) -> HRESULT
          get_source_app_user_model_id : (IGlobalSystemMediaTransportControlsSession*, HSTRING*) -> HRESULT
          try_get_media_properties_async : (IGlobalSystemMediaTransportControlsSession*, Void**) -> HRESULT
          get_timeline_properties : (IGlobalSystemMediaTransportControlsSession*, Void**) -> HRESULT
          get_playback_info : (IGlobalSystemMediaTransportControlsSession*, IGlobalSystemMediaTransportControlsSessionPlaybackInfo**) -> HRESULT
          try_play_async : (IGlobalSystemMediaTransportControlsSession*, IAsyncOperationBoolean**) -> HRESULT
          try_pause_async : (IGlobalSystemMediaTransportControlsSession*, IAsyncOperationBoolean**) -> HRESULT
          try_stop_async : (IGlobalSystemMediaTransportControlsSession*, IAsyncOperationBoolean**) -> HRESULT
          try_record_async : (IGlobalSystemMediaTransportControlsSession*, IAsyncOperationBoolean**) -> HRESULT
          try_fast_forward_async : (IGlobalSystemMediaTransportControlsSession*, IAsyncOperationBoolean**) -> HRESULT
          try_rewind_async : (IGlobalSystemMediaTransportControlsSession*, IAsyncOperationBoolean**) -> HRESULT
          try_skip_next_async : (IGlobalSystemMediaTransportControlsSession*, IAsyncOperationBoolean**) -> HRESULT
          try_skip_previous_async : (IGlobalSystemMediaTransportControlsSession*, IAsyncOperationBoolean**) -> HRESULT
          try_change_channel_up_async : (IGlobalSystemMediaTransportControlsSession*, IAsyncOperationBoolean**) -> HRESULT
          try_change_channel_down_async : (IGlobalSystemMediaTransportControlsSession*, IAsyncOperationBoolean**) -> HRESULT
          try_toggle_play_pause_async : (IGlobalSystemMediaTransportControlsSession*, IAsyncOperationBoolean**) -> HRESULT
          try_change_auto_repeat_mode_async : (IGlobalSystemMediaTransportControlsSession*, Int32, IAsyncOperationBoolean**) -> HRESULT
          try_change_playback_rate_async : (IGlobalSystemMediaTransportControlsSession*, Float64, IAsyncOperationBoolean**) -> HRESULT
          try_change_shuffle_active_async : (IGlobalSystemMediaTransportControlsSession*, BOOLEAN, IAsyncOperationBoolean**) -> HRESULT
          try_change_playback_position_async : (IGlobalSystemMediaTransportControlsSession*, Int64, IAsyncOperationBoolean**) -> HRESULT
          add_timeline_properties_changed : (IGlobalSystemMediaTransportControlsSession*, Void*, EventRegistrationToken*) -> HRESULT
          remove_timeline_properties_changed : (IGlobalSystemMediaTransportControlsSession*, EventRegistrationToken) -> HRESULT
          add_playback_info_changed : (IGlobalSystemMediaTransportControlsSession*, Void*, EventRegistrationToken*) -> HRESULT
          remove_playback_info_changed : (IGlobalSystemMediaTransportControlsSession*, EventRegistrationToken) -> HRESULT
          add_media_properties_changed : (IGlobalSystemMediaTransportControlsSession*, Void*, EventRegistrationToken*) -> HRESULT
          remove_media_properties_changed : (IGlobalSystemMediaTransportControlsSession*, EventRegistrationToken) -> HRESULT
        end

        struct IGlobalSystemMediaTransportControlsSession
          lpVtbl : IGlobalSystemMediaTransportControlsSessionVtbl*
        end

        struct IGlobalSystemMediaTransportControlsSessionManagerVtbl
          query_interface : (IGlobalSystemMediaTransportControlsSessionManager*, GUID*, Void**) -> HRESULT
          add_ref : (IGlobalSystemMediaTransportControlsSessionManager*) -> UInt32
          release : (IGlobalSystemMediaTransportControlsSessionManager*) -> UInt32
          get_iids : (IGlobalSystemMediaTransportControlsSessionManager*, UInt32*, GUID**) -> HRESULT
          get_runtime_class_name : (IGlobalSystemMediaTransportControlsSessionManager*, HSTRING*) -> HRESULT
          get_trust_level : (IGlobalSystemMediaTransportControlsSessionManager*, TrustLevel*) -> HRESULT
          get_current_session : (IGlobalSystemMediaTransportControlsSessionManager*, IGlobalSystemMediaTransportControlsSession**) -> HRESULT
          get_sessions : (IGlobalSystemMediaTransportControlsSessionManager*, Void**) -> HRESULT
          add_CurrentSessionChanged : (IGlobalSystemMediaTransportControlsSessionManager*, Void*, EventRegistrationToken*) -> HRESULT
          remove_CurrentSessionChanged : (IGlobalSystemMediaTransportControlsSessionManager*, EventRegistrationToken) -> HRESULT
          add_SessionsChanged : (IGlobalSystemMediaTransportControlsSessionManager*, Void*, EventRegistrationToken*) -> HRESULT
          remove_SessionsChanged : (IGlobalSystemMediaTransportControlsSessionManager*, EventRegistrationToken) -> HRESULT
        end

        struct IGlobalSystemMediaTransportControlsSessionManager
          lpVtbl : IGlobalSystemMediaTransportControlsSessionManagerVtbl*
        end

        struct IGlobalSystemMediaTransportControlsSessionManagerStaticsVtbl
          query_interface : (IGlobalSystemMediaTransportControlsSessionManagerStatics*, GUID*, Void**) -> HRESULT
          add_ref : (IGlobalSystemMediaTransportControlsSessionManagerStatics*) -> UInt32
          release : (IGlobalSystemMediaTransportControlsSessionManagerStatics*) -> UInt32
          get_iids : (IGlobalSystemMediaTransportControlsSessionManagerStatics*, UInt32*, GUID**) -> HRESULT
          get_runtime_class_name : (IGlobalSystemMediaTransportControlsSessionManagerStatics*, HSTRING*) -> HRESULT
          get_trust_level : (IGlobalSystemMediaTransportControlsSessionManagerStatics*, TrustLevel*) -> HRESULT
          request_async : (IGlobalSystemMediaTransportControlsSessionManagerStatics*, IAsyncOperationGSMTCSessionManager**) -> HRESULT
        end

        struct IGlobalSystemMediaTransportControlsSessionManagerStatics
          lpVtbl : IGlobalSystemMediaTransportControlsSessionManagerStaticsVtbl*
        end

        struct IMMDeviceEnumeratorVtbl
          query_interface : (IMMDeviceEnumerator*, GUID*, Void**) -> HRESULT
          add_ref : (IMMDeviceEnumerator*) -> UInt32
          release : (IMMDeviceEnumerator*) -> UInt32
          enum_audio_endpoints : (IMMDeviceEnumerator*, EDataFlow, DWORD, Void**) -> HRESULT
          get_default_audio_endpoint : (IMMDeviceEnumerator*, EDataFlow, ERole, IMMDevice**) -> HRESULT
          get_device : (IMMDeviceEnumerator*, Pointer(UInt16), IMMDevice**) -> HRESULT
          register_endpoint_notification_callback : (IMMDeviceEnumerator*, Void*) -> HRESULT
          unregister_endpoint_notification_callback : (IMMDeviceEnumerator*, Void*) -> HRESULT
        end

        struct IMMDeviceEnumerator
          lpVtbl : IMMDeviceEnumeratorVtbl*
        end

        struct IMMDeviceVtbl
          query_interface : (IMMDevice*, GUID*, Void**) -> HRESULT
          add_ref : (IMMDevice*) -> UInt32
          release : (IMMDevice*) -> UInt32
          activate : (IMMDevice*, GUID*, DWORD, Void*, Void**) -> HRESULT
          open_property_store : (IMMDevice*, DWORD, Void**) -> HRESULT
          get_id : (IMMDevice*, Pointer(Pointer(UInt16))) -> HRESULT
          get_state : (IMMDevice*, DWORD*) -> HRESULT
        end

        struct IMMDevice
          lpVtbl : IMMDeviceVtbl*
        end

        struct IAudioEndpointVolumeVtbl
          query_interface : (IAudioEndpointVolume*, GUID*, Void**) -> HRESULT
          add_ref : (IAudioEndpointVolume*) -> UInt32
          release : (IAudioEndpointVolume*) -> UInt32
          register_control_change_notify : (IAudioEndpointVolume*, Void*) -> HRESULT
          unregister_control_change_notify : (IAudioEndpointVolume*, Void*) -> HRESULT
          get_channel_count : (IAudioEndpointVolume*, UINT*) -> HRESULT
          set_master_volume_level : (IAudioEndpointVolume*, Float32, GUID*) -> HRESULT
          set_master_volume_level_scalar : (IAudioEndpointVolume*, Float32, GUID*) -> HRESULT
          get_master_volume_level : (IAudioEndpointVolume*, Float32*) -> HRESULT
          get_master_volume_level_scalar : (IAudioEndpointVolume*, Float32*) -> HRESULT
          set_channel_volume_level : (IAudioEndpointVolume*, UINT, Float32, GUID*) -> HRESULT
          set_channel_volume_level_scalar : (IAudioEndpointVolume*, UINT, Float32, GUID*) -> HRESULT
          get_channel_volume_level : (IAudioEndpointVolume*, UINT, Float32*) -> HRESULT
          get_channel_volume_level_scalar : (IAudioEndpointVolume*, UINT, Float32*) -> HRESULT
          set_mute : (IAudioEndpointVolume*, BOOL, GUID*) -> HRESULT
          get_mute : (IAudioEndpointVolume*, BOOL*) -> HRESULT
          get_volume_step_info : (IAudioEndpointVolume*, UINT*, UINT*) -> HRESULT
          volume_step_up : (IAudioEndpointVolume*, GUID*) -> HRESULT
          volume_step_down : (IAudioEndpointVolume*, GUID*) -> HRESULT
          query_hardware_support : (IAudioEndpointVolume*, DWORD*) -> HRESULT
          get_volume_range : (IAudioEndpointVolume*, Float32*, Float32*, Float32*) -> HRESULT
        end

        struct IAudioEndpointVolume
          lpVtbl : IAudioEndpointVolumeVtbl*
        end
      end

      alias GUID = Types::GUID
      alias POINT = Types::POINT
      alias RECT = Types::RECT
      alias MSG = Types::MSG
      alias WndProc = Types::WndProc
      alias WNDCLASSEXW = Types::WNDCLASSEXW
      alias KEYBDINPUT = Types::KEYBDINPUT
      alias MOUSEINPUT = Types::MOUSEINPUT
      alias HARDWAREINPUT = Types::HARDWAREINPUT
      alias INPUT_UNION = Types::INPUT_UNION
      alias INPUT = Types::INPUT
      alias NOTIFYICONDATAW = Types::NOTIFYICONDATAW
      alias EventRegistrationToken = Types::EventRegistrationToken
      alias IUnknownVtbl = Types::IUnknownVtbl
      alias IUnknown = Types::IUnknown
      alias IInspectableVtbl = Types::IInspectableVtbl
      alias IInspectable = Types::IInspectable
      alias IAsyncOperationGSMTCSessionManagerVtbl = Types::IAsyncOperationGSMTCSessionManagerVtbl
      alias IAsyncOperationGSMTCSessionManager = Types::IAsyncOperationGSMTCSessionManager
      alias IAsyncOperationBooleanVtbl = Types::IAsyncOperationBooleanVtbl
      alias IAsyncOperationBoolean = Types::IAsyncOperationBoolean
      alias IGlobalSystemMediaTransportControlsSessionPlaybackInfoVtbl = Types::IGlobalSystemMediaTransportControlsSessionPlaybackInfoVtbl
      alias IGlobalSystemMediaTransportControlsSessionPlaybackInfo = Types::IGlobalSystemMediaTransportControlsSessionPlaybackInfo
      alias IGlobalSystemMediaTransportControlsSessionVtbl = Types::IGlobalSystemMediaTransportControlsSessionVtbl
      alias IGlobalSystemMediaTransportControlsSession = Types::IGlobalSystemMediaTransportControlsSession
      alias IGlobalSystemMediaTransportControlsSessionManagerVtbl = Types::IGlobalSystemMediaTransportControlsSessionManagerVtbl
      alias IGlobalSystemMediaTransportControlsSessionManager = Types::IGlobalSystemMediaTransportControlsSessionManager
      alias IGlobalSystemMediaTransportControlsSessionManagerStaticsVtbl = Types::IGlobalSystemMediaTransportControlsSessionManagerStaticsVtbl
      alias IGlobalSystemMediaTransportControlsSessionManagerStatics = Types::IGlobalSystemMediaTransportControlsSessionManagerStatics
      alias IMMDeviceEnumeratorVtbl = Types::IMMDeviceEnumeratorVtbl
      alias IMMDeviceEnumerator = Types::IMMDeviceEnumerator
      alias IMMDeviceVtbl = Types::IMMDeviceVtbl
      alias IMMDevice = Types::IMMDevice
      alias IAudioEndpointVolumeVtbl = Types::IAudioEndpointVolumeVtbl
      alias IAudioEndpointVolume = Types::IAudioEndpointVolume

      def self.make_guid(data1 : UInt32, data2 : UInt16, data3 : UInt16, data4 : StaticArray(UInt8, 8)) : GUID
        guid = GUID.new
        guid.data1 = data1
        guid.data2 = data2
        guid.data3 = data3
        guid.data4 = data4
        guid
      end

      CLSID_MMDeviceEnumerator                                     = make_guid(0xBCDE0395_u32, 0xE52F_u16, 0x467C_u16, StaticArray[0x8E_u8, 0x3D_u8, 0xC4_u8, 0x57_u8, 0x92_u8, 0x91_u8, 0x69_u8, 0x2E_u8])
      IID_IMMDeviceEnumerator                                      = make_guid(0xA95664D2_u32, 0x9614_u16, 0x4F35_u16, StaticArray[0xA7_u8, 0x46_u8, 0xDE_u8, 0x8D_u8, 0xB6_u8, 0x36_u8, 0x17_u8, 0xE6_u8])
      IID_IMMDevice                                                = make_guid(0xD666063F_u32, 0x1587_u16, 0x4E43_u16, StaticArray[0x81_u8, 0xF1_u8, 0xB9_u8, 0x48_u8, 0xE8_u8, 0x07_u8, 0x36_u8, 0x3F_u8])
      IID_IAudioEndpointVolume                                     = make_guid(0x5CDF2C82_u32, 0x841E_u16, 0x4546_u16, StaticArray[0x97_u8, 0x22_u8, 0x0C_u8, 0xF7_u8, 0x40_u8, 0x78_u8, 0x22_u8, 0x9A_u8])
      IID_IGlobalSystemMediaTransportControlsSessionManagerStatics = make_guid(0x2050C4EE_u32, 0x11A0_u16, 0x57DE_u16, StaticArray[0xAE_u8, 0xD7_u8, 0xC9_u8, 0x7C_u8, 0x70_u8, 0x33_u8, 0x82_u8, 0x45_u8])

      @[Link("kernel32")]
      lib LibKernel32
        fun GetModuleHandleW(lpModuleName : Pointer(UInt16)) : HINSTANCE
        fun Sleep(dwMilliseconds : DWORD) : Nil
      end

      @[Link("user32")]
      lib LibUser32
        fun RegisterClassExW(lpWndClass : Types::WNDCLASSEXW*) : WORD
        fun CreateWindowExW(dwExStyle : DWORD, lpClassName : Pointer(UInt16), lpWindowName : Pointer(UInt16), dwStyle : DWORD, x : Int32, y : Int32, nWidth : Int32, nHeight : Int32, hWndParent : HWND, hMenu : HMENU, hInstance : HINSTANCE, lpParam : Void*) : HWND
        fun DefWindowProcW(hWnd : HWND, msg : UINT, wParam : WPARAM, lParam : LPARAM) : LRESULT
        fun DestroyWindow(hWnd : HWND) : BOOL
        fun ShowWindow(hWnd : HWND, nCmdShow : Int32) : BOOL
        fun UpdateWindow(hWnd : HWND) : BOOL
        fun GetMessageW(lpMsg : Types::MSG*, hWnd : HWND, wMsgFilterMin : UINT, wMsgFilterMax : UINT) : BOOL
        fun TranslateMessage(lpMsg : Types::MSG*) : BOOL
        fun DispatchMessageW(lpMsg : Types::MSG*) : LRESULT
        fun PostQuitMessage(nExitCode : Int32) : Nil
        fun LoadIconW(hInstance : HINSTANCE, lpIconName : Pointer(UInt16)) : HICON
        fun GetCursorPos(lpPoint : Types::POINT*) : BOOL
        fun SetForegroundWindow(hWnd : HWND) : BOOL
        fun PostMessageW(hWnd : HWND, msg : UINT, wParam : WPARAM, lParam : LPARAM) : BOOL
        fun CreatePopupMenu : HMENU
        fun AppendMenuW(hMenu : HMENU, uFlags : UINT, uIDNewItem : UInt64, lpNewItem : Pointer(UInt16)) : BOOL
        fun TrackPopupMenu(hMenu : HMENU, uFlags : UINT, x : Int32, y : Int32, nReserved : Int32, hWnd : HWND, prcRect : Types::RECT*) : BOOL
        fun DestroyMenu(hMenu : HMENU) : BOOL
        fun SendInput(cInputs : UINT, pInputs : Types::INPUT*, cbSize : Int32) : UINT
        fun SetTimer(hWnd : HWND, nIDEvent : UINT_PTR, uElapse : UINT, lpTimerFunc : Void*) : UINT_PTR
        fun KillTimer(hWnd : HWND, uIDEvent : UINT_PTR) : BOOL
      end

      @[Link("shell32")]
      lib LibShell32
        fun Shell_NotifyIconW(dwMessage : DWORD, lpData : Types::NOTIFYICONDATAW*) : BOOL
      end

      @[Link("ole32")]
      lib LibOle32
        fun CoInitializeEx(pvReserved : Void*, dwCoInit : DWORD) : HRESULT
        fun CoUninitialize : Nil
        fun CoCreateInstance(rclsid : GUID*, pUnkOuter : Void*, dwClsContext : DWORD, riid : GUID*, ppv : Void**) : HRESULT
      end

      @[Link("runtimeobject")]
      lib LibCombase
        fun RoInitialize(initType : DWORD) : HRESULT
        fun RoGetActivationFactory(activatableClassId : HSTRING, iid : GUID*, factory : Void**) : HRESULT
        fun WindowsCreateString(sourceString : Pointer(UInt16), length : UInt32, string : HSTRING*) : HRESULT
        fun WindowsDeleteString(string : HSTRING) : HRESULT
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
          outp = Array(UInt16).new(str.size + 1)
          str.each_char do |ch|
            codepoint = ch.ord
            if codepoint <= 0xFFFF
              outp << codepoint.to_u16
            else
              codepoint -= 0x10000
              outp << ((codepoint >> 10) + 0xD800).to_u16
              outp << ((codepoint & 0x3FF) + 0xDC00).to_u16
            end
          end
          outp << 0_u16
          outp
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

      def self.ok?(hr : HRESULT) : Bool
        hr >= 0
      end

      def self.release_unknown(ptr : Pointer(Void)) : Nil
        return if ptr.null?
        unknown = ptr.as(IUnknown*)
        unknown.value.lpVtbl.value.release.call(unknown)
      end

      def self.create_hstring(str : String) : HSTRING
        w = WString.encode(str)
        hstring = Pointer(Void).null
        hr = LibCombase.WindowsCreateString(w.to_unsafe, (w.size - 1).to_u32, pointerof(hstring))
        return Pointer(Void).null unless ok?(hr)
        hstring
      end

      def self.delete_hstring(hstring : HSTRING) : Nil
        return if hstring.null?
        LibCombase.WindowsDeleteString(hstring)
      end
    end
  end
end
