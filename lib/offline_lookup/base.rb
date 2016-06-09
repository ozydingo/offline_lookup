module OfflineLookup
  module Base
    extend ActiveSupport::Concern

    included do
      builder = OfflineLookup::Builder.new(self.offline_lookup_options)

      ### define value-named methods such as :two_hour_id and :two_hour?

      self.offline_lookup_values.each do |key, value|
        # class method: get key value (e.g. FooType.bar_id)
        define_singleton_method(builder.key_method_name(value)) do
          key
        end

        # instance method: true if instance is of named type (e.g. FooType.first.bar?)
        if self.offline_lookup_options[:identity_methods]
          define_method(builder.indentiy_method_name(value)) do
            self.attributes[self.offline_lookup_options[:key]] == key
          end
        end

        # class method: get instance by named method (e.g. FooType.bar)
        # not "Offline", but lookup by indexed key. Also, synactic sugar.
        if self.offline_lookup_options[:lookup_methods]
          define_singleton_method(builder.lookup_method_name(value)) do
            key = self.offline_lookup_values.find{|k, v| v.to_s == value.to_s}.try(:first)
            find(key)
          end
        end

        # class method: get instance using more general `lookup` method
        # Just as not "offline" as above, but less dangerous / more robust to any db value
        define_singleton_method :lookup do |value|
          key = self.offline_lookup_values.find{|k, v| v.to_s == value.to_s}.try(:first)
          find_by(id: key)
        end
      end
  

      ### define statically-named methods where you pass in the named value, e.g., id_for_name(:two_hour)
      # e.g. FooType.name_for_id(1)
      define_singleton_method(builder.field_for_key_method_name) do |key_value|
        self.offline_lookup_values[key_value]
      end

      # e.g. FooType.id_for_name("Bar")
      define_singleton_method(builder.key_for_field_method_name) do |field_value|
        self.offline_lookup_values.find{|k, v| v.to_s == field_value.to_s}.try(:first)
      end

    end
  end
end
