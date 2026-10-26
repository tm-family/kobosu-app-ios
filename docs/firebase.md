# Firebase の設定（人がすること）

こぼすは、投稿・共感・通報を Firebase（匿名認証と Firestore）でみんなと共有します。
Firebase のコンソールでの作業はリポジトリの外なので、ここに手順をまとめます。
`GoogleService-Info.plist` が無いビルド（テスト・Preview・撮影モード・手元のビルド）は Firebase につながず、端末の中だけで動きます。

リポジトリにある設定ファイル:

| ファイル | 中身 |
| --- | --- |
| [`firestore.rules`](../firestore.rules) | セキュリティルール。アプリが書く形だけを許し、それ以外は拒む |
| [`firestore.indexes.json`](../firestore.indexes.json) | タイムラインの複合インデックスと、`expireAt` の TTL |
| [`firebase.json`](../firebase.json) | `firebase deploy --only firestore` で上の 2 つを出すための設定 |

## 1. プロジェクトを作る

1. [Firebase コンソール](https://console.firebase.google.com/) でプロジェクトを作る（Google アナリティクスは使わないので、オフでかまいません）
2. iOS アプリを追加する。バンドル ID は `Configs/Project.xcconfig` の `APP_BUNDLE_IDENTIFIER` と同じにする
3. `GoogleService-Info.plist` をダウンロードする
   - 手元で Firebase につないで動かすときは `Kobosu/GoogleService-Info.plist` に置く（`.gitignore` に入っているので、コミットされません）
   - 配信のビルドでは、`base64 -i GoogleService-Info.plist` の結果を GitHub の Secret `GOOGLE_SERVICE_INFO_PLIST_BASE64` に登録する（README の「4. GitHub Secrets を設定する」）

## 2. 匿名認証を有効にする

「Authentication」→「ログイン方法」で「匿名」を有効にします。ほかのログイン方法は使いません。

## 3. Firestore を作る

1. 「Firestore Database」でデータベースを作る。ロケーションは `asia-northeast1`（東京）など、使う人に近い場所にする（あとから変えられません）
2. 「本番環境モード」で始める（テストモードにしない。ルールは次の手順で出します）

## 4. ルールとインデックスを出す

[Firebase CLI](https://firebase.google.com/docs/cli) を使います。

```sh
npm install -g firebase-tools
firebase login
firebase use --add            # 作ったプロジェクトを選ぶ（.firebaserc ができる）
firebase deploy --only firestore
```

- ルールを変えたら、もう一度 `firebase deploy --only firestore:rules` を流します
- カテゴリを 10 種類から 6 種類（義理の親・パートナー・子育て・家事分担・お金・その他）に減らしたので、ルールを出し直してください。
  出し直すまでは、新しいアプリの投稿も古いルールで通りますが、出し直したあとは古いアプリで外したカテゴリ（実の親・きょうだい/親戚・介護・仕事と家庭）を選んだ投稿がはじかれます。
  すでにある外したカテゴリの投稿は、新しいアプリでは表示されません（24 時間で消えるので、そのまま待ちます）。
  本人のノートにも出ないので、1 件ずつは消せません。「すべてのデータを削除」では消えます
- カテゴリに「未分類」（`uncategorized`）を足したので、ルールを出し直してください。出し直すまでは、新しいアプリで未分類のまま投稿するとはじかれます。
  未分類の投稿は、タイムラインでは「すべて」にだけ出ます（カテゴリで絞ったタイムラインには出ません）
- 複合インデックス（`posts` の `category` + `expireAt` の降順）は、作り終わるまで数分かかります。それまではカテゴリで絞ったタイムラインが読めません
- `.firebaserc` にはプロジェクト ID が入ります。コミットするかは、プロジェクトを作った人が決めてください

## 5. TTL（自動で消す）を設定する

投稿は作ってから 24 時間で消えます。端末では期限を過ぎたものを出さず、サーバーでは TTL で文書ごと消します。
TTL は親の文書を消してもサブコレクションを消さないので、次の 5 つのコレクション グループの `expireAt` に、それぞれ TTL を付けます。

| コレクション グループ | 場所 | 中身 |
| --- | --- | --- |
| `posts` | `posts/{postId}` | 投稿 |
| `reports` | `posts/{postId}/reports/{uid}` | 通報 |
| `ownPosts` | `users/{uid}/ownPosts/{postId}` | 自分の投稿の目印 |
| `sentStamps` | `users/{uid}/sentStamps/{postId}` | 自分が送ったスタンプ |
| `sentReports` | `users/{uid}/sentReports/{postId}` | 自分が通報した目印 |

`firestore.indexes.json` の `fieldOverrides` に `"ttl": true` を書いてあるので、`firebase deploy --only firestore` で設定されます。
設定されていないとき（CLI が古いなど）は、コンソールの「Firestore Database」→「TTL」で、上の 5 つに `expireAt` のポリシーを作ってください。

- TTL は期限を過ぎてから実際に消えるまで、最大 24 時間ほどかかります。そのあいだもアプリには出しません（タイムラインの読み出しの条件と、端末の判定の両方で外しています）
- TTL の削除は Firestore の削除の回数として数えられます。TTL を使うのに課金（Blaze プラン）が要るかは、設定するときのコンソールの案内に従ってください（手元では確かめられていません）

## 6. 運営が通報を確かめる

通知や Cloud Functions は使わず、Firebase コンソールで見ます。

1. 「Firestore Database」→「データ」で `posts` を開く
2. `reportCount` で絞り込む（`reportCount >= 3`）。3 人以上から通報された投稿は、タイムラインに自動で出なくなっています（`ReportPolicy.autoHideThreshold`）
3. 投稿の下の `reports` を開くと、通報の理由（`reason`）が見られます。文書 ID は通報した人の匿名の uid です。名前やメールアドレスは持っていません

| `reason` | アプリでの表示 |
| --- | --- |
| `identifiable_information` | 特定の人が分かる情報がある |
| `harassment` | 誰かを強く攻撃している |
| `dangerous` | 危険を感じる内容がある |
| `spam` | 宣伝や関係のない投稿 |
| `other` | そのほか |

- 投稿も通報も、期限（作ってから 24 時間）を過ぎると TTL で消えます。確かめられるのは投稿が残っているあいだだけです
- すぐに消したい投稿は、コンソールで `posts/{postId}` を消します（その下の `reports` も一緒に消してください）

## 7. 匿名アカウントについて

「すべてのデータを削除」では、サーバーの投稿・送った共感・通報を消してから、Firebase の匿名ユーザーを消します。
ただ、Firebase はサインインしてから時間がたったユーザーの削除を断る（`requiresRecentLogin`）ことが多く、そのときはサインアウトして uid を手放すだけになります。
データは消えていますが、中身の無い匿名アカウントが Authentication に残ります。

残ったアカウントを片づけたいときは、次のどちらかを人が選んでください。

- Firebase Authentication を Identity Platform にアップグレードし、匿名アカウントの自動削除（30 日）を有効にする
- ときどき、コンソールの「Authentication」→「ユーザー」で、古い匿名アカウントを消す

## 8. ルールで守っていること・守れないこと

ルールは、アプリが書く形（`Kobosu/Repositories` の `PostDocument`・`ReportDocument`・`MyDataDocument` と `Firestore*Repository`）にあわせてあります。アプリの書き方を変えたら、ルールも一緒に直します。

守っていること:

- 投稿の文書に、投稿者を特定できる値を置けない。自分の目印・送ったスタンプ・通報した目印は、本人しか読み書きできない
- 期限は、作るときはサーバーの時刻（`request.time`）だけ、2 段目では `createdAt` の 24 時間後だけにできる。あとから延ばせない
- 自分の投稿には共感・通報できない。期限切れ・書き終わっていない投稿にもできない
- 共感はスタンプごとに 1 人 1 回、通報は 1 人 1 回。人数は記録と同じ書き込みでだけ 1 増やせ、その記録を消すのと同じ書き込みでだけ 1 減らせる
- 投稿を消せるのは、自分の目印がある人だけ。目印は投稿と一緒に消すとき（または投稿がもう無いとき）だけ消せる
- 投稿のカテゴリは、アプリの `PostCategory` の 6 種類と未分類のどれかだけ（`categoryIDs()`）

守れないこと（アプリで外している）:

- タイムラインの読み出しは、サインインしていればできる。期限切れ（TTL を待っているもの）と、通報が 3 人以上の投稿は、アプリが外している
- `reportCount` は投稿の文書にあるので、アプリを改造すれば読める
- ルールは手元では動かしていません（Firebase CLI・エミュレーターが無いため）。下の「9. 動くか確かめる」で、実際のプロジェクトで確かめてください
- ルールが `exists()`・`get()` を呼べる回数には上限があります（1 つの書き込みで 10 回、1 つのバッチで 20 回）。「すべてのデータを削除」は投稿を 10 件ずつのバッチに分けて消しています（`MyDataDocument.postsPerDeletionBatch`）。
  4 種のスタンプと通報をまとめて取り下げる書き込みは、同じ文書を何度も読むので、上限に数えられるかを 9 の 7 で確かめてください

## 9. 動くか確かめる

ルールとインデックスを出したあと、`Kobosu/GoogleService-Info.plist` を置いた実機（または Simulator）で、次を確かめます。
ルールにはじかれると、Xcode のコンソールに `Missing or insufficient permissions` が出ます。

1. 投稿する → タイムラインとノートに出る。Firestore の `posts` と `users/{uid}/ownPosts` に文書ができ、`expireAt` が `createdAt` の 24 時間後になっている
2. カテゴリで絞る → 絞ったタイムラインが出る（インデックスができていないと、コンソールにインデックスを作るリンクが出る）
3. 別の端末（別の匿名ユーザー）で共感を送る → `stampCounts` が 1 増え、`users/{uid}/sentStamps` に記録ができる。同じスタンプをもう一度押しても増えない
4. 別の端末で通報する → `reportCount` が 1 増え、`reports/{uid}` と `users/{uid}/sentReports` ができる。2 回目は増えない
5. 自分の投稿をノートから消す → `posts` と `ownPosts` から消える
6. 共感・通報をした端末で「すべてのデータを削除」→ 送った分だけ `stampCounts`・`reportCount` が 1 ずつ減り、その端末の `users/{uid}` の下が空になる
7. 「すべてのデータを削除」の重い場合を確かめる
   - 自分の投稿が 21 件以上ある端末で削除する → すべての `posts` と `ownPosts` が消える
   - 1 つの投稿に 4 種のスタンプを送り、通報もした端末で削除する → 4 種の `stampCounts` と `reportCount` が 1 ずつ減る（はじかれたら、ルールの `exists()`・`get()` の回数の上限を超えています）
   - 期限を過ぎて TTL を待っている投稿に共感・通報していた端末で削除する → 人数は引かず、`sentStamps`・`sentReports`・`reports/{uid}` だけ消える
8. Rules Playground（コンソールの「ルール」→「Rules Playground」）で、他人の `users/{uid}/sentStamps` を読む・`posts` に `uid` などのフィールドを足して書く、がはじかれる
