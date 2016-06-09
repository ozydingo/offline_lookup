module OfflineLookup
  class Builder
    def initialize(options)
      @fields = options[:fields]
      @key = options[:key]
      @name = options[:name]
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
      sanitize "#{@name}_for_#{@key}"
    end

    # e.g. :id_for_name(name)
    def key_for_field_method_name
      sanitize "#{@key}_for_#{@name}"
    end

  end
end
