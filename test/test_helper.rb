require 'rubygems'
require 'spork'
#uncomment the following line to use spork with the debugger
#require 'spork/ext/ruby-debug'

Spork.prefork do
  # Loading more in this block will cause your tests to run faster. However,
  # if you change any configuration or code from libraries loaded here, you'll
  # need to restart spork for it take effect.
  require 'cover_me'
  ENV["RAILS_ENV"] = "test"
  require File.expand_path('../../config/environment', __FILE__)
  require 'rails/test_help'

  require 'factory_girl'
  require 'mocha'

  # you will have to restart guard when you modify factories
  # if you don't like this, put this line under #each_run()
  FactoryGirl.find_definitions
end

Spork.each_run do
  # This code will be run each time you run your specs.
end

class ActiveSupport::TestCase
  def dump_database
    Mongoid::Config.master.collections.each do |collection|
      collection.drop unless collection.name.include?('system.')
    end
  end

  def raw_post(action, body, parameters = nil, session = nil, flash = nil)
    @request.env['RAW_POST_DATA'] = body
    post(action, parameters, session, flash)
  end
  
  def basic_signin(user)
     @request.env['HTTP_AUTHORIZATION'] = "Basic #{ActiveSupport::Base64.encode64("#{user.username}:#{user.password}")}"
  end

  def collection_fixtures(*collection_names)
    collection_names.each do |collection|
      MONGO_DB[collection].drop
      Dir.glob(File.join(Rails.root, 'test', 'fixtures', collection, '*.json')).each do |json_fixture_file|
        fixture_json = JSON.parse(File.read(json_fixture_file))
          MONGO_DB[collection].save(fixture_json)
      end
    end
  end
  
  def hash_includes?(expected, actual)
    if (actual.is_a? Hash)
      (expected.keys & actual.keys).all? {|k| expected[k] == actual[k]}
    elsif (actual.is_a? Array )
      actual.any? {|value| hash_includes? expected, value}
    else 
      false
    end
  end
  
  def assert_query_results_equal(factory_result, result)
    
    factory_result.each do |key, value|
      assert_equal value, result[key] unless key == '_id'
    end
    
  end
  
  def expose_tempfile(fixture)
    class << fixture
      attr_reader :tempfile
    end
    fixture
  end
end