module OfflineLookup
  module Base
    extend ActiveSupport::Concern

    included do
      OfflineLookup::Builder.new(self, self.offline_lookup_options).build
    end
  end
end
