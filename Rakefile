begin
  require 'rspec/core/rake_task'
  require 'rubocop/rake_task'

  RSpec::Core::RakeTask.new(:spec) do |t|
    t.pattern = 'spec/**/*_spec.rb'
    t.rspec_opts = '--format documentation'
    t.verbose = false
  end

  RuboCop::RakeTask.new

  task default: [:spec, :rubocop]
rescue LoadError
  # Non-testing environment
end

require 'dockmaster/rake_task'

Dockmaster::RakeTask.new
