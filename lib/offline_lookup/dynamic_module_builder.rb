module OfflineLookup
  class DynamicModuleBuilder
    def initialize(model, options)
      @model = model
      @fields = options[:fields].map(&:to_s)
      @key_name = options[:key]
      @name = options[:name]
      @build_identity_methods = options[:identity_methods]
      @build_lookup_methods = options[:lookup_methods]
      @modyule = get_module || create_module
    end

    def get_module
      @model.const_defined?("OfflineLookupMethods") && @model::OfflineLookupMethods
    end

    def create_module
      modyule = Module.new
      modyule.extend ActiveSupport::Concern
      modyule.const_set("ClassMethods", Module.new)
      @model.const_set("OfflineLookupMethods", modyule)
      return modyule
    end

    def build_module
      add_all_dynamic_lookups
      add_name_for_key_method
      add_key_for_name_method
      add_static_lookup_method
      return @modyule
    end

    def add_all_dynamic_lookups
      @model.offline_lookup_values.each{|key_value, value| add_dynamic_lookup_methods(key_value, value)}
    end

    def add_dynamic_lookup_methods(key_value, value)
      add_key_lookup_method(key_value, value)
      add_identity_method(key_value, value) if @build_identity_methods
      add_lookup_method(key_value, value) if @build_lookup_methods
    end

    # Get key value (e.g. FooType.bar_id)
    def add_key_lookup_method(key_value, value)
      key_lookup_method_name = sanitize("#{value}_#{@key_name}")
      @modyule::ClassMethods.instance_exec(key_lookup_method_name, key_value, value) do |method_name, key_value|
        define_method method_name do
          key_value
        end
      end
    end

    # Return true iff instance is of named type (e.g. FooType.first.bar?)
    def add_identity_method(key_value, value)
      identify_method_name = sanitize(value) + "?"
      @modyule.instance_exec(identify_method_name, @key_name, key_value) do |method_name, key_name, key_value|
        define_method method_name do
          self.attributes[key_name] == key_value
        end
      end
    end

    # Get instance by named method (e.g. FooType.bar) (Not offline, but syntactic sugar)
    def add_lookup_method(key_value, value)
      lookup_method_name = sanitize(value)
      @modyule::ClassMethods.instance_exec(lookup_method_name, @key_name, key_value, value) do |method_name, key_name, key_value|
        define_method method_name do
          find_by(key_name => key_value)
        end
      end
    end

    # e.g. FooType.name_for_id(1)
    def add_name_for_key_method
      method_name = sanitize("#{@name}_for_#{@key_name}")
      @modyule::ClassMethods.instance_exec(method_name) do |method_name|
        define_method method_name do |key|
          self.offline_lookup_values[key]
        end
      end
    end

    # e.g. FooType.id_for_name("Bar")
    def add_key_for_name_method
      method_name = sanitize("#{@key_name}_for_#{@name}")
      @modyule::ClassMethods.instance_exec(method_name) do |method_name|
        define_method method_name do |value|
          self.offline_lookup_values.key(value.to_s)
        end
      end
    end

    # e.g. FooType.lookup("Bar")
    def add_static_lookup_method
      @modyule::ClassMethods.instance_exec(@key_name) do |key_name|
        define_method "lookup" do |value|
          find_by(key_name => self.offline_lookup_values.key(value.to_s))
        end
      end
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
  end
end
