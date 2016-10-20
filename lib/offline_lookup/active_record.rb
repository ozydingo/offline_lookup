module OfflineLookup
  module ActiveRecord
    extend ActiveSupport::Concern

    module ClassMethods
      def use_offline_lookup(*fields, key: "id", identity_methods: false, lookup_methods: false, compact: false, delimiter: " ", name: fields.join(delimiter), transform: nil)
        class_attribute :offline_lookup_options
        self.offline_lookup_options = {
          fields: fields.map(&:to_s),
          key: key.to_s,
          identity_methods: !!identity_methods,
          lookup_methods: !!lookup_methods,
          compact: !!compact,
          delimiter: delimiter.to_s,
          name: name,
          transform: transform
        }
        include OfflineLookup::Core
        include OfflineLookup::DynamicModuleBuilder.new(self, self.offline_lookup_options).build_module
      end
    end
  end
end
