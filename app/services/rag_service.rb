require 'rest-client'
require 'numo/narray'
require 'openai'
require 'faiss'


class RagService
  def initialize
    @client = OpenAI::Client.new(
      access_token: ENV['OPEN_AI_API_KEY']
    )
    setup_knowledge_base
  end

  def call(question)
    search_similar_chunks(question)
    prompt = build_prompt(question)
    run_completion(prompt)
  end

  private

  def setup_knowledge_base
    load_text_from_url("https://raw.githubusercontent.com/run-llama/llama_index/main/docs/docs/examples/data/paul_graham/paul_graham_essay.txt")
    chunk_text
    create_embeddings
    create_index
  end

  def load_text_from_url(url)
    response = RestClient.get(url)
    @text = response.body
  end

  def chunk_text(chunk_size = 2048)
    @chunks = @text.chars.each_slice(chunk_size).map(&:join)
  end

  def get_text_embedding(input)
    response = @client.embeddings(
      parameters: {
        model: 'text-embedding-3-small',
        input: input
      }
    )
    response.dig('data', 0, 'embedding')
  end

  def create_embeddings
    @text_embeddings = @chunks.map { |chunk| get_text_embedding(chunk) }
    @text_embeddings = Numo::DFloat[*@text_embeddings]
  end

  def create_index
    d = @text_embeddings.shape[1]
    @index = Faiss::IndexFlatL2.new(d)
    @index.add(@text_embeddings)
  end

  def search_similar_chunks(question, k = 2)
    # Ensure index exists before searching
    raise "No index available. Please load and process text first." if @index.nil?

    question_embedding = get_text_embedding(question)
    distances, indices = @index.search([question_embedding], k)
    index_array = indices.to_a[0]
    @retrieved_chunks = index_array.map { |i| @chunks[i] }
  end

  def build_prompt(question)
    <<-PROMPT
    Context information is below.
    ---------------------
    #{@retrieved_chunks.join("\n---------------------\n")}
    ---------------------
    Given the context information and not prior knowledge, answer the query.
    Query: #{question}
    Answer:
    PROMPT
  end

  def run_completion(user_message, model: 'gpt-3.5-turbo')
    response = @client.chat(
      parameters: {
        model: model,
        messages: [{ role: 'user', content: user_message }],
        temperature: 0.0
      }
    )
    response.dig('choices', 0, 'message', 'content')
  end
end