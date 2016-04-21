# TODO: provide multiple column names in a single call (e.g. firstname, lastname)
# TODO: support multiple offline lookups per model
# TODO: support scope arg in use_offline_lookup (partial index)

module OfflineLookup
  module ActiveRecord
    def use_offline_lookup(field = :name, key: :id, identity_methods: true, lookup_methods: true)
      class_attribute :offline_lookup_values, :offline_lookup_options
      self.offline_lookup_options = {
        field: field.to_s,
        key: key.to_s,
        identity_methods: !!identity_methods,
        lookup_methods: !!lookup_methods
      }.freeze
      self.offline_lookup_values = self.all.pluck(key, field).to_h.freeze

      include OfflineLookup::Base
    end
  end

  class Builder
    def initialize(options)
      @field = options[:field]
      @key = options[:key]
    end

    def sanitize(string)
      #:methodize went away. Where did it go?
      #1. Replace illegal chars and _ boundaries with " " boundary
      string = string.gsub(/[^a-zA-Z\d]+/," ").strip
      #2. Insert " " boundary at snake-case boundaries
      string.gsub!(/([a-z])([A-Z])/){|s| "#{$1} #{$2}"}
      #3. underscore
      string.gsub!(/\s+/, "_")
      string.downcase!
      #4. Append underscore if name begins with digit
      string = "_#{string}" if string.length == 0 || string[0] =~ /\d/
      return string
    end

    # e.g., :two_hour_id
    def key_method_name(value)
      sanitize "#{value}_#{@key}"
    end

    def lookup_method_name(value)
      sanitize value.to_s
    end

    # e.g., :two_hour?
    def indentiy_method_name(value)
      lookup_method_name(value) + "?"
    end

    # e.g. :name_for_id(id)
    def field_for_key_method_name
      sanitize "#{@field}_for_#{@key}"
    end

    # e.g. :id_for_name(name)
    def key_for_field_method_name
      sanitize "#{@key}_for_#{@field}"
    end

  end

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
            key = self.offline_lookup_values.find{|k, v| v.to_s == value.to_s}.first
            find(key)
          end
        end
      end
  

      ### define statically-named methods where you pass in the named value, e.g., id_for_name(:two_hour)
      # e.g. FooType.name_for_id(1)
      define_singleton_method(builder.field_for_key_method_name) do |key_value|
        self.offline_lookup_values[key_value]
      end

      # e.g. FooType.id_for_name("Bar")
      define_singleton_method(builder.key_for_field_method_name) do |field_value|
        self.offline_lookup_values.find{|k, v| v.to_s == field_value.to_s}.first
      end

    end
  end
end

ActiveRecord::Base.extend OfflineLookup::ActiveRecord
