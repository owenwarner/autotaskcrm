Gem::Specification.new do |s|
  s.name            = 'autotaskcrm'
  s.version         = '0.2'

  s.date            = '2012-11-26'
  s.summary         = "AutoTask functionality for Ruby."
  s.description     = "Commonly needed AutoTask functionality for Ruby projects."
  s.authors         = ["Mark Stanislav", "Matthew Warner"]
  s.email           = 'mark.stanislav@gmail.com'
  s.files           = ["lib/autotaskcrm.rb", "README.md"]
  s.homepage        = 'http://rubygems.org/gems/autotaskcrm'
  s.license         = 'MIT'

  s.add_dependency('savon', '~> 2.0')
  s.add_dependency('gyoku', '~> 1.0')
  s.add_dependency('httpclient', '~> 2.5.3.3')
end
