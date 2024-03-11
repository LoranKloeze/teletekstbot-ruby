module Services
  class MastodonService
    MASTODON_URL = "https://mastodon.nl"
    TOKEN = ENV["MASTODON_TOKEN"]

    attr_reader :log
    def initialize(log)
      @log = log
    end

    def post(page)
      log.info "Mastodon: posting #{page.page_nr} - '#{page.title}'"
      if App::DRY_RUN
        log.warn "Not posting since running in dry run mode"
        return
      end

      media_id = post_media(page)
      post_status(page, media_id)
    end

    private

    def post_media(page)
      conn = Faraday.new(url: MASTODON_URL, headers: headers) { |f| f.request :multipart }
      response = conn.post("/api/v2/media", {
        file: Faraday::Multipart::FilePart.new(page.screenshot, "image/png"),
        description: page.alt_text
      })
      JSON.parse(response.body)["id"]
    end

    def post_status(page, media_id)
      conn = Faraday.new(url: MASTODON_URL, headers: headers)

      form_params = {
        status: "#{page.status_text}\n#{page.nos_link}",
        media_ids: [media_id]
      }
      conn.post("/api/v1/statuses", form_params)
    end

    def headers
      {"Authorization" => "Bearer #{TOKEN}"}
    end
  end
end
