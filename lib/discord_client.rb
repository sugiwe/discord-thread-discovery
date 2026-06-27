# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

# Discord API通信を担当するクラス
class DiscordClient
  API_BASE = "https://discord.com/api/v10"

  def initialize(bot_token:, guild_id:, channel_id:, webhook_url:)
    @bot_token = bot_token
    @guild_id = guild_id
    @channel_id = channel_id
    @webhook_url = webhook_url
  end

  # 429(レート制限)を最低限ケアした GET ヘルパー
  def get_json(path)
    3.times do
      uri = URI("#{API_BASE}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bot #{@bot_token}"
      request["User-Agent"] = "shumi-hakkutsu/0.1"
      request["Cache-Control"] = "no-cache"

      response = http.request(request)
      return JSON.parse(response.body) if response.code == "200"

      if response.code == "429"
        wait = ((JSON.parse(response.body)["retry_after"] rescue 1).to_f) + 0.5
        warn "rate limited: retrying in #{wait}s"
        sleep wait
        next
      end

      raise "Discord API error #{response.code}: #{response.body}"
    end
    raise "rate limited too many times: #{path}"
  end

  # 全スレッド一覧（アクティブ + アーカイブ）を取得
  def fetch_all_threads
    active = get_json("/guilds/#{@guild_id}/threads/active?_=#{Time.now.to_i}")
      .fetch("threads")
      .select { |t| t["parent_id"] == @channel_id }

    archived = get_json("/channels/#{@channel_id}/threads/archived/public?_=#{Time.now.to_i}")
      .fetch("threads", [])

    active + archived
  end

  # スレッドの最新メッセージを取得
  def fetch_latest_message(thread_id)
    get_json("/channels/#{thread_id}/messages?limit=1").first
  end

  # Webhookにメッセージを投稿
  def post_to_webhook(content)
    payload = { content: content, allowed_mentions: { parse: [] } }

    uri = URI(@webhook_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request.body = payload.to_json

    response = http.request(request)
    raise "Webhook post failed #{response.code}: #{response.body}" unless response.code.to_i.between?(200, 299)
  end
end
