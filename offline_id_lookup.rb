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
    def use_offline_lookup(field = :name, key: :id, identity_methods: false)
      class_attribute :offline_lookup_values, :offline_lookup_options
      self.offline_lookup_options = {field: field.to_s, key: key.to_s, identity_methods: identity_methods}.freeze
      self.offline_lookup_values = self.all.pluck(key, field).to_h.freeze

      include OfflineIDLookup::Base
    end
  end

  module Base
    extend ActiveSupport::Concern

    # define methods such as :two_hour_id and :id_for_name
    self.offline_lookup_values.each do |key, value|
      # e.g., :two_hour_id
      define_method "#{value.to_s.methodize}_#{self.offline_lookup_options[:key]}" do
        key
      end

      # e.g., :two_hour?
      if self.offline_lookup_options[:identity_methods]
        define_method "#{value.to_s.methodize}?" do
          self.attributes[self.offline_lookup_options[:key]] == key
        end
      end
    end

    # e.g. :name_for_id(id)
    define_method "#{self.offline_lookup_options[:field]}_for_#{self.offline_lookup_options[:key]}" do |key|
      self.offline_lookup_values(key)
    end

    # e.g. :id_for_name(name)
    define_method "#{self.offline_lookup_options[:key]}_for_#{self.offline_lookup_options[:field]}" do |value|
      self.offline_lookup_values.find{|k, v| v.to_s == value.to_s}
    end

    # e.g. quick_lookup(:two_hour)
    # not offline, but looks up by key which is usually indexed. Also syntactic sugar.
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
