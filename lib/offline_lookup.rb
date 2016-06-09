# TODO: support multiple offline lookups per model
# TODO: support scope arg in use_offline_lookup (partial index)

require 'offline_lookup/active_record.rb'
require 'offline_lookup/base.rb'
require 'offline_lookup/builder.rb'

ActiveRecord::Base.extend OfflineLookup::ActiveRecord
