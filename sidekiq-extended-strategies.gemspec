# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.authors       = ['Alexander Maznev']
  gem.email         = ['alexander.maznev@gmail.com']
  gem.description   = gem.summary = 'Extended strategies for sidekiq workers'
  gem.homepage      = 'https://github.com/pik/sidekiq-extended-strategies'
  gem.license       = 'MIT'


  gem.post_install_message = 'Note that sidekiq-extended-strategies requires Redis > 2.6'
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- spec/*`.split("\n")
  gem.name          = 'sidekiq-extended-strategies'
  gem.require_paths = ['.', 'lib']
  gem.version = '0.0.1'
  gem.add_dependency 'sidekiq', '>= 2.6'
  gem.add_development_dependency 'rspec', '~> 3.1.0'
end
