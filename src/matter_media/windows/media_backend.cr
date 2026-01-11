require "../matter/media_backend"
require "./media_control"

module MatterMedia
  module Windows
    class MediaBackend
      include MatterMedia::Matter::MediaBackend

      def playback_state : MatterMedia::Matter::PlaybackState
        map_playback_state(MediaControl.playback_state)
      end

      def volume_level : UInt8
        MediaControl.volume_level
      end

      def mute? : Bool
        MediaControl.mute?
      end

      def set_volume_level(level : UInt8) : Nil
        MediaControl.set_volume_level(level)
      end

      def set_mute(state : Bool) : Nil
        MediaControl.set_mute(state)
      end

      def play : Nil
        MediaControl.play
      end

      def pause : Nil
        MediaControl.pause
      end

      def toggle : Nil
        MediaControl.toggle
      end

      def next_track : Nil
        MediaControl.next_track
      end

      def previous_track : Nil
        MediaControl.previous_track
      end

      def on_playback_state(&block : MatterMedia::Matter::PlaybackState ->) : Nil
        MediaControl.on_playback_state do |state|
          block.call(map_playback_state(state))
        end
      end

      def on_volume_level(&block : UInt8 ->) : Nil
        MediaControl.on_volume_level do |level|
          block.call(level)
        end
      end

      def on_mute_state(&block : Bool ->) : Nil
        MediaControl.on_mute_state do |muted|
          block.call(muted)
        end
      end

      private def map_playback_state(state : MediaControl::PlaybackState) : MatterMedia::Matter::PlaybackState
        case state
        when MediaControl::PlaybackState::Playing
          MatterMedia::Matter::PlaybackState::Playing
        when MediaControl::PlaybackState::Paused
          MatterMedia::Matter::PlaybackState::Paused
        else
          MatterMedia::Matter::PlaybackState::Stopped
        end
      end
    end
  end
end
