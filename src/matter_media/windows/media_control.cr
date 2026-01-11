require "./win32"

module MatterMedia
  module Windows
    module MediaControl
      enum PlaybackState
        None
        Closed
        Opened
        Changing
        Stopped
        Playing
        Paused
      end

      {% if flag?(:x86_64) %}
        ULONG_PTR_ZERO = 0_u64
      {% else %}
        ULONG_PTR_ZERO = 0_u32
      {% end %}

      @@initialized = false
      @@manager = Pointer(Win32::IGlobalSystemMediaTransportControlsSessionManager).null
      @@endpoint = Pointer(Win32::IAudioEndpointVolume).null
      @@playback_state = PlaybackState::None
      @@volume_level = 0_u8
      @@mute_state = false
      @@playback_set = false
      @@volume_set = false
      @@mute_set = false
      @@playback_callbacks = [] of Proc(PlaybackState, Nil)
      @@volume_callbacks = [] of Proc(UInt8, Nil)
      @@mute_callbacks = [] of Proc(Bool, Nil)

      def self.on_playback_state(&block : PlaybackState ->) : Nil
        @@playback_callbacks << block
      end

      def self.on_volume_level(&block : UInt8 ->) : Nil
        @@volume_callbacks << block
      end

      def self.on_mute_state(&block : Bool ->) : Nil
        @@mute_callbacks << block
      end

      def self.playback_state : PlaybackState
        ensure_initialized
        update_playback_cache(false) unless @@playback_set
        @@playback_state
      end

      def self.volume_level : UInt8
        ensure_initialized
        update_volume_cache(false) unless @@volume_set
        @@volume_level
      end

      def self.mute? : Bool
        ensure_initialized
        update_mute_cache(false) unless @@mute_set
        @@mute_state
      end

      def self.volume_percent : Int32
        level = volume_level
        ((level.to_f32 / 254.0_f32) * 100.0_f32).round.to_i
      end

      def self.set_volume_level(level : UInt8) : Nil
        ensure_initialized
        return if @@endpoint.null?
        target = clamp_level(level)
        scalar = target.to_f32 / 254.0_f32
        @@endpoint.value.lpVtbl.value.set_master_volume_level_scalar.call(@@endpoint, scalar, Pointer(Win32::GUID).null)
        update_volume_cache(true)
      end

      def self.set_mute(state : Bool) : Nil
        ensure_initialized
        return if @@endpoint.null?
        @@endpoint.value.lpVtbl.value.set_mute.call(@@endpoint, state ? 1 : 0, Pointer(Win32::GUID).null)
        update_mute_cache(true)
      end

      def self.play : Nil
        ensure_initialized
        return if try_session_command(:play)
        press_key(Win32::VK_MEDIA_PLAY_PAUSE)
      end

      def self.pause : Nil
        ensure_initialized
        return if try_session_command(:pause)
        press_key(Win32::VK_MEDIA_PLAY_PAUSE)
      end

      def self.toggle : Nil
        ensure_initialized
        return if try_session_command(:toggle)
        press_key(Win32::VK_MEDIA_PLAY_PAUSE)
      end

      def self.play_pause : Nil
        toggle
      end

      def self.next_track : Nil
        press_key(Win32::VK_MEDIA_NEXT_TRACK)
      end

      def self.previous_track : Nil
        press_key(Win32::VK_MEDIA_PREV_TRACK)
      end

      def self.stop : Nil
        press_key(Win32::VK_MEDIA_STOP)
      end

      def self.volume_up : Nil
        press_key(Win32::VK_VOLUME_UP)
      end

      def self.volume_down : Nil
        press_key(Win32::VK_VOLUME_DOWN)
      end

      def self.mute_toggle : Nil
        ensure_initialized
        if @@endpoint.null?
          press_key(Win32::VK_VOLUME_MUTE)
        else
          set_mute(!mute?)
        end
      end

      def self.poll : Nil
        ensure_initialized
        update_playback_cache(true)
        update_volume_cache(true)
        update_mute_cache(true)
      end

      private def self.ensure_initialized : Nil
        return if @@initialized
        @@initialized = true
        Win32::LibOle32.CoInitializeEx(Pointer(Void).null, Win32::COINIT_MULTITHREADED)
        Win32::LibCombase.RoInitialize(Win32::RO_INIT_MULTITHREADED)
        @@endpoint = create_audio_endpoint
      end

      private def self.ensure_manager : Nil
        return unless @@manager.null?
        @@manager = create_session_manager(25_u32)
      end

      private def self.create_audio_endpoint : Pointer(Win32::IAudioEndpointVolume)
        enumerator = Pointer(Win32::IMMDeviceEnumerator).null
        hr = Win32::LibOle32.CoCreateInstance(pointerof(Win32::CLSID_MMDeviceEnumerator), Pointer(Void).null, Win32::CLSCTX_ALL, pointerof(Win32::IID_IMMDeviceEnumerator), pointerof(enumerator).as(Void**))
        return Pointer(Win32::IAudioEndpointVolume).null unless Win32.ok?(hr)

        device = Pointer(Win32::IMMDevice).null
        hr = enumerator.value.lpVtbl.value.get_default_audio_endpoint.call(enumerator, Win32::EDataFlow::Render, Win32::ERole::Console, pointerof(device))
        Win32.release_unknown(enumerator.as(Pointer(Void)))
        return Pointer(Win32::IAudioEndpointVolume).null unless Win32.ok?(hr)

        endpoint = Pointer(Win32::IAudioEndpointVolume).null
        hr = device.value.lpVtbl.value.activate.call(device, pointerof(Win32::IID_IAudioEndpointVolume), Win32::CLSCTX_ALL, Pointer(Void).null, pointerof(endpoint).as(Void**))
        Win32.release_unknown(device.as(Pointer(Void)))
        return Pointer(Win32::IAudioEndpointVolume).null unless Win32.ok?(hr)

        endpoint
      end

      private def self.create_session_manager(timeout_ms : UInt32) : Pointer(Win32::IGlobalSystemMediaTransportControlsSessionManager)
        class_id = Win32.create_hstring("Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager")
        return Pointer(Win32::IGlobalSystemMediaTransportControlsSessionManager).null if class_id.null?

        statics = Pointer(Win32::IGlobalSystemMediaTransportControlsSessionManagerStatics).null
        hr = Win32::LibCombase.RoGetActivationFactory(class_id, pointerof(Win32::IID_IGlobalSystemMediaTransportControlsSessionManagerStatics), pointerof(statics).as(Void**))
        Win32.delete_hstring(class_id)
        return Pointer(Win32::IGlobalSystemMediaTransportControlsSessionManager).null unless Win32.ok?(hr) && !statics.null?

        operation = Pointer(Win32::IAsyncOperationGSMTCSessionManager).null
        hr = statics.value.lpVtbl.value.request_async.call(statics, pointerof(operation))
        Win32.release_unknown(statics.as(Pointer(Void)))
        return Pointer(Win32::IGlobalSystemMediaTransportControlsSessionManager).null unless Win32.ok?(hr) && !operation.null?

        status = Win32::AsyncStatus::Started
        elapsed = 0_u32
        while status == Win32::AsyncStatus::Started && elapsed < timeout_ms
          operation.value.lpVtbl.value.get_status.call(operation, pointerof(status))
          break unless status == Win32::AsyncStatus::Started
          Win32::LibKernel32.Sleep(5_u32)
          elapsed += 5_u32
        end

        manager = Pointer(Win32::IGlobalSystemMediaTransportControlsSessionManager).null
        if status == Win32::AsyncStatus::Completed
          hr = operation.value.lpVtbl.value.get_results.call(operation, pointerof(manager))
          manager = Pointer(Win32::IGlobalSystemMediaTransportControlsSessionManager).null unless Win32.ok?(hr)
        end

        Win32.release_unknown(operation.as(Pointer(Void)))
        manager
      end

      private def self.update_volume_cache(notify : Bool) : Nil
        level = read_volume_level
        if !@@volume_set || level != @@volume_level
          @@volume_level = level
          @@volume_set = true
          if notify
            @@volume_callbacks.each { |cb| cb.call(level) }
          end
        end
      end

      private def self.update_mute_cache(notify : Bool) : Nil
        muted = read_mute_state
        if !@@mute_set || muted != @@mute_state
          @@mute_state = muted
          @@mute_set = true
          if notify
            @@mute_callbacks.each { |cb| cb.call(muted) }
          end
        end
      end

      private def self.read_volume_level : UInt8
        return 0_u8 if @@endpoint.null?
        scalar = 0.0_f32
        hr = @@endpoint.value.lpVtbl.value.get_master_volume_level_scalar.call(@@endpoint, pointerof(scalar))
        return 0_u8 unless Win32.ok?(hr)
        clamp_level(((scalar * 254.0_f32).round).to_i)
      end

      private def self.read_mute_state : Bool
        return false if @@endpoint.null?
        muted = 0
        hr = @@endpoint.value.lpVtbl.value.get_mute.call(@@endpoint, pointerof(muted))
        return false unless Win32.ok?(hr)
        muted != 0
      end

      private def self.update_playback_cache(notify : Bool) : Nil
        ensure_manager
        state = read_playback_state
        if !@@playback_set || state != @@playback_state
          @@playback_state = state
          @@playback_set = true
          if notify
            @@playback_callbacks.each { |cb| cb.call(state) }
          end
        end
      end

      private def self.read_playback_state : PlaybackState
        ensure_manager
        return PlaybackState::None if @@manager.null?

        session = Pointer(Win32::IGlobalSystemMediaTransportControlsSession).null
        hr = @@manager.value.lpVtbl.value.get_current_session.call(@@manager, pointerof(session))
        return PlaybackState::None unless Win32.ok?(hr) && !session.null?

        info = Pointer(Win32::IGlobalSystemMediaTransportControlsSessionPlaybackInfo).null
        hr = session.value.lpVtbl.value.get_playback_info.call(session, pointerof(info))
        Win32.release_unknown(session.as(Pointer(Void)))
        return PlaybackState::None unless Win32.ok?(hr) && !info.null?

        status = Win32::GSMTCPlaybackStatus::Closed
        info.value.lpVtbl.value.get_playback_status.call(info, pointerof(status))
        Win32.release_unknown(info.as(Pointer(Void)))

        map_playback_status(status)
      end

      private def self.map_playback_status(status : Win32::GSMTCPlaybackStatus) : PlaybackState
        case status
        when Win32::GSMTCPlaybackStatus::Closed
          PlaybackState::Closed
        when Win32::GSMTCPlaybackStatus::Opened
          PlaybackState::Opened
        when Win32::GSMTCPlaybackStatus::Changing
          PlaybackState::Changing
        when Win32::GSMTCPlaybackStatus::Stopped
          PlaybackState::Stopped
        when Win32::GSMTCPlaybackStatus::Playing
          PlaybackState::Playing
        when Win32::GSMTCPlaybackStatus::Paused
          PlaybackState::Paused
        else
          PlaybackState::None
        end
      end

      private def self.try_session_command(kind : Symbol) : Bool
        ensure_manager
        return false if @@manager.null?

        session = Pointer(Win32::IGlobalSystemMediaTransportControlsSession).null
        hr = @@manager.value.lpVtbl.value.get_current_session.call(@@manager, pointerof(session))
        return false unless Win32.ok?(hr) && !session.null?

        op = Pointer(Win32::IAsyncOperationBoolean).null
        hr = case kind
             when :play
               session.value.lpVtbl.value.try_play_async.call(session, pointerof(op))
             when :pause
               session.value.lpVtbl.value.try_pause_async.call(session, pointerof(op))
             else
               session.value.lpVtbl.value.try_toggle_play_pause_async.call(session, pointerof(op))
             end

        Win32.release_unknown(session.as(Pointer(Void)))
        Win32.release_unknown(op.as(Pointer(Void))) unless op.null?
        Win32.ok?(hr)
      end

      private def self.clamp_level(level : UInt8) : UInt8
        if level > 254_u8
          254_u8
        else
          level
        end
      end

      private def self.clamp_level(level : Int32) : UInt8
        if level < 0
          0_u8
        elsif level > 254
          254_u8
        else
          level.to_u8
        end
      end

      private def self.press_key(vk : UInt16) : Nil
        inputs = StaticArray(Win32::INPUT, 2).new(Win32::INPUT.new)

        down = Win32::INPUT.new
        down.type = Win32::INPUT_KEYBOARD
        down.u.ki = Win32::KEYBDINPUT.new(wVk: vk, wScan: 0_u16, dwFlags: 0_u32, time: 0_u32, dwExtraInfo: ULONG_PTR_ZERO)

        up = Win32::INPUT.new
        up.type = Win32::INPUT_KEYBOARD
        up.u.ki = Win32::KEYBDINPUT.new(wVk: vk, wScan: 0_u16, dwFlags: Win32::KEYEVENTF_KEYUP, time: 0_u32, dwExtraInfo: ULONG_PTR_ZERO)

        inputs[0] = down
        inputs[1] = up

        Win32::LibUser32.SendInput(2_u32, inputs.to_unsafe, sizeof(Win32::INPUT))
        nil
      end
    end
  end
end
