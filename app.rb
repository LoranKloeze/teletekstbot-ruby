class App
  CHROME_HOST = ENV["CHROME_HOST"]
  DATA_LOCATION = ENV["DATA_LOCATION"]
  DRY_RUN = ENV["DRY_RUN"] == "true"

  attr_reader :log

  def initialize(log)
    @log = log
  end

  def run
    log.info "Starting deamon"
    log.info DRY_RUN ? "Running in dry run mode" : "Running in live mode"

    loop do
      log.info "Checking for new updates"
      updated_pages = contents_and_screenshots(fetch_updated_pages)
      if updated_pages.empty?
        log.info "No updated pages found"
      else
        log.info "Found updated pages: #{updated_pages.map { |p| p.page_nr }.join(", ")}"
        post_mastodon(updated_pages)
        post_bluesky(updated_pages)
      end

      log.info "Done..., waiting 3 minutes"
      sleep 180
    end
  end

  private

  def post_mastodon(pages)
    log.info "Posting to Mastodon"
    pages.each do |page|
      Services::MastodonService.new(log).post(page)
    end
  end

  def post_bluesky(pages)
    log.info "Posting to Bluesky"
    pages.each do |page|
      Services::BlueskyService.new(log).post(page)
    end
  end

  def contents_and_screenshots(pages)
    pages.map do |page|
      page_nr = page[:page_nr]

      screenshot_path = File.join(DATA_LOCATION, "regular#{page_nr}.png")

      browser = Capybara.current_session
      browser.visit "https://nos.nl/teletekst/#{page_nr}"
      browser.assert_selector("#fastText2Green")
      browser.execute_script("document.getElementById('sterad-container').remove()")

      # Get screenshot
      browser.save_screenshot(screenshot_path)
      cropped_screenshot_path = Services::CropImageService.new(screenshot_path, page_nr).crop
      log.info "Saved a cropped screenshot at #{cropped_screenshot_path}"

      # Get contents 
      rows = browser.find_all('#content > section > div')[0].text.split("\n")
      browser.driver.quit

      title = []
      body = []
      section = :outside

      rows.each_with_index do |row, idx|
        next if idx < 2
        section = :title if idx == 2

        if section == :title
          if row.start_with?("")
            section = :body
            next
          end
          title << row.strip
        end

        if section == :body
          if row.start_with?("")
            break
          end
          body << row.delete("").strip
        end
      end

      Models::Page.new.tap do |p|
        p.page_nr = page_nr
        p.title = title.join(" ")
        p.body = body.join("\n")
        p.screenshot = cropped_screenshot_path
      end
    end
  end

  def fetch_updated_pages
    browser = Capybara.current_session
    browser.visit "https://nos.nl/teletekst/101"
    current_pages = []

    rows = browser.find_all('#content > section > div')[0].text.split("\n")
    browser.driver.quit

    pages_seen = []
    rows.each_with_index do |row, idx|
      next if idx < 5

      page_nr = row[-3..].to_i
      next unless page_nr > 100
      next if pages_seen.include?(page_nr)
      
      current_pages << {page_nr: page_nr, title: row[0..-4].strip}
      pages_seen << page_nr
    end
    updated_pages = []

    pages_cache = File.join(DATA_LOCATION, "pages.json")
    if File.exist?(pages_cache)
      saved_pages = File.read(pages_cache)
      saved_pages = JSON.parse(saved_pages)
      current_pages.each do |current_page|
        saved_page = saved_pages.find { |sp| sp["page_nr"] == current_page[:page_nr] }
        if saved_page.nil? || saved_page["title"] != current_page[:title]
          updated_pages << current_page
        end
      end
    else
      updated_pages = current_pages
    end

    File.write(pages_cache, current_pages.to_json)
    updated_pages
  end
end
