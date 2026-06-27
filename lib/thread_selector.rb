# frozen_string_literal: true

require "time"

# スレッド選択ロジックを担当するクラス
class ThreadSelector
  def initialize(history_manager:, guild_id:, channel_id:)
    @history_manager = history_manager
    @guild_id = guild_id
    @channel_id = channel_id
  end

  # 4層選択ロジックでスレッドを選択
  def select(threads, history)
    now = Time.now

    # 第1候補: 過去24時間以内に最終メッセージがあり、未紹介のスレッド
    tier1 = threads.select do |t|
      next if zero_post_thread?(t)
      next if history[t["id"]]

      last_msg_time = last_message_timestamp(t)
      last_msg_time && last_msg_time > (now - 24 * 60 * 60)
    end
    return build_result(tier1.sample, 1, false) if tier1.any?

    # 第2候補: 24時間超〜7日以内に最終メッセージがあり、未紹介のスレッド
    tier2 = threads.select do |t|
      next if zero_post_thread?(t)
      next if history[t["id"]]

      last_msg_time = last_message_timestamp(t)
      last_msg_time && last_msg_time > (now - 7 * 24 * 60 * 60) && last_msg_time <= (now - 24 * 60 * 60)
    end
    return build_result(tier2.sample, 2, false) if tier2.any?

    # 第3候補: 投稿ゼロで未紹介のスレッド
    tier3 = threads.select do |t|
      zero_post_thread?(t) && !history[t["id"]]
    end
    return build_result(tier3.sample, 3, true) if tier3.any?

    # 第4候補: 最後の紹介から7日以上経過したスレッド（再紹介OK）
    tier4 = threads.select do |t|
      next unless history[t["id"]]
      @history_manager.cooldown_passed?(history[t["id"]]["last_introduced_at"])
    end

    if tier4.any?
      selected = tier4.sample
      return build_result(selected, 4, zero_post_thread?(selected))
    end

    # 全滅
    build_result(nil, 5, false)
  end

  # スレッドのリンクを生成
  def thread_link(thread_id)
    "https://discord.com/channels/#{@guild_id}/#{thread_id}"
  end

  # チャンネルのリンクを生成
  def channel_link
    "https://discord.com/channels/#{@guild_id}/#{@channel_id}"
  end

  private

  # スレッドが投稿ゼロかどうか判定（スターターメッセージのみで返信なし）
  # message_count はスターターメッセージを含まず、返信のみをカウント
  def zero_post_thread?(thread)
    thread["message_count"].to_i == 0
  end

  # 最終メッセージのタイムスタンプを取得（Snowflake IDから計算）
  def last_message_timestamp(thread)
    return nil unless thread["last_message_id"]

    # Discord Snowflake: ((id >> 22) + 1420070400000) / 1000 = Unix timestamp
    snowflake = thread["last_message_id"].to_i
    Time.at((snowflake >> 22) / 1000.0 + 1420070400)
  end

  # 選択結果を構築
  def build_result(thread, tier, zero_post)
    { thread: thread, tier: tier, zero_post: zero_post }
  end
end
