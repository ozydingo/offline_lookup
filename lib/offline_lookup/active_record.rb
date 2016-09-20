module OfflineLookup
  module ActiveRecord
    extend ActiveSupport::Concern

    included do
      after_create :get_offline_lookup_values, :add_offline_lookup
      after_destroy :get_offline_lookup_values
    end

    def get_offline_lookup_values
      self.class.get_offline_lookup_values
    end

    def offline_lookup_value
      self.class.offline_lookup_value(*offline_lookup_options[:fields].map{|f| self.attributes[f.to_s]})
    end

    def add_offline_lookup
      builder = OfflineLookup::Builder.new(self.class, self.offline_lookup_options)
      builder.add_lookup(self.attributes[builder.key], offline_lookup_value)
    end

    module ClassMethods
      def use_offline_lookup(*fields, key: "id", identity_methods: false, lookup_methods: false, compact: false, delimiter: " ", name: fields.join(delimiter), transform: nil)
        class_attribute :offline_lookup_values, :offline_lookup_options
        self.offline_lookup_options = {
          fields: fields.map(&:to_s),
          key: key.to_s,
          identity_methods: !!identity_methods,
          lookup_methods: !!lookup_methods,
          compact: !!compact,
          delimiter: delimiter.to_s,
          name: name,
          transform: transform
        }.freeze

        get_offline_lookup_values

        include OfflineLookup::Base
      end

      def offline_lookup_value(*fields)
        if offline_lookup_options[:transform].present?
          offline_lookup_options[:transform].call(*fields.map(&:to_s))
        else
          fields.map(&:to_s).join(offline_lookup_options[:delimiter])
        end
      end

      def get_offline_lookup_values
        self.offline_lookup_values = self.all.pluck(offline_lookup_options[:key], *offline_lookup_options[:fields]).map do |key, *fields|
          fields.compact! if offline_lookup_options[:compact]
          value = offline_lookup_options[:transform].present? ? offline_lookup_options[:transform].call(*fields.map(&:to_s)) : fields.map(&:to_s).join(offline_lookup_options[:delimiter])
          [key, value.to_s]
        end.to_h.freeze
      end

    end
  end
end
