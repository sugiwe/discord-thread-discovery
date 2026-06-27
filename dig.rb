# frozen_string_literal: true

# ローカル実行時のみ .env を読む（GitHub Actions では Secrets を使うので不要）
begin
  require "dotenv/load"
rescue LoadError
  # 本番(Actions)では dotenv は無くてよい
end

require_relative "lib/discord_client"
require_relative "lib/history_manager"
require_relative "lib/thread_selector"
require_relative "lib/message_formatter"

# 環境変数
BOT_TOKEN        = ENV.fetch("DISCORD_BOT_TOKEN")
GUILD_ID         = ENV.fetch("DISCORD_GUILD_ID")
HOBBY_CHANNEL_ID = ENV.fetch("HOBBY_CHANNEL_ID")
WEBHOOK_URL      = ENV.fetch("DIGEST_WEBHOOK_URL")

HISTORY_FILE = "state/history.json"
COOLDOWN_DAYS = 7

def main
  # 各クラスのインスタンスを生成
  discord_client = DiscordClient.new(
    bot_token: BOT_TOKEN,
    guild_id: GUILD_ID,
    channel_id: HOBBY_CHANNEL_ID,
    webhook_url: WEBHOOK_URL
  )

  history_manager = HistoryManager.new(
    history_file: HISTORY_FILE,
    cooldown_days: COOLDOWN_DAYS
  )

  thread_selector = ThreadSelector.new(
    history_manager: history_manager,
    guild_id: GUILD_ID,
    channel_id: HOBBY_CHANNEL_ID
  )

  message_formatter = MessageFormatter.new(
    discord_client: discord_client,
    thread_selector: thread_selector
  )

  # スレッド一覧を取得
  threads = discord_client.fetch_all_threads
  if threads.empty?
    puts "スレッドが見つかりませんでした。投稿をスキップします。"
    return
  end

  # 履歴を読み込み、スレッドを選択
  history = history_manager.load
  result = thread_selector.select(threads, history)

  # 全滅時
  if result[:tier] == 5
    discord_client.post_to_webhook(message_formatter.all_introduced_message)
    puts "全て紹介済みのため、全滅メッセージを投稿しました。"
    return
  end

  # メッセージを生成して投稿
  selected = result[:thread]
  message = message_formatter.format(selected, zero_post: result[:zero_post])
  discord_client.post_to_webhook(message)

  # 履歴を更新して保存
  history_manager.record(
    history,
    thread_id: selected["id"],
    thread_name: selected["name"],
    tier: result[:tier],
    zero_post: result[:zero_post]
  )
  history_manager.save(history)

  # Gitコミット&プッシュ（GitHub Actionsで実行時のみ）
  if ENV["GITHUB_ACTIONS"] == "true"
    system("git config --global user.email 'actions@github.com'")
    system("git config --global user.name 'GitHub Actions'")
    system("git add #{HISTORY_FILE}")
    system("git commit -m 'Update history: #{selected["name"]}'")
    system("git push")
  end

  puts "投稿しました: #{selected["name"]} (第#{result[:tier]}候補#{result[:zero_post] ? "・投稿ゼロ" : ""})"
end

main if __FILE__ == $PROGRAM_NAME
