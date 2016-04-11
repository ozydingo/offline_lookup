#
# 3Play Media: Cambridge, MA, USA
# support@3playmedia.com
#
# Copyright © 2012 3Play Media, Inc.  The following software is the sole and
# exclusive property of 3Play Media, Inc. and may not to be reproduced,
# modified, distributed or otherwise used, without the written approval
# of 3Play Media, Inc.
#
# This software is provided "as is" and any express or implied
# warranties, including but not limited to, an implied warranty of
# merchantability and fitness for a particular purpose are disclaimed.
#
# In no event shall 3Play Media, Inc. be liable for any direct,
# indirect, incidental, special, exemplary, or consequential damages
# (including but not limited to, procurement or substitute goods or
# services, loss of use, data or profits, or business interruption)
# however caused and on any theory of liability, whether in contract,
# strict liability, or tort (including negligence or otherwise) arising
# in any way out of the use of this software, even if advised of the
# possibility of such damage.
#

# In any ActiveRecord::Base subclass, use:
# >>  use_offline_id_lookup column_name
# to define class methods that can convert between id and the corresponding
# value in column_name for the class, without going to the database
# 
# column_name defaults to :name, but can be any column of the table
#
# Usage example:
# class JobType < ActiveRecord::Base
#   use_offline_id_lookup :name
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


# TODO: provide multiple column names in a single call

module OfflineIDLookup
  extend ActiveSupport::Concern

  module ClassMethods

    #can be used multiple times for different columns
    def use_offline_id_lookup(field = :name, identity_methods: false)
      #first find the current values in the database
      lookup_values = {}
      self.find_each do |row|
        lookup_values[row.id] = row[field]
      end

      # define class lookup methods that do not require db access
      self.singleton_class.instance_eval do
        # 1. klass.<name>_id
        lookup_values.each do |id, name|
          define_method "#{name}_id".methodize do
            id
          end
        end

        # 2. klass.<name>_for_id(id), klass.id_for_<name>(name)
        define_method "#{field}_for_id" do |id|
          lookup_values[id]
        end
        define_method "id_for_#{field}" do |name|
          lookup_values.keys.find{|id| lookup_values[id].methodize == name.to_s.methodize}
        end

        # 3. klass.offline_lookup(<name>)
        # Actually not really offline but does a search on the indexed primary key, so it's faster
        define_method "offline_lookup" do |name|
          name = name.to_s if name.is_a? Symbol
          self.find(lookup_values.key(name))
        end
      end

      # Define instance methods if requested
      if identity_methods
        lookup_values.each do |id, value|
          define_method("#{value}?".methodize) do
            self.id == id
          end
        end
      end

    end

  end  
end

ActiveRecord::Base.class_eval { include OfflineIDLookup }
