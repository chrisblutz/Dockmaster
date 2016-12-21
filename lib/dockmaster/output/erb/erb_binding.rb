require 'unparser'

module Dockmaster
  # Represents an ERB binding
  # for the templates
  class ERBBinding
    attr_reader :master_store, :store, :base_helper, :theme_helper

    def initialize(master_store, store, base_helper, theme_helper, renderer)
      @master_store = master_store
      @store = store

      @base_helper = base_helper
      @theme_helper = theme_helper

      @renderer = renderer
    end

    def erb_binding
      binding
    end

    def render
      return '' if @renderer.nil?
      @renderer.result(erb_binding)
    end

    def plugins
      Dockmaster::Plugin.plugins_by_id
    end
  end
end
