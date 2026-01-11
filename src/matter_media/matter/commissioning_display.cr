module MatterMedia
  module Matter
    struct CommissioningInfo
      getter manual_code : String
      getter qr_code_payload : String
      getter device_name : String

      def initialize(
        @manual_code : String,
        @qr_code_payload : String,
        @device_name : String,
      )
      end
    end

    module CommissioningDisplay
      abstract def show(info : CommissioningInfo) : Nil
      abstract def hide : Nil
    end
  end
end
