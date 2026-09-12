require "log"
require "matter"

require "./media_backend"
require "./commissioning_display"

module MatterMedia
  module Matter
    class MediaDevice < ::Matter::Device
      Log = ::Log.for(self)

      STORAGE_FILE = "matter_media_storage.yml"

      MOMENTARY_RESET_DELAY = 150.milliseconds

      PLAYBACK_ENDPOINT = 1_u16
      VOLUME_ENDPOINT   = 2_u16
      NEXT_ENDPOINT     = 3_u16
      PREVIOUS_ENDPOINT = 4_u16

      VOLUME_MIN =   0_u8
      VOLUME_MAX = 254_u8

      identity vendor: "Matter Media", product: "Matter Media",
        vendor_id: ::Matter::SetupPayload.test_vendor_id,
        product_id: 0x0001_u16,
        discriminator: ::Matter::SetupPayload.generate_random_discriminator,
        pin: ::Matter::SetupPayload.generate_random_pin,
        device_type: ::Matter::DeviceType::ON_OFF_LIGHT_SWITCH

      # Apple Home only renders a handful of device types, so the media controls
      # are presented as switches and a dimmable light (see README).
      endpoint PLAYBACK_ENDPOINT, device_type: ::Matter::DeviceType::ON_OFF_LIGHT_SWITCH do
        cluster ::Matter::Cluster::OnOff, as: :play_pause
        # The On/Off Light Switch device type requires Identify.
        cluster ::Matter::Cluster::Identify, identify_type: :visible_light
        cluster ::Matter::Cluster::FixedLabel, [::Matter::Cluster::LabelStruct.new("name", "Play/Pause")]
        cluster ::Matter::Cluster::UserLabel, [::Matter::Cluster::LabelStruct.new("name", "Play/Pause")]
      end

      endpoint VOLUME_ENDPOINT, device_type: ::Matter::DeviceType::DIMMABLE_LIGHT do
        cluster ::Matter::Cluster::OnOff, feature_map: :lighting, as: :volume_on_off
        cluster ::Matter::Cluster::LevelControl,
          current_level: VOLUME_MIN,
          min_level: VOLUME_MIN,
          max_level: VOLUME_MAX,
          feature_map: ::Matter::Cluster::LevelControl::Feature::OnOff |
                       ::Matter::Cluster::LevelControl::Feature::Lighting,
          as: :volume_level
        cluster ::Matter::Cluster::Identify, identify_type: :visible_light
        # The Dimmable Light device type requires Groups.
        cluster ::Matter::Cluster::Groups
        cluster ::Matter::Cluster::FixedLabel, [::Matter::Cluster::LabelStruct.new("name", "Volume")]
        cluster ::Matter::Cluster::UserLabel, [::Matter::Cluster::LabelStruct.new("name", "Volume")]
      end

      endpoint NEXT_ENDPOINT, device_type: ::Matter::DeviceType::ON_OFF_LIGHT_SWITCH do
        cluster ::Matter::Cluster::OnOff, as: :skip_next
        cluster ::Matter::Cluster::Identify, identify_type: :visible_light
        cluster ::Matter::Cluster::FixedLabel, [::Matter::Cluster::LabelStruct.new("name", "Next")]
        cluster ::Matter::Cluster::UserLabel, [::Matter::Cluster::LabelStruct.new("name", "Next")]
      end

      endpoint PREVIOUS_ENDPOINT, device_type: ::Matter::DeviceType::ON_OFF_LIGHT_SWITCH do
        cluster ::Matter::Cluster::OnOff, as: :skip_previous
        cluster ::Matter::Cluster::Identify, identify_type: :visible_light
        cluster ::Matter::Cluster::FixedLabel, [::Matter::Cluster::LabelStruct.new("name", "Previous")]
        cluster ::Matter::Cluster::UserLabel, [::Matter::Cluster::LabelStruct.new("name", "Previous")]
      end

      on(:play_pause, :state_changed) { |state| handle_play_pause_change(state) }
      on(:volume_on_off, :state_changed) { |state| handle_mute_change(state) }
      on(:volume_level, :level_changed) { |old_level, new_level| handle_volume_change(old_level, new_level) }
      on(:skip_next, :state_changed) { |state| handle_next_change(state) }
      on(:skip_previous, :state_changed) { |state| handle_previous_change(state) }

      @backend : MediaBackend
      @commissioning_display : CommissioningDisplay?

      @syncing_playback = false
      @syncing_volume = false
      @syncing_mute = false
      @resetting_next = false
      @resetting_previous = false

      def initialize(
        @backend : MediaBackend,
        @commissioning_display : CommissioningDisplay? = nil,
        storage : ::Matter::Storage::Backend = ::Matter::Storage::YamlFile.new(STORAGE_FILE),
        ip_addresses : Array(Socket::IPAddress)? = nil,
        port : Int32 = ::Matter::Device::DEFAULT_PORT,
      )
        super(storage, ip_addresses: ip_addresses, port: port)

        wire_backend_callbacks
        sync_state_from_backend
      end

      protected def started_commissioning_mode : Nil
        show_commissioning_display
      end

      protected def started_operational_mode : Nil
        @commissioning_display.try &.hide
      end

      private def show_commissioning_display : Nil
        display = @commissioning_display
        return unless display
        info = CommissioningInfo.new(
          manual_code: manual_code,
          qr_code_payload: qr_code_payload,
          device_name: device_name
        )
        display.show(info)
      end

      private def manual_code : String
        ::Matter::SetupPayload.generate_manual_code(discriminator, setup_pin)
      end

      private def qr_code_payload : String
        ::Matter::SetupPayload::QRCode.generate_qr_code(
          discriminator: discriminator,
          pin: setup_pin,
          vendor_id: vendor_id,
          product_id: product_id,
          flow: ::Matter::SetupPayload::QRCode::CommissionFlow::Standard,
          capabilities: ::Matter::SetupPayload::QRCode::DiscoveryCapability::BLE
        )
      end

      private def wire_backend_callbacks : Nil
        @backend.on_playback_state { |state| update_playback_state(state) }
        @backend.on_volume_level { |level| update_volume_level(level) }
        @backend.on_mute_state { |muted| update_mute_state(muted) }
      end

      private def sync_state_from_backend : Nil
        update_playback_state(@backend.playback_state)
        update_volume_level(@backend.volume_level)
        update_mute_state(@backend.mute?)
      rescue ex
        Log.warn(exception: ex) { "matter: failed to sync backend state" }
      end

      private def update_playback_state(state : PlaybackState) : Nil
        target = state == PlaybackState::Playing
        return if play_pause.on? == target
        @syncing_playback = true
        play_pause.on = target
      ensure
        @syncing_playback = false
      end

      private def update_volume_level(level : UInt8) : Nil
        return if volume_level.current_level == level
        @syncing_volume = true
        volume_level.level = level
      ensure
        @syncing_volume = false
      end

      private def update_mute_state(muted : Bool) : Nil
        target = !muted
        return if volume_on_off.on? == target
        @syncing_mute = true
        volume_on_off.on = target
      ensure
        @syncing_mute = false
      end

      private def handle_play_pause_change(new_state : Bool) : Nil
        return if @syncing_playback
        if new_state
          @backend.play
        else
          @backend.pause
        end
      end

      private def handle_volume_change(_old_level : UInt8, new_level : UInt8) : Nil
        return if @syncing_volume
        @backend.set_volume_level(new_level)
        @backend.set_mute(false) if @backend.mute?
      end

      private def handle_mute_change(new_state : Bool) : Nil
        return if @syncing_mute
        @backend.set_mute(!new_state)
      end

      private def handle_next_change(new_state : Bool) : Nil
        return if @resetting_next
        return unless new_state
        @backend.next_track
        @resetting_next = true
        reset_momentary(skip_next) { @resetting_next = false }
      end

      private def handle_previous_change(new_state : Bool) : Nil
        return if @resetting_previous
        return unless new_state
        @backend.previous_track
        @resetting_previous = true
        reset_momentary(skip_previous) { @resetting_previous = false }
      end

      # A momentary button reports itself off again shortly after it was pressed,
      # without the release looking like a command from the controller.
      private def reset_momentary(cluster : ::Matter::Cluster::OnOff, &released : -> Nil) : Nil
        spawn do
          sleep MOMENTARY_RESET_DELAY
          cluster.on = false
          released.call
        end
      end
    end
  end
end
