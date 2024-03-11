module Services
  class BlueskyService
    BLUESKY_URL = "https://bsky.social"
    BLUESKY_HANDLE = ENV["BLUESKY_HANDLE"]
    BLUESKY_PASSWORD = ENV["BLUESKY_PASSWORD"]
    TOKEN = ENV["BLUESKY_TOKEN"]

    attr_reader :log
    def initialize(log)
      @log = log
    end

    def post(page)
      log.info "Bluesky: posting #{page.page_nr} - '#{page.title}'"
      if App::DRY_RUN
        log.warn "Not posting since running in dry run mode"
        return
      end

      tokens = get_tokens

      blob_body = post_blob(tokens, page)

      post_record(tokens, page, blob_body)
    end

    private

    def headers(jwt_token = nil)
      if jwt_token.nil?
        {
          "Accept" => "application/json"
        }
      else
        {
          "Accept" => "application/json",
          "Authorization" => "Bearer #{jwt_token}"
        }
      end
    end

    def get_tokens
      conn = Faraday.new(url: BLUESKY_URL, headers: headers) { |f| f.request :json }
      response = conn.post("/xrpc/com.atproto.server.createSession", {
        identifier: BLUESKY_HANDLE,
        password: BLUESKY_PASSWORD
      })

      JSON.parse(response.body).slice("refreshJwt", "accessJwt")
    end

    def post_blob(tokens, page)
      conn = Faraday.new(url: BLUESKY_URL, headers: headers(tokens["accessJwt"]))
      blob = File.read(page.screenshot)
      response = conn.post("/xrpc/com.atproto.repo.uploadBlob", blob)

      JSON.parse(response.body)["blob"]
    end

    def post_record(tokens, page, blob_body)
      conn = Faraday.new(url: BLUESKY_URL, headers: headers(tokens["accessJwt"])) { |f| f.request :json }
      conn.post("/xrpc/com.atproto.repo.createRecord", {
        repo: BLUESKY_HANDLE,
        collection: "app.bsky.feed.post",
        record: {
          text: page.status_text,
          createdAt: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
          facets: [
            {
              index: {byteStart: 6, byteEnd: page.status_text.length},
              features: [
                {
                  "$type": "app.bsky.richtext.facet#link",
                  uri: page.nos_link
                }
              ]
            }
          ],
          embed: {
            "$type": "app.bsky.embed.images",
            images: [
              alt: page.alt_text,
              image: blob_body
            ]
          }
        }
      })
    end
  end
end
