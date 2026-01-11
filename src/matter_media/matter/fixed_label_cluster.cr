require "json"
require "matter"

module Matter
  module Cluster
    struct LabelStruct
      include TLV::Serializable
      include JSON::Serializable

      @[TLV::Field(tag: 0)]
      property label : String

      @[TLV::Field(tag: 1)]
      property value : String

      def initialize(@label : String, @value : String)
      end
    end

    class FixedLabelCluster < Base
      CLUSTER_ID = 0x0040_u32

      ATTR_LABEL_LIST = 0x0000_u32

      @label_list : Array(LabelStruct)

      def initialize(endpoint_id : DataType::EndpointNumber, label_list : Array(LabelStruct))
        super(endpoint_id, DataType::ClusterId.new(CLUSTER_ID))
        @label_list = label_list
        @attribute_values[ATTR_LABEL_LIST] = label_list.to_tlv
      end

      def name : String
        "FixedLabel"
      end

      def attributes : Array(AttributeMetadata)
        [
          AttributeMetadata.new(
            DataType::AttributeId.new(ATTR_LABEL_LIST),
            "LabelList",
            :list,
            writable: false
          ),
        ]
      end

      def read_attribute(attribute_id : UInt32, fabric_index : UInt8? = nil) : InteractionModel::Status | Bytes
        case attribute_id
        when ATTR_LABEL_LIST
          @label_list.to_tlv
        else
          super
        end
      end

      protected def encode_cluster_revision_global : Bytes
        1_u16.to_tlv
      end
    end
  end
end
