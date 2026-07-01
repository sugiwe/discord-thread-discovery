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
FORUM_CHANNEL_ID = ENV.fetch("FORUM_CHANNEL_ID")
WEBHOOK_URL      = ENV.fetch("DIGEST_WEBHOOK_URL")

HISTORY_FILE = "state/history.json"
COOLDOWN_DAYS = 7

def main
  # 各クラスのインスタンスを生成
  my_discord_client = DiscordClient.new(
    bot_token: BOT_TOKEN,
    guild_id: GUILD_ID,
    channel_id: FORUM_CHANNEL_ID,
    webhook_url: WEBHOOK_URL
  )

  my_history_manager = HistoryManager.new(
    history_file: HISTORY_FILE,
    cooldown_days: COOLDOWN_DAYS
  )

  my_thread_selector = ThreadSelector.new(
    history_manager: my_history_manager,
    guild_id: GUILD_ID,
    channel_id: FORUM_CHANNEL_ID
  )

  my_message_formatter = MessageFormatter.new(
    discord_client: my_discord_client,
    thread_selector: my_thread_selector
  )

  # スレッド一覧を取得
  my_threads = my_discord_client.fetch_all_threads
  if my_threads.empty?
    puts "スレッドが見つかりませんでした。投稿をスキップします。"
    return
  end

  # 履歴を読み込み、スレッドを選択
  my_history = my_history_manager.load
  my_result = my_thread_selector.select(my_threads, my_history)

  # 全滅時
  if my_result[:tier] == 5
    my_discord_client.post_to_webhook(my_message_formatter.all_introduced_message)
    puts "全て紹介済みのため、全滅メッセージを投稿しました。"
    return
  end

  # メッセージを生成して投稿
  my_selected = my_result[:thread]
  my_message = my_message_formatter.format(my_selected, zero_post: my_result[:zero_post])
  my_discord_client.post_to_webhook(my_message)

  # 履歴を更新して保存
  my_history_manager.record(
    my_history,
    thread_id: my_selected["id"],
    thread_name: my_selected["name"],
    tier: my_result[:tier],
    zero_post: my_result[:zero_post]
  )
  my_history_manager.save(my_history)

  # Gitコミット&プッシュ（GitHub Actionsで実行時のみ）
  if ENV["GITHUB_ACTIONS"] == "true"
    system("git config --global user.email 'actions@github.com'")
    system("git config --global user.name 'GitHub Actions'")
    system("git add #{HISTORY_FILE}")
    system("git commit -m 'Update history: #{my_selected["name"]}'")
    system("git push")
  end

  puts "投稿しました: #{my_selected["name"]} (第#{my_result[:tier]}候補#{my_result[:zero_post] ? "・投稿ゼロ" : ""})"
end

main if __FILE__ == $PROGRAM_NAME
