module OfflineLookup
  module ActiveRecord
    def use_offline_lookup(*fields, key: "id", identity_methods: false, lookup_methods: false, compact: false, delimiter: " ", name: fields.join(delimiter))
      class_attribute :offline_lookup_values, :offline_lookup_options
      self.offline_lookup_options = {
        fields: fields.map(&:to_s),
        key: key.to_s,
        identity_methods: !!identity_methods,
        lookup_methods: !!lookup_methods,
        compact: !!compact,
        delimiter: delimiter.to_s,
        name: name
      }.freeze

      self.offline_lookup_values = self.all.pluck(key, *fields).map do |key, *fields|
        fields.compact! if compact
        [key, fields.map(&:to_s).join(delimiter)]
      end.to_h.freeze

      include OfflineLookup::Base
    end
  end
end
