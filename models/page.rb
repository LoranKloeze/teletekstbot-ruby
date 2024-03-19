module Models
  class Page
    attr_accessor :page_nr, :title, :body, :screenshot

    def alt_text
      "Pagina #{page_nr} - Titel: #{title} - Inhoud: #{body}"
    end

    def status_text
      "[#{page_nr}] #{title}"
    end

    def nos_link
      "https://nos.nl/teletekst/#{page_nr}"
    end
  end
end
