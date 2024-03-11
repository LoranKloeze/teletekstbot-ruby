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

      media_id = post_media(page)
      conn = Faraday.new(url: MASTODON_URL, headers: headers)

      form_params = {
        status: construct_status(page),
        media_ids: [media_id]
      }
      response = conn.post("/api/v1/statuses", form_params)

      log.info(response.status)
    end

    private

    def construct_status(page)
      "[#{page.page_nr}] #{page.title}\nhttps://nos.nl/teletekst##{page.page_nr}"
    end

    def post_media(page)
      conn = Faraday.new(url: MASTODON_URL, headers: headers) { |f| f.request :multipart }
      response = conn.post("/api/v2/media", {
        file: Faraday::Multipart::FilePart.new(page.screenshot, "image/png"),
        description: "Pagina #{page.page_nr} - Titel: #{page.title} - Inhoud: #{page.body} "
      })
      JSON.parse(response.body)["id"]
    end

    def headers
      {"Authorization" => "Bearer #{TOKEN}"}
    end
  end
end
