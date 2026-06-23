# shumi-hakkutsu 🎲

「趣味」チャンネルのアクティブなスレッドから毎朝ランダムに1つ選んで、
分報チャンネルにリンク付きで投下する最小構成の Discord 発掘 BOT。
常駐せず、GitHub Actions の定期実行（無料）で動く。

## 仕組み

1. Discord REST API で「趣味」チャンネル配下のアクティブスレッドを一覧取得
2. その中からランダムに1つ選ぶ
3. スレッド名＋最新メッセージのスニペット＋リンクを、分報チャンネルの Webhook に投稿

読み取りには BOT トークン、投稿には Webhook を使う（投稿に BOT の送信権限は不要）。

## セットアップ

### 1. Discord BOT を作る

1. https://discord.com/developers/applications で「New Application」
2. 左メニュー **Bot** → **Reset Token** でトークンを取得 → `DISCORD_BOT_TOKEN` に使う
3. 同じ Bot 画面で **MESSAGE CONTENT INTENT** を ON にする
   （スニペット＝本文を読むのに必須。100サーバー未満なら自己申告トグルだけでOK）

### 2. BOT をサーバーに招待

OAuth2 → URL Generator で `scope = bot`、権限は **View Channels** と **Read Message History** にチェック。
または下の URL の `CLIENT_ID` を差し替えてアクセス（権限 66560 = 上記2つ）:

```
https://discord.com/api/oauth2/authorize?client_id=CLIENT_ID&scope=bot&permissions=66560
```

「趣味」チャンネルが非公開なら、BOT のロールがそのチャンネルを閲覧できることも確認。

### 3. ID を取得する

Discord クライアントで 設定 → 詳細設定 → **開発者モード** を ON。

- サーバー名を右クリック → ID をコピー → `DISCORD_GUILD_ID`
- 「趣味」チャンネルを右クリック → ID をコピー → `HOBBY_CHANNEL_ID`

### 4. 分報チャンネルに Webhook を作る

分報チャンネルの 編集 → 連携サービス → ウェブフック → 新規作成 → **URL をコピー**
→ `DIGEST_WEBHOOK_URL`。名前やアイコンはここで自由に設定できる。

### 5. GitHub Secrets に登録

リポジトリ → Settings → Secrets and variables → Actions → New repository secret で4つ登録:

| Secret 名 | 値 |
|---|---|
| `DISCORD_BOT_TOKEN` | BOT トークン |
| `DISCORD_GUILD_ID` | サーバー ID |
| `HOBBY_CHANNEL_ID` | 趣味チャンネル ID |
| `DIGEST_WEBHOOK_URL` | 分報の Webhook URL |

## 動かす

- **手動テスト**: Actions タブ → `shumi-hakkutsu daily digest` → Run workflow（`workflow_dispatch`）
- **自動**: 毎日 8:00 JST に実行。時刻は `.github/workflows/digest.yml` の cron で変更（UTC 基準なので注意）

## ローカルで試す

```sh
cp .env.example .env   # 値を埋める
bundle install
bundle exec ruby dig.rb
```

## カスタマイズの入口

- 投稿時刻 … `digest.yml` の `cron`
- スニペット長 … `dig.rb` の `SNIPPET_MAX`
- 投稿文面 … `dig.rb` の `main` 内ヒアドキュメント
- 🔥盛り上がり枠・🌱新着枠を足す … `hobby_threads` で集計＆選定ロジックを拡張

## 注意点

- 対象は**アクティブ（非アーカイブ）スレッドのみ**。Discord は一定期間で自動アーカイブするので、
  事実上「最近動きのあるスレッド」が対象になる。アーカイブ済みも拾いたくなったら
  `GET /channels/{id}/threads/archived/public` を追加する。
- GitHub Actions の schedule は混雑時に数分〜遅延することがある。また**リポジトリが60日間
  非アクティブだと schedule が自動停止**するので、たまに何かコミットするか手動実行を。
- schedule はデフォルトブランチでのみ動く。
