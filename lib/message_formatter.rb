# frozen_string_literal: true

# メッセージフォーマットを担当するクラス
class MessageFormatter
  SNIPPET_MAX = 120

  def initialize(discord_client:, thread_selector:)
    @discord_client = discord_client
    @thread_selector = thread_selector
  end

  # メッセージ本文を生成
  def format(thread, zero_post:)
    if zero_post
      format_zero_post_message(thread)
    else
      format_normal_message(thread)
    end
  end

  # 全滅時のメッセージ
  def all_introduced_message
    <<~MD.strip
      🌱✨🌱✨🌱 **趣味発掘** 🌱✨🌱✨🌱

      最近の投稿はだいたい紹介しました、新しい投稿をお待ちしています✨
      #{@thread_selector.channel_link}

      🌱✨🌱✨🌱✨🌱✨🌱✨🌱✨🌱
    MD
  end

  private

  # 通常スレッド用メッセージ
  def format_normal_message(thread)
    <<~MD.strip
      🎮📚🎸🐶🐱 **趣味発掘** 🎧⚾️🐦🎬📸

      **#{thread["name"]}**
      > #{snippet(thread["id"])}
      #{@thread_selector.thread_link(thread["id"])}

      🎨🧶🚗✈️🌿🎯🍕🔬🎭🧩🏀🎪🌸🎵
    MD
  end

  # 投稿ゼロスレッド用メッセージ
  def format_zero_post_message(thread)
    <<~MD.strip
      🌱✨🌱✨🌱 **趣味発掘** 🌱✨🌱✨🌱

      **#{thread["name"]}**
      > まだ投稿がありません、最初の一言をお待ちしています✨
      #{@thread_selector.thread_link(thread["id"])}

      🌱✨🌱✨🌱✨🌱✨🌱✨🌱✨🌱
    MD
  end

  # メッセージのスニペットを生成
  def snippet(thread_id)
    message = @discord_client.fetch_latest_message(thread_id)
    return "(本文なし)" unless message

    content = message["content"].to_s.strip
    return "(画像・添付のみ)" if content.empty?

    oneline = content.gsub(/\s+/, " ")
    oneline.length > SNIPPET_MAX ? "#{oneline[0, SNIPPET_MAX]}…" : oneline
  end
end
