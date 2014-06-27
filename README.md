# Fitquery

Tools for inspecting and querying a FitNesse test hierarchy.
This Ruby gem allows you to create an enumerable structure that represents an entire test hierarchy, and then inspect that
structure. For example, let's say that your organization makes heavy use of tags in FitNesse, and you would like to find
all the tests that are not included by a particular tag. That could be done like this:

    fitnesse = FitnesseRoot.new("C:/gitrepos/centralrepobare/FitTest/FitNesseRoot")
    untagged = fitnesse.find_all {|node|
      node.runable? && node.test? && !node.has_tag?('Nightly')
    }
    puts untagged


## Installation

Add this line to your application's Gemfile:

    gem 'fitquery'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install fitquery


## Contributing

1. Fork it ( https://github.com/[my-github-username]/fitquery/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
