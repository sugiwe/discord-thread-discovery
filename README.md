# discord-thread-discovery 🎮📚🎸

任意のフォーラムから設定した頻度でスレッドを発掘して紹介するDiscord BOTです。
GitHub Actionsで動作し、サーバー不要・完全無料で運用できます。

## 特徴

- **4層選択ロジック**: 新鮮な投稿を優先しつつ、投稿ゼロスレッドや過去スレッドもバランスよく紹介
- **履歴管理**: 同じスレッドの連続紹介を避け、7日間のクールダウンを設定
- **アーカイブ対応**: アクティブ・アーカイブ両方のスレッドから選択
- **サーバー不要**: GitHub Actionsで定期実行（無料枠で十分）
- **マルチサーバー対応**: フォーク＋Secrets設定だけで別サーバーに展開可能

## 仕組み

### スレッド選択ロジック（4層フォールバック）

1. **第1候補**: 過去24時間以内に投稿があり、未紹介のスレッド
2. **第2候補**: 24時間〜7日以内に投稿があり、未紹介のスレッド
3. **第3候補**: 投稿ゼロ（返信なし）で未紹介のスレッド
4. **第4候補**: 最後の紹介から7日以上経過したスレッド（再紹介）
5. **全滅**: 全スレッド紹介済み＆クールダウン中の場合は特別メッセージ

### 技術構成

- **読み取り**: Discord BOT（REST API）でスレッド一覧と最新メッセージを取得
- **投稿**: Webhookで分報チャンネルに投稿
- **履歴**: `state/history.json` をGitコミット＆プッシュで管理
- **実行**: GitHub Actions（cron: 毎朝8:00 JST）

### コード構成

```
dig.rb                    # メインエントリーポイント（93行）
lib/
  discord_client.rb       # Discord API通信（77行）
  history_manager.rb      # 履歴管理（43行）
  thread_selector.rb      # 4層選択ロジック（90行）
  message_formatter.rb    # メッセージ装飾（72行）
state/
  history.json           # 紹介履歴（自動生成・自動更新）
```

## セットアップ

### A. Discord管理人が行うこと

Discordサーバーの管理権限を持つ人が行う作業です。

#### 1. BOT用のフォーラムチャンネルを用意

発掘対象のフォーラムチャンネルを決めます（既存フォーラムでもOK）。

#### 2. 投稿先チャンネルにWebhookを作成

分報チャンネル（投稿先）で：

編集 → 連携サービス → ウェブフック → 新しいウェブフック → **URLをコピー**

このURLを `DIGEST_WEBHOOK_URL` として後で導入者に共有します。
Webhookの名前やアイコンはここで自由に設定できます。

#### 3. BOTを招待

導入者から提供されるOAuth URLでBOTをサーバーに招待します。

フォーラムチャンネルが非公開の場合、BOTのロールに閲覧権限を付与してください。

#### 4. チャンネルIDを取得して導入者に共有

Discord設定 → 詳細設定 → **開発者モード** を ON

- サーバー名を右クリック → IDをコピー → `DISCORD_GUILD_ID`
- 趣味フォーラムを右クリック → IDをコピー → `HOBBY_CHANNEL_ID`

この2つのIDと、手順2で作成したWebhook URLを導入者に共有してください。

---

### B. BOT導入者が行うこと

GitHubリポジトリとDiscord BOTアプリケーションを管理する人が行う作業です。

#### 1. このリポジトリをフォーク

自分のGitHubアカウントにこのリポジトリをフォークします。

#### 2. Discord BOTアプリケーションを作成

1. [Discord Developer Portal](https://discord.com/developers/applications) で **New Application**
2. 左メニュー **Bot** → **Reset Token** でトークンを取得（後で使用）
3. 同じBot画面で **MESSAGE CONTENT INTENT** を **ON** にする
   - スニペット（メッセージ本文）取得に必須
   - 100サーバー未満なら自己申告トグルのみでOK

#### 3. BOT招待URLを生成してDiscord管理人に共有

OAuth2 → URL Generator:

- **Scopes**: `bot`
- **Permissions**: `View Channels` + `Read Message History`（合計: 66560）

または以下のURLの `CLIENT_ID` を自分のBOTのClient IDに置き換えて管理人に共有：

```
https://discord.com/api/oauth2/authorize?client_id=CLIENT_ID&scope=bot&permissions=66560
```

#### 4. Discord管理人から情報を受け取る

管理人から以下の3つを受け取ります：

- `DISCORD_GUILD_ID`（サーバーID）
- `HOBBY_CHANNEL_ID`（フォーラムチャンネルID）
- `DIGEST_WEBHOOK_URL`（Webhook URL）

#### 5. GitHub Secretsに登録

フォークしたリポジトリ → Settings → Secrets and variables → Actions → **New repository secret**

| Secret名             | 値                   | 取得元     |
| -------------------- | -------------------- | ---------- |
| `DISCORD_BOT_TOKEN`  | BOTトークン          | 手順2      |
| `DISCORD_GUILD_ID`   | サーバーID           | 管理人から |
| `HOBBY_CHANNEL_ID`   | 趣味フォーラムID     | 管理人から |
| `DIGEST_WEBHOOK_URL` | Webhook URL          | 管理人から |

#### 6. 動作確認

GitHub → Actions → `shumi-hakkutsu daily digest` → **Run workflow** で手動実行してテストします。

---

### C. 一人で両方やる場合

Discord管理人と導入者が同一人物の場合は、A・B両方の手順を順番に実施してください。

## 使い方

### 手動実行（テスト）

GitHub → Actions → `shumi-hakkutsu daily digest` → **Run workflow**

### 自動実行

毎日 **8:00 JST**（23:00 UTC前日）に自動実行されます。

時刻変更: [`.github/workflows/digest.yml`](.github/workflows/digest.yml#L6) の `cron` を編集
（GitHub ActionsのcronはUTC基準）

### ローカル実行

```bash
cp .env.example .env   # 4つの環境変数を記入
bundle install
bundle exec ruby dig.rb
```

## カスタマイズ

### 投稿時刻を変更

[`.github/workflows/digest.yml`](.github/workflows/digest.yml) のcron設定を編集します。

GitHub ActionsのcronはUTC基準なので、JST時刻から9時間引いた値を設定してください。
ファイル内のコメントにJST↔UTC対応表があります。

```yaml
# 例: JST 12:00に実行したい場合
- cron: "0 3 * * *" # 12 - 9 = 3 (UTC)
```

### クールダウン期間を変更

[`dig.rb`](dig.rb#L22):

```ruby
COOLDOWN_DAYS = 7  # デフォルト7日
```

### スニペット長を変更

[`lib/message_formatter.rb`](lib/message_formatter.rb#L5):

```ruby
SNIPPET_MAX = 120  # デフォルト120文字
```

### メッセージテンプレートを変更

[`lib/message_formatter.rb`](lib/message_formatter.rb) の各メソッド：

- `format_normal_message` - 通常スレッド用
- `format_zero_post_message` - 投稿ゼロスレッド用
- `all_introduced_message` - 全滅時用

### 選択ロジックを変更

[`lib/thread_selector.rb`](lib/thread_selector.rb#L14-L56) の `select` メソッド

## マルチサーバー展開

別のDiscordサーバーにも展開可能（フォーク方式）：

1. このリポジトリをフォーク
2. 新サーバーでBOT作成＋Webhook作成
3. フォーク先のGitHub Secretsに新サーバーの値を設定
4. 完了（コード変更不要）

各サーバーごとに独立した履歴が管理されます。

## 注意点

### Discord API

- **フォーラムチャンネル専用**: テキストチャンネルでは動作しません
- **レート制限**: 429エラー時は自動リトライ（最大3回）
- **投稿ゼロの定義**: `message_count == 0`（スターターメッセージは含まず、返信のみカウント）

### GitHub Actions

- **schedule遅延**: 混雑時に数分遅れることがあります
- **自動停止**: リポジトリが60日間非アクティブだとscheduleが停止（手動実行で復活）
- **デフォルトブランチ**: scheduleはmainブランチでのみ動作

### 履歴管理

- `state/history.json` は自動生成・自動更新されます
- GitHub Actionsが自動コミット＆プッシュ（`permissions: contents: write` 必須）
- ローカル実行時はコミットされません（`ENV["GITHUB_ACTIONS"]` で判定）

## ライセンス

MIT

## 開発

```bash
# 依存関係
bundle install

# ローカルテスト
bundle exec ruby dig.rb

# コード構成
# - dig.rb: オーケストレーション
# - lib/discord_client.rb: API通信
# - lib/history_manager.rb: JSON履歴管理
# - lib/thread_selector.rb: 4層選択ロジック
# - lib/message_formatter.rb: メッセージ生成
```

各クラスは依存性注入パターンで疎結合になっており、テストしやすい設計です。
