# -*- encoding: utf-8 -*-
module Recipes0
  class Version
    MAJOR = 1
    MINOR = 1
    PATCH = 1

    def self.to_s
      "#{MAJOR}.#{MINOR}.#{PATCH}"
    end
  end
end
