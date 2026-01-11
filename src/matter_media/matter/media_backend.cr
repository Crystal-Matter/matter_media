module MatterMedia
  module Matter
    enum PlaybackState
      Stopped
      Playing
      Paused
    end

    module MediaBackend
      abstract def playback_state : PlaybackState
      abstract def volume_level : UInt8
      abstract def mute? : Bool

      abstract def set_volume_level(level : UInt8) : Nil
      abstract def set_mute(state : Bool) : Nil

      abstract def play : Nil
      abstract def pause : Nil
      abstract def toggle : Nil
      abstract def next_track : Nil
      abstract def previous_track : Nil

      abstract def on_playback_state(&block : PlaybackState ->) : Nil
      abstract def on_volume_level(&block : UInt8 ->) : Nil
      abstract def on_mute_state(&block : Bool ->) : Nil
    end
  end
end
