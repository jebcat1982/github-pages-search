require 'elasticsearch'
require 'elasticsearch/model'
require 'elasticsearch/persistence'

class PageRepository
  include Elasticsearch::Persistence::Repository

  def initialize(options={})
    index  'pages'
    type   'page'
    client Elasticsearch::Client.new url: ENV['ELASTICSEARCH_URL'] || ENV['BOXEN_ELASTICSEARCH_URL'] || ENV['BONSAI_URL'] || 'http://localhost:9200', log: true
  end

  klass Page

  analysis = { }

  analysis[:analyzer] = {
    :texty => {
      :tokenizer => 'standard',
      :filter    => %w[standard lowercase asciifolding keyword_repeat kstem texty_unique_words texty_words]
    },
    :texty_search => {
      :tokenizer => 'standard',
      :filter    => %w[standard lowercase asciifolding]
    }
  }

  analysis[:filter] = {
    :texty_unique_words => {
      :type                  => 'unique',
      :only_on_same_position => true
    },
    :texty_words => {
      :type => 'word_delimiter',
      :generate_word_parts     => true,   # If true causes parts of words to be generated: “PowerShot” => “Power” “Shot”. Defaults to true.
      :generate_number_parts   => true,   # If true causes number subwords to be generated: “500-42” => “500” “42”. Defaults to true.
      :catenate_words          => false,  # If true causes maximum runs of word parts to be catenated: “wi-fi” => “wifi”. Defaults to false.
      :catenate_numbers        => false,  # If true causes maximum runs of number parts to be catenated: “500-42” => “50042”. Defaults to false.
      :catenate_all            => false,  # If true causes all subword parts to be catenated: “wi-fi-4000” => “wifi4000”. Defaults to false.
      :split_on_case_change    => false,  # If true causes “PowerShot” to be two tokens; (“Power-Shot” remains two parts regards). Defaults to true.
      :preserve_original       => true,   # If true includes original words in subwords: “500-42” => “500” “42” “500-42”. Defaults to false.
      :split_on_numerics       => false,  # If true causes “j2se” to be three tokens; “j” “2” “se”. Defaults to true.
      :stem_english_possessive => false   # If true causes trailing “’s” to be removed for each subword: “O’Neil’s” => “O”, “Neil”. Defaults to true.
    }
  }

  settings({:index => {:analysis => analysis}})

  settings number_of_shards: 1 do
    mapping do
      indexes :title, type: 'string', analyzer: 'texty'
      indexes :body, type: 'string', analyzer: 'texty'
      indexes :path, type: 'string', index: :not_analyzed
      indexes :updated_at, type: 'date', index: :not_analyzed
    end
  end

  create_index! force: true

  def deserialize(document)
    Page.new document['_source'].merge('id' => document['_id'])
  end
end
