# IMPORTANT: don't use this for models that have a lot of data!!
#
# This is basically a in-memory pseudo-index intended to speed up quick, repeated
# finds of index table values without trips to an external db machine.
# It's also nicer syntax, e.g:
# TurnaroundLevel.two_hour_id
# TurnaroundLevel.quick_lookup("Two Hour")
# Service.last.turnaround_level.two_hour?
#
# In any ActiveRecord::Base subclass, use:
# >> use_offline_id_lookup column_name
# to define class methods that can convert between id and the corresponding
# value in column_name for the class, without going to the database
# 
# column_name defaults to :name, but can be any column of the table
# use the :key keyword arg if you're interested in a key colun other than :id
#
# Usage example:
# class JobType < ActiveRecord::Base
#   use_offline_id_lookup
#   ...
# end
#
# This gives you:
# JobType.editing_id
# #=> 1
# JobType.name_for_id(1)
# #=> 'Editing'
# JobType.id_for_name('Editing')
# #=> 1
# with no db queries.
#
# You can use this on multiple column names (currently 
# need to call use_offline_id_lookup once for each column name)
# class InvoiceLineItemType < ActiveRecord::Base
#   use_offline_id_lookup :name
#   use_offline_id_lookup :accounting_label
#   ...
#
# You get InvoiceLineItemType.name_for_id(id) and 
# InvoiceLineItemType.account_label_for_id(id), etc.
# Beware that if any value occurs more than once, 
# either in the same column or different columns for 
# which use_offline_id_lookup was called, the <name>_id 
# method will only use the last column for which it was observed.


#!!!
# TODO: requires :methodize
#!!!

# TODO: provide multiple column names in a single call (e.g. firstname, lastname)
# TODO: support multiple offline lookups per model
# TODO: support scope arg in use_offline_lookup (partial index)

module OfflineIDLookup
  module ActiveRecord
    def use_offline_lookup(field = :name, key: :id, lookup_methods: true)
      class_attribute :offline_lookup_values, :offline_lookup_options
      self.offline_lookup_options = {field: field.to_s, key: key.to_s, lookup_methods: lookup_methods}.freeze
      self.offline_lookup_values = self.all.pluck(key, field).to_h.freeze

      include OfflineIDLookup::Base
    end
  end

  class Builder
    def initialize(options)
      @field = options[:field]
      @key = options[:key]
    end

    def sanitize(string)
      s = string.strip.gsub(/[^\w\s]/,"").titlecase.gsub(/\s/, "").underscore
      s = "_#{s}" if s.length == 0 || s[0] =~ /\d/
      return s
    end

    # e.g., :two_hour_id
    def key_method_name(value)
      sanitize("#{value}_#{@key}")
    end

    def lookup_method_name(value)
      santiize(value.to_s)
    end

    # e.g., :two_hour?
    def indentiy_method_name(value)
      lookup_method_name(value) + "?"
    end

    # e.g. :name_for_id(id)
    def field_for_key_method_name
      "#{@field}_for_#{@key}" 
    end

    # e.g. :id_for_name(name)
    def key_for_field_method_name
      "#{@key}_for_#{@field}" 
    end

  end

  module Base
    extend ActiveSupport::Concern
    builder = OfflineIDLookup::Builder.new(self.offline_lookup_options)

    ### define value-named methods such as :two_hour_id and :two_hour?

    self.offline_lookup_values.each do |key, value|
      define_method builder.key_method_name(value) do
        key
      end

      define_method indentiy_method_name(value) do
        self.attributes[self.offline_lookup_options[:key]] == key
      end

      # not "Offline", but lookup by indexed key. Also, synactic sugar.
      if self.offline_lookup_options[:lookup_methods]
        define_method lookup_method_name(value) do
          key = self.offline_lookup_values.find{|k, v| v.to_s == value.to_s}
          find(key)
        end
      end
    end


    ### define statically-named methods where you pass in the named value, e.g., id_for_name(:two_hour)

    define_method field_for_key_method_name do |key_value|
      self.offline_lookup_values(key_value)
    end

    define_method key_for_field_method_name do |field_value|
      self.offline_lookup_values.find{|k, v| v.to_s == field_value.to_s}
    end

    def quick_lookup(value)
      key = self.offline_lookup_values.find{|k, v| v.to_s == value.to_s}
      find_by(self.offline_lookup_options[:key] => key)
    end
    def quick_lookup!(value)
      key = self.offline_lookup_values.find{|k, v| v.to_s == value.to_s}
      find(key)
    end

  end
end

ActiveRecord::Base.extend OfflineIDLookup::ActiveRecord
