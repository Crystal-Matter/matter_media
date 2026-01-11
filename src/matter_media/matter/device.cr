require "log"
require "matter"

require "./media_backend"
require "./commissioning_display"

module MatterMedia
  module Matter
    class MediaDevice < ::Matter::Device::Base
      Log = ::Log.for(self)

      STORAGE_FILE = "matter_media_storage.json"

      MOMENTARY_RESET_DELAY = 150.milliseconds

      @backend : MediaBackend
      @commissioning_display : CommissioningDisplay?

      @vendor_id : UInt16
      @product_id : UInt16
      @discriminator : UInt16
      @setup_pin : UInt32

      @play_pause : ::Matter::Cluster::OnOffCluster? = nil
      @volume_on_off : ::Matter::Cluster::OnOffCluster? = nil
      @volume_level : ::Matter::Cluster::LevelControlCluster? = nil
      @next : ::Matter::Cluster::OnOffCluster? = nil
      @previous : ::Matter::Cluster::OnOffCluster? = nil

      @syncing_playback = false
      @syncing_volume = false
      @syncing_mute = false
      @resetting_next = false
      @resetting_previous = false

      def initialize(
        @backend : MediaBackend,
        @commissioning_display : CommissioningDisplay? = nil,
        ip_addresses : Array(Socket::IPAddress)? = nil,
      )
        @vendor_id = ::Matter::SetupPayload.test_vendor_id
        @product_id = 0x0001_u16
        @discriminator = ::Matter::SetupPayload.generate_random_discriminator
        @setup_pin = ::Matter::SetupPayload.generate_random_pin

        super(ip_addresses: ip_addresses || local_ips)

        wire_backend_callbacks
        sync_state_from_backend
      end

      def device_name : String
        "Matter Media"
      end

      def vendor_id : UInt16
        @vendor_id
      end

      def product_id : UInt16
        @product_id
      end

      def discriminator : UInt16
        @discriminator
      end

      def setup_pin : UInt32
        @setup_pin
      end

      def primary_device_type_id : UInt16
        ::Matter::DeviceTypes::ON_OFF_LIGHT_SWITCH
      end

      def vendor_name : String
        "Matter Media"
      end

      def product_name : String
        device_name
      end

      protected def build_storage_manager : ::Matter::Storage::Manager
        ::Matter::Storage::Manager.new(::Matter::Storage::JsonFileBackend.new(STORAGE_FILE))
      end

      protected def endpoint_device_types : Hash(UInt16, UInt32)
        {
          1_u16 => ::Matter::DeviceTypes::ON_OFF_LIGHT_SWITCH.to_u32,
          2_u16 => ::Matter::DeviceTypes::DIMMABLE_LIGHT.to_u32,
          3_u16 => ::Matter::DeviceTypes::ON_OFF_LIGHT_SWITCH.to_u32,
          4_u16 => ::Matter::DeviceTypes::ON_OFF_LIGHT_SWITCH.to_u32,
        } of UInt16 => UInt32
      end

      protected def device_clusters : Array(::Matter::Cluster::Base)
        clusters = [] of ::Matter::Cluster::Base

        playback_endpoint = ::Matter::DataType::EndpointNumber.new(1_u16)
        @play_pause = ::Matter::Cluster::OnOffCluster.new(playback_endpoint)
        @play_pause.not_nil!.on_state_changed { |new_state| handle_play_pause_change(new_state) }
        clusters << @play_pause.not_nil!

        volume_endpoint = ::Matter::DataType::EndpointNumber.new(2_u16)
        @volume_on_off = ::Matter::Cluster::OnOffCluster.new(
          volume_endpoint,
          feature_map: ::Matter::Cluster::OnOffCluster::Feature::Lighting
        )
        @volume_level = ::Matter::Cluster::LevelControlCluster.new(
          volume_endpoint,
          current_level: 0_u8,
          min_level: 0_u8,
          max_level: 254_u8,
          feature_map: ::Matter::Cluster::LevelControlCluster::Feature::OnOff |
                       ::Matter::Cluster::LevelControlCluster::Feature::Lighting
        )
        @volume_on_off.not_nil!.on_state_changed { |new_state| handle_mute_change(new_state) }
        @volume_level.not_nil!.on_level_changed { |old_level, new_level| handle_volume_change(old_level, new_level) }
        clusters << @volume_on_off.not_nil!
        clusters << @volume_level.not_nil!

        next_endpoint = ::Matter::DataType::EndpointNumber.new(3_u16)
        @next = ::Matter::Cluster::OnOffCluster.new(next_endpoint)
        @next.not_nil!.on_state_changed { |new_state| handle_next_change(new_state) }
        clusters << @next.not_nil!

        previous_endpoint = ::Matter::DataType::EndpointNumber.new(4_u16)
        @previous = ::Matter::Cluster::OnOffCluster.new(previous_endpoint)
        @previous.not_nil!.on_state_changed { |new_state| handle_previous_change(new_state) }
        clusters << @previous.not_nil!

        clusters
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
        cluster = @play_pause
        return unless cluster
        target = state == PlaybackState::Playing
        return if cluster.on? == target
        @syncing_playback = true
        cluster.on = target
      ensure
        @syncing_playback = false
      end

      private def update_volume_level(level : UInt8) : Nil
        cluster = @volume_level
        return unless cluster
        return if cluster.current_level == level
        @syncing_volume = true
        cluster.level = level
      ensure
        @syncing_volume = false
      end

      private def update_mute_state(muted : Bool) : Nil
        cluster = @volume_on_off
        return unless cluster
        target = !muted
        return if cluster.on? == target
        @syncing_mute = true
        cluster.on = target
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
        reset_momentary(@next, :next)
      end

      private def handle_previous_change(new_state : Bool) : Nil
        return if @resetting_previous
        return unless new_state
        @backend.previous_track
        reset_momentary(@previous, :previous)
      end

      private def reset_momentary(cluster : ::Matter::Cluster::OnOffCluster?, kind : Symbol) : Nil
        return unless cluster
        case kind
        when :next
          @resetting_next = true
        when :previous
          @resetting_previous = true
        end

        spawn do
          sleep MOMENTARY_RESET_DELAY
          cluster.on = false
          case kind
          when :next
            @resetting_next = false
          when :previous
            @resetting_previous = false
          end
        end
      end

      private def local_ips : Array(Socket::IPAddress)
        ips = [] of Socket::IPAddress

        begin
          socket = UDPSocket.new(:inet6)
          socket.connect("2606:4700:4700::1111", 53)
          addr = socket.local_address
          socket.close
          ips << Socket::IPAddress.new(addr.address, 0)
        rescue
        end

        begin
          socket = UDPSocket.new(:inet)
          socket.connect("8.8.8.8", 80)
          addr = socket.local_address
          socket.close
          ips << Socket::IPAddress.new(addr.address, 0)
        rescue
        end

        ips << Socket::IPAddress.new("127.0.0.1", 0) if ips.empty?
        ips
      end
    end
  end
end
