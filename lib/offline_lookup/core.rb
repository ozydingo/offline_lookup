module OfflineLookup
  module Core
    extend ActiveSupport::Concern

    included do
      class_attribute :offline_lookup_values
      self.offline_lookup_values = get_offline_lookup_values

      after_create :set_class_offline_lookup_values, :add_to_offline_lookup
      after_destroy :set_class_offline_lookup_values
    end

    module ClassMethods
      def offline_lookup_value(*field_values)
        field_values.compact! if offline_lookup_options[:compact]
        if offline_lookup_options[:transform].present?
          offline_lookup_options[:transform].call(*field_values.map(&:to_s))
        else
          field_values.map(&:to_s).join(offline_lookup_options[:delimiter])
        end
      end

      def get_offline_lookup_values
        self.all.pluck(offline_lookup_options[:key], *offline_lookup_options[:fields]).map do |key_value, *field_values|
          [key_value, offline_lookup_value(*field_values)]
        end.to_h.freeze
      end
    end

    def set_class_offline_lookup_values
      self.class.offline_lookup_values = self.class.get_offline_lookup_values
    end

    def offline_lookup_value
      self.class.offline_lookup_value(*offline_lookup_options[:fields].map{|f| self.attributes[f.to_s]})
    end

    def add_to_offline_lookup
      builder = OfflineLookup::DynamicModuleBuilder.new(self.class, self.offline_lookup_options)
      builder.add_dynamic_lookup_methods(self.attributes[self.offline_lookup_options[:key]], offline_lookup_value)
    end

  end
end
