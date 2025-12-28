require "./win32"

module MatterMedia
  module Windows
    module MediaControl
      def self.play_pause : Nil
        press_key(Win32::VK_MEDIA_PLAY_PAUSE)
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
        press_key(Win32::VK_VOLUME_MUTE)
      end

      private def self.press_key(vk : UInt16) : Nil
        inputs = Slice(Win32::INPUT).new(2)

        down = uninitialized Win32::INPUT
        LibC.memset(pointerof(down).as(Void*), 0, sizeof(Win32::INPUT))
        down.type = Win32::INPUT_KEYBOARD
        down.u.ki = Win32::KEYBDINPUT.new(wVk: vk, wScan: 0_u16, dwFlags: 0_u32, time: 0_u32, dwExtraInfo: 0.as(Win32::ULONG_PTR))

        up = uninitialized Win32::INPUT
        LibC.memset(pointerof(up).as(Void*), 0, sizeof(Win32::INPUT))
        up.type = Win32::INPUT_KEYBOARD
        up.u.ki = Win32::KEYBDINPUT.new(wVk: vk, wScan: 0_u16, dwFlags: Win32::KEYEVENTF_KEYUP, time: 0_u32, dwExtraInfo: 0.as(Win32::ULONG_PTR))

        inputs[0] = down
        inputs[1] = up

        Win32::LibUser32.SendInput(2_u32, inputs.to_unsafe, sizeof(Win32::INPUT))
        nil
      end
    end
  end
end
