# frozen_string_literal: true

require_relative "../lib/thread_selector"
require_relative "../lib/history_manager"

RSpec.describe ThreadSelector do
  # テスト用のモックオブジェクトを作成
  let(:history_manager) do
    instance_double(
      HistoryManager,
      cooldown_passed?: false
    )
  end

  let(:selector) do
    ThreadSelector.new(
      history_manager: history_manager,
      guild_id: "123456789",
      channel_id: "987654321"
    )
  end

  describe "#select" do
    let(:now) { Time.utc(2025, 1, 1, 12, 0, 0) }

    # Discord Snowflake ID を生成するヘルパーメソッド
    # 指定した秒数前のタイムスタンプを持つSnowflake IDを生成
    def snowflake_id_for_time(time)
      # Discord Snowflake: (timestamp_ms - 1420070400000) << 22
      timestamp_ms = (time.to_f * 1000).to_i
      discord_epoch_ms = 1420070400000
      ((timestamp_ms - discord_epoch_ms) << 22).to_s
    end

    before do
      allow(Time).to receive(:now).and_return(now)
    end

    context "第1候補: 過去24時間以内に投稿があり未紹介のスレッドがある場合" do
      it "tier 1 を返す" do
        threads = [
          {
            "id" => "1",
            "message_count" => 5,
            "name" => "最近のスレッド",
            "last_message_id" => snowflake_id_for_time(now - 12 * 60 * 60) # 12時間前
          }
        ]
        history = {}

        result = selector.select(threads, history)

        expect(result[:tier]).to eq(1)
        expect(result[:zero_post]).to be false
        expect(result[:thread]["name"]).to eq("最近のスレッド")
      end
    end

    context "第2候補: 24時間〜7日以内に投稿があり未紹介のスレッドがある場合" do
      it "tier 2 を返す" do
        threads = [
          {
            "id" => "2",
            "message_count" => 3,
            "name" => "少し前のスレッド",
            "last_message_id" => snowflake_id_for_time(now - 3 * 24 * 60 * 60) # 3日前
          }
        ]
        history = {}

        result = selector.select(threads, history)

        expect(result[:tier]).to eq(2)
        expect(result[:zero_post]).to be false
        expect(result[:thread]["name"]).to eq("少し前のスレッド")
      end
    end

    context "第3候補: 投稿ゼロで未紹介のスレッドがある場合" do
      it "message_count が 0 の場合、zero_post: true で返す" do
        threads = [
          { "id" => "3", "message_count" => 0, "name" => "投稿ゼロスレッド" }
        ]
        history = {}

        result = selector.select(threads, history)

        expect(result[:tier]).to eq(3)
        expect(result[:zero_post]).to be true
        expect(result[:thread]["name"]).to eq("投稿ゼロスレッド")
      end

      it "message_count が nil の場合も zero_post: true で返す（エッジケース）" do
        threads = [
          { "id" => "3", "message_count" => nil, "name" => "投稿ゼロスレッド" }
        ]
        history = {}

        result = selector.select(threads, history)

        expect(result[:tier]).to eq(3)
        expect(result[:zero_post]).to be true
        expect(result[:thread]["name"]).to eq("投稿ゼロスレッド")
      end
    end

    context "第3候補（拡張）: クールダウンが経過したスレッドがある場合" do
      it "tier 3 で再紹介スレッドを返す" do
        threads = [
          {
            "id" => "4",
            "message_count" => 2,
            "name" => "再紹介スレッド",
            "last_message_id" => snowflake_id_for_time(now - 10 * 24 * 60 * 60) # 10日前
          }
        ]
        history = {
          "4" => {
            "last_introduced_at" => (now - 8 * 24 * 60 * 60).iso8601, # 8日前に紹介
            "thread_name" => "再紹介スレッド"
          }
        }

        # クールダウンが経過したことをモック
        allow(history_manager).to receive(:cooldown_passed?).and_return(true)

        result = selector.select(threads, history)

        expect(result[:tier]).to eq(3)
        expect(result[:thread]["name"]).to eq("再紹介スレッド")
      end
    end

    context "全滅: 全てのスレッドが紹介済みでクールダウン中の場合" do
      it "tier 5 を返す" do
        threads = [
          { "id" => "5", "message_count" => 1, "name" => "スレッド1" }
        ]
        history = {
          "5" => {
            "last_introduced_at" => (now - 3 * 24 * 60 * 60).iso8601,
            "thread_name" => "スレッド1"
          }
        }

        result = selector.select(threads, history)

        expect(result[:tier]).to eq(5)
        expect(result[:thread]).to be_nil
      end
    end

    context "スレッド一覧が空の場合" do
      it "tier 5 を返し、thread は nil になる" do
        result = selector.select([], {})

        expect(result[:tier]).to eq(5)
        expect(result[:thread]).to be_nil
      end
    end
  end
end
