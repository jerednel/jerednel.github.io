# frozen_string_literal: true

# Jekyll 3 / Liquid 4 still expects Ruby's legacy taint API.
# GitHub Pages currently runs on Ruby 3.2+, where those methods are gone.
module LiquidCompat
  module LegacyTaintAPI
    def tainted?
      false
    end

    def taint
      self
    end

    def untaint
      self
    end
  end
end

Object.include(LiquidCompat::LegacyTaintAPI) unless Object.method_defined?(:tainted?)
