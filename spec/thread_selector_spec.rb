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

  describe "#zero_post_thread?" do
    it "message_count が 0 の時は true を返す" do
      thread = { "message_count" => 0 }
      expect(selector.send(:zero_post_thread?, thread)).to be true
    end

    it "message_count が 1 の時は false を返す" do
      thread = { "message_count" => 1 }
      expect(selector.send(:zero_post_thread?, thread)).to be false
    end

    # Discord API は message_count を常に整数で返すため、
    # nil のケースは実際には発生しない（to_i で 0 に変換される挙動は許容）
    it "message_count が nil の時は true を返す（エッジケース）" do
      thread = { "message_count" => nil }
      expect(selector.send(:zero_post_thread?, thread)).to be true
    end
  end

  describe "#select" do
    let(:now) { Time.now }

    before do
      allow(Time).to receive(:now).and_return(now)
    end

    context "第3候補: 投稿ゼロで未紹介のスレッドがある場合" do
      it "zero_post: true で返す" do
        threads = [
          { "id" => "1", "message_count" => 0, "name" => "投稿ゼロスレッド" }
        ]
        history = {}

        result = selector.select(threads, history)

        expect(result[:tier]).to eq(3)
        expect(result[:zero_post]).to be true
        expect(result[:thread]["name"]).to eq("投稿ゼロスレッド")
      end
    end

    context "全滅: 全てのスレッドが紹介済みでクールダウン中の場合" do
      it "tier 5 を返す" do
        threads = [
          { "id" => "1", "message_count" => 1, "name" => "スレッド1" }
        ]
        history = {
          "1" => {
            "last_introduced_at" => (now - 3 * 24 * 60 * 60).iso8601,
            "thread_name" => "スレッド1"
          }
        }

        # cooldown_passed? が false を返すようにモック
        allow(history_manager).to receive(:cooldown_passed?).and_return(false)

        result = selector.select(threads, history)

        expect(result[:tier]).to eq(5)
        expect(result[:thread]).to be_nil
      end
    end
  end
end
