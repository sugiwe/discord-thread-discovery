# frozen_string_literal: true

# ローカル実行時のみ .env を読む（GitHub Actions では Secrets を使うので不要）
begin
  require "dotenv/load"
rescue LoadError
  # 本番(Actions)では dotenv は無くてよい
end

require "json"
require "net/http"
require "uri"

API_BASE = "https://discord.com/api/v10"

BOT_TOKEN        = ENV.fetch("DISCORD_BOT_TOKEN")
GUILD_ID         = ENV.fetch("DISCORD_GUILD_ID")
HOBBY_CHANNEL_ID = ENV.fetch("HOBBY_CHANNEL_ID")
WEBHOOK_URL      = ENV.fetch("DIGEST_WEBHOOK_URL")

SNIPPET_MAX = 120

# 429(レート制限)を最低限ケアした GET ヘルパー
def get_json(path)
  3.times do
    uri = URI("#{API_BASE}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bot #{BOT_TOKEN}"
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

# 「趣味」チャンネル配下のアクティブ(非アーカイブ)スレッド一覧
def hobby_threads
  # キャッシュバスティング用にタイムスタンプを追加
  get_json("/guilds/#{GUILD_ID}/threads/active?_=#{Time.now.to_i}")
    .fetch("threads")
    .select { |t| t["parent_id"] == HOBBY_CHANNEL_ID }
end

# スレッドの最新メッセージ1件（スニペット用）
def latest_message(thread_id)
  get_json("/channels/#{thread_id}/messages?limit=1").first
end

def snippet(message)
  return "(本文なし)" unless message

  content = message["content"].to_s.strip
  return "(画像・添付のみ)" if content.empty?

  oneline = content.gsub(/\s+/, " ")
  oneline.length > SNIPPET_MAX ? "#{oneline[0, SNIPPET_MAX]}…" : oneline
end

def thread_link(thread_id)
  "https://discord.com/channels/#{GUILD_ID}/#{thread_id}"
end

def post_to_webhook(content)
  # allowed_mentions を空にして、スニペット内の @mention で誤爆通知しないようにする
  payload = { content: content, allowed_mentions: { parse: [] } }

  uri = URI(WEBHOOK_URL)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  request = Net::HTTP::Post.new(uri)
  request["Content-Type"] = "application/json"
  request.body = payload.to_json

  response = http.request(request)
  raise "Webhook post failed #{response.code}: #{response.body}" unless response.code.to_i.between?(200, 299)
end

def main
  threads = hobby_threads
  if threads.empty?
    puts "アクティブなスレッドが見つかりませんでした。投稿をスキップします。"
    return
  end

  pick = threads.sample
  body = <<~MD.strip
    🎲 **趣味発掘** — きょうのスレッド

    **#{pick["name"]}**
    > #{snippet(latest_message(pick["id"]))}
    #{thread_link(pick["id"])}
  MD

  post_to_webhook(body)
  puts "投稿しました: #{pick["name"]}"
end

main
