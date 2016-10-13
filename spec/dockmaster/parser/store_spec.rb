require 'fileutils'

RSpec.describe Dockmaster::Store do
  context 'if cache is cleared' do
    it 'is empty' do
      default_store = Dockmaster::Store.new(nil, :none, '')
      default_store.children << Dockmaster::Store.new(default_store, :module, 'Test')

      Dockmaster::Store.clear_cache

      expect(Dockmaster::Store.in_cache?(default_store, :module, 'Test')).to be_falsey
    end
  end

  context 'if a Store is not in the cache' do
    it 'returns a Store with the given parameters' do
      Dockmaster::Store.clear_cache
      default_store = Dockmaster::Store.new(nil, :none, '')
      store = Dockmaster::Store.from_cache(default_store, :module, 'Test')

      store_check = Dockmaster::Store.new(default_store, :module, 'Test')

      expect(store).to eq(store_check)
    end
  end
end
