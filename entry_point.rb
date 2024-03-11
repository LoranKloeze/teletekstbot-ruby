#!/bin/env ruby

require "dotenv/load"
require "bundler"
require "syslog/logger"
Bundler.require

loader = Zeitwerk::Loader.new
loader.push_dir(".")
loader.setup

log = Logger.new($stdout)

raise "Set env var CHROME_HOST to e.g. 'http://localhost:8890'" if ENV["CHROME_HOST"].nil?

log.info "Setting up Capybara with Chrome host #{ENV["CHROME_HOST"]}"
Capybara.register_driver :remote_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--no-sandbox")
  options.add_argument("--headless")
  options.add_argument("--window-size=800,800")
  Capybara::Selenium::Driver.new(app,
    browser: :remote,
    url: "#{ENV["CHROME_HOST"]}/webdriver",
    options: options)
end
Capybara.default_driver = :remote_chrome

app = App.new(log)
app.run
