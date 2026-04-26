RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, type: :system, js: true) do
    # Capybara's JS driver pings the test server via localhost — allow it through WebMock
    WebMock.allow_net_connect!
    if ENV["SELENIUM_REMOTE_URL"].present?
      driven_by :selenium, using: :chrome, screen_size: [1400, 1400],
                           options: {
                             browser: :remote,
                             url: ENV["SELENIUM_REMOTE_URL"],
                             desired_capabilities: Selenium::WebDriver::Remote::Capabilities.chrome(
                               chromeOptions: { args: %w[headless disable-gpu no-sandbox disable-dev-shm-usage] }
                             )
                           }
    else
      driven_by :selenium_chrome_headless, screen_size: [1400, 1400]
    end
  end
end
