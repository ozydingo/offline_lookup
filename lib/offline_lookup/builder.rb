module OfflineLookup
  class Builder
    attr_reader :fields, :key, :name
    def initialize(model, options)
      @model = model
      @fields = options[:fields]
      @key = options[:key]
      @name = options[:name]
      @build_identity_methods = options[:identity_methods]
      @build_lookup_methods = options[:lookup_methods]
      @modyule = get_module || create_module
    end

    def get_module
      @model.const_defined?("OfflineLookupMethods") && @model::OfflineLookupMethods
    end

    def create_module
      @modyule = Module.new
      @modyule.extend ActiveSupport::Concern
      @modyule.const_set("ClassMethods", Module.new)
      @model.const_set("OfflineLookupMethods", @modyule)
    end

    def build
      @model.offline_lookup_values.each do |key, value|
        add_lookup(key, value)
      end
      add_name_for_key_method
      add_key_for_name_method
      add_static_lookup_method
      @model.include @modyule
    end

    def add_lookup(key, value)
      add_key_lookup_method(key, value)
      add_identity_method(key, value) if @build_identity_methods
      add_lookup_method(key, value) if @build_lookup_methods
    end

    def sanitize(string)
      #1. Replace illegal chars and _ boundaries with " " boundary
      string = string.to_s.gsub(/[^a-zA-Z\d]+/," ").strip
      #2. Insert " " boundary at snake-case boundaries
      string.gsub!(/([a-z])([A-Z])/){|s| "#{$1} #{$2}"}
      #3. underscore
      string.gsub!(/\s+/, "_")
      string.downcase!
      #4. Append underscore if name begins with digit
      string = "_#{string}" if string.length == 0 || string[0] =~ /\d/
      return string
    end

    # Get key value (e.g. FooType.bar_id)
    def add_key_lookup_method(key, value)
      @modyule::ClassMethods.instance_exec(self, key, value) do |builder, key, value|
        define_method builder.sanitize("#{value}_#{builder.key}") do
          key
        end
      end
    end

    # Return true iff instance is of named type (e.g. FooType.first.bar?)
    def add_identity_method(key, value)
      @modyule.instance_exec(self, key, value) do |builder, key, value|
        define_method builder.sanitize(value) + "?" do
          self.attributes[builder.key] == key
        end
      end
    end

    # Get instance by named method (e.g. FooType.bar) (Not offline, but syntactic sugar)
    def add_lookup_method(key, value)
      @modyule::ClassMethods.instance_exec(self, key, value) do |builder, key, value|
        define_method builder.sanitize(value) do
          find_by(builder.key => self.offline_lookup_values.key(value.to_s))
        end
      end
    end

    # e.g. FooType.name_for_id(1)
    def add_name_for_key_method
      @modyule::ClassMethods.instance_exec(self) do |builder|
        define_method builder.sanitize("#{builder.name}_for_#{builder.key}") do |key|
          self.offline_lookup_values[key]
        end
      end
    end

    # e.g. FooType.id_for_name("Bar")
    def add_key_for_name_method
      @modyule::ClassMethods.instance_exec(self) do |builder|
        define_method builder.sanitize("#{builder.key}_for_#{builder.name}") do |value|
          self.offline_lookup_values.key(value.to_s)
        end
      end
    end

    # e.g. FooType.lookup("Bar")
    def add_static_lookup_method
      @modyule::ClassMethods.instance_exec(self) do |builder|
        define_method "lookup" do |value|
          find_by(builder.key => self.offline_lookup_values.key(value.to_s))
        end
      end
    end

  end
end
