# frozen_string_literal: true

require "json"
require "fileutils"
require "time"

# 紹介履歴の管理を担当するクラス
class HistoryManager
  def initialize(history_file:, cooldown_days: 7)
    @history_file = history_file
    @cooldown_days = cooldown_days
  end

  # 履歴を読み込む
  def load
    return {} unless File.exist?(@history_file)
    JSON.parse(File.read(@history_file, encoding: "UTF-8"))
  rescue JSON::ParserError
    {}
  end

  # 履歴を保存
  def save(history)
    FileUtils.mkdir_p(File.dirname(@history_file))
    File.write(@history_file, JSON.pretty_generate(history), encoding: "UTF-8")
  end

  # スレッドを履歴に記録
  def record(history, thread_id:, thread_name:, tier:, zero_post:)
    history[thread_id] = {
      "last_introduced_at" => Time.now.iso8601,
      "thread_name" => thread_name,
      "tier" => tier,
      "zero_post" => zero_post
    }
  end

  # クールダウン期間が経過したスレッドかチェック
  def cooldown_passed?(last_introduced_at)
    cooldown_threshold = Time.now - (@cooldown_days * 24 * 60 * 60)
    Time.parse(last_introduced_at) < cooldown_threshold
  end
end
