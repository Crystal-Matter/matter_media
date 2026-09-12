require "./spec_helper"

private class FakeMediaBackend
  include MatterMedia::Matter::MediaBackend

  getter calls = [] of String
  property playback_state : MatterMedia::Matter::PlaybackState = MatterMedia::Matter::PlaybackState::Stopped
  property volume_level : UInt8 = 0_u8
  property? mute : Bool = false

  @on_playback_state : Proc(MatterMedia::Matter::PlaybackState, Nil)?
  @on_volume_level : Proc(UInt8, Nil)?
  @on_mute_state : Proc(Bool, Nil)?

  def set_volume_level(level : UInt8) : Nil
    @calls << "volume:#{level}"
    @volume_level = level
  end

  def set_mute(state : Bool) : Nil
    @calls << "mute:#{state}"
    @mute = state
  end

  def play : Nil
    @calls << "play"
    @playback_state = MatterMedia::Matter::PlaybackState::Playing
  end

  def pause : Nil
    @calls << "pause"
    @playback_state = MatterMedia::Matter::PlaybackState::Paused
  end

  def toggle : Nil
    @calls << "toggle"
  end

  def next_track : Nil
    @calls << "next"
  end

  def previous_track : Nil
    @calls << "previous"
  end

  def on_playback_state(&block : MatterMedia::Matter::PlaybackState ->) : Nil
    @on_playback_state = block
  end

  def on_volume_level(&block : UInt8 ->) : Nil
    @on_volume_level = block
  end

  def on_mute_state(&block : Bool ->) : Nil
    @on_mute_state = block
  end

  # Report a change the way the Windows backend does, from its watcher.
  def report_playback_state(state : MatterMedia::Matter::PlaybackState) : Nil
    @playback_state = state
    @on_playback_state.try &.call(state)
  end

  def report_volume_level(level : UInt8) : Nil
    @volume_level = level
    @on_volume_level.try &.call(level)
  end

  def report_mute_state(muted : Bool) : Nil
    @mute = muted
    @on_mute_state.try &.call(muted)
  end
end

private class SpyDisplay
  include MatterMedia::Matter::CommissioningDisplay

  getter shown = [] of MatterMedia::Matter::CommissioningInfo
  getter? hidden = false

  def show(info : MatterMedia::Matter::CommissioningInfo) : Nil
    @shown << info
  end

  def hide : Nil
    @hidden = true
  end
end

# The commissioning display is driven by the lifecycle hooks, which are
# protected; this reaches them without starting the transport.
private class DisplayProbe < MatterMedia::Matter::MediaDevice
  def enter_commissioning_mode : Nil
    started_commissioning_mode
  end

  def enter_operational_mode : Nil
    started_operational_mode
  end
end

private def build_device(backend : FakeMediaBackend) : MatterMedia::Matter::MediaDevice
  MatterMedia::Matter::MediaDevice.new(
    backend,
    storage: Matter::Storage::Memory.new,
    ip_addresses: [Socket::IPAddress.new("127.0.0.1", 0)],
    port: 0
  )
end

private def build_probe(backend : FakeMediaBackend, display : SpyDisplay) : DisplayProbe
  DisplayProbe.new(
    backend,
    display,
    storage: Matter::Storage::Memory.new,
    ip_addresses: [Socket::IPAddress.new("127.0.0.1", 0)],
    port: 0
  )
end

describe MatterMedia do
  it "has a version" do
    MatterMedia::VERSION.should be_a(String)
    MatterMedia::VERSION.should_not be_empty
  end
end

describe MatterMedia::Matter::MediaDevice do
  it "builds endpoints that satisfy their device types" do
    backend = FakeMediaBackend.new
    device = build_device(backend)

    begin
      device.node.validate.should be_empty
    ensure
      device.shutdown!
    end
  end

  it "plays and pauses as the play/pause switch is toggled" do
    backend = FakeMediaBackend.new
    device = build_device(backend)

    begin
      device.play_pause.on = true
      device.play_pause.on = false

      backend.calls.should eq(["play", "pause"])
    ensure
      device.shutdown!
    end
  end

  it "does not echo a backend playback change back to the backend" do
    backend = FakeMediaBackend.new
    device = build_device(backend)

    begin
      backend.report_playback_state(MatterMedia::Matter::PlaybackState::Playing)

      device.play_pause.on?.should be_true
      backend.calls.should be_empty
    ensure
      device.shutdown!
    end
  end

  it "sets the volume from the level control cluster and unmutes" do
    backend = FakeMediaBackend.new
    backend.mute = true
    device = build_device(backend)

    begin
      backend.calls.clear
      device.volume_level.level = 100_u8

      backend.calls.should eq(["volume:100", "mute:false"])
      backend.volume_level.should eq(100_u8)
    ensure
      device.shutdown!
    end
  end

  it "mutes when the volume switch is turned off" do
    backend = FakeMediaBackend.new
    device = build_device(backend)

    begin
      backend.calls.clear
      device.volume_on_off.on = false

      backend.calls.should eq(["mute:true"])
    ensure
      device.shutdown!
    end
  end

  it "releases the momentary skip buttons after they are pressed" do
    backend = FakeMediaBackend.new
    device = build_device(backend)

    begin
      device.skip_next.on = true
      device.skip_previous.on = true
      backend.calls.should eq(["next", "previous"])

      sleep MatterMedia::Matter::MediaDevice::MOMENTARY_RESET_DELAY * 3
      device.skip_next.on?.should be_false
      device.skip_previous.on?.should be_false
      backend.calls.should eq(["next", "previous"])
    ensure
      device.shutdown!
    end
  end

  it "shows the pairing codes while commissioning and hides them once paired" do
    backend = FakeMediaBackend.new
    display = SpyDisplay.new
    device = build_probe(backend, display)

    begin
      device.enter_commissioning_mode
      info = display.shown.first
      # A manual code carries the pin and only the short form of the discriminator.
      info.manual_code.should match(/\A\d{4}-\d{3}-\d{4}\z/)
      Matter::SetupPayload.parse_manual_code(info.manual_code).last.should eq(device.setup_pin)
      info.qr_code_payload.should start_with("MT:")
      info.device_name.should eq("Matter Media")

      device.enter_operational_mode
      display.hidden?.should be_true
    ensure
      device.shutdown!
    end
  end
end
