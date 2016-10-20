# TODO: support multiple offline lookups per model
# TODO: support scope arg in use_offline_lookup (partial index)

require 'offline_lookup/active_record.rb'
require 'offline_lookup/core.rb'
require 'offline_lookup/dynamic_module_builder.rb'

ActiveRecord::Base.include OfflineLookup::ActiveRecord
