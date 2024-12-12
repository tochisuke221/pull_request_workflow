require 'octokit'
require 'dotenv/load'
require 'io/console'

# 定数
OWNER = 'tochisuke221'.freeze
REPO = 'pull_request_workflow'.freeze

LABEL_EMOJI = {
  '新機能' => '🎉',
  '改善' => '✨',
  'バグ修正' => '🐛',
  '内部変更' => '🧹',
  'その他' => '🔧'
}.freeze

# GitHubクライアントの初期化
GITHUB_TOKEN = 'xxxxx'
if GITHUB_TOKEN.nil? || GITHUB_TOKEN.empty?
  raise 'GITHUB_TOKENが設定されていません。環境変数にトークンを設定してください。'
end

client = Octokit::Client.new(access_token: GITHUB_TOKEN)

# Gitコマンドを実行してローカルブランチを取得
def fetch_local_branches
  branches = `git branch --list`.split("\n").map { |b| b.strip.gsub('* ', '') }
  raise 'Gitブランチ情報の取得に失敗しました。Gitリポジトリ内で実行してください。' if branches.empty?

  branches
end

def prompt(message)
  print "#{message}: "
  gets.chomp
end

def select_option(message, options)
  puts message
  options.each_with_index do |option, index|
    puts "#{index + 1}. #{option}"
  end
  print '選択番号: '
  index = gets.chomp.to_i - 1
  options[index]
end

begin
  # Gitブランチ情報を取得
  branches = fetch_local_branches
  puts 'ローカルブランチを取得しました。'

  # 各種情報入力
  head = select_option('PRのheadブランチを選択してください', branches)
  base = select_option('PRのbaseブランチを選択してください', branches)
  task_id = prompt('NotionのタスクIDを入力してください (省略可能)')
  label = select_option('ラベルを選択してください', LABEL_EMOJI.keys)
  title = prompt('PRのタイトルを入力してください')
  type = select_option('PRの種類を選択してください (draftまたはready)', %w[draft ready])

  # PRタイトル生成
  pr_title = "#{task_id.empty? ? '' : "[#{task_id}] "}#{LABEL_EMOJI[label]} #{title}"

  # 確認メッセージ
  puts 'PR情報を確認してください:'
  puts "Baseブランチ: #{base}"
  puts "Headブランチ: #{head}"
  puts "タイトル: #{pr_title}"
  puts "ラベル: #{label}"
  puts "種類: #{type}"
  puts 'この内容で作成しますか? (y/n)'
  confirmation = $stdin.getch
  exit unless confirmation.downcase == 'y'

  # PRテンプレート読み込み
  template_path = '../.github/pull_request_template.md'
  template = File.exist?(template_path) ? File.read(template_path) : ''

  # PR作成
  pr = client.create_pull_request(
    "#{OWNER}/#{REPO}",
    base,
    head,
    pr_title,
    template
  )

  # PRをDraft状態に更新
  client.update_pull_request("#{OWNER}/#{REPO}", pr[:number], draft: true) if type == 'draft'

  # ラベルを追加
  client.add_labels_to_an_issue("#{OWNER}/#{REPO}", pr[:number], [label])

  # 自分をアサイン
  client.add_assignees("#{OWNER}/#{REPO}", pr[:number], [client.user[:login]])

  puts "PRが作成されました: #{pr[:html_url]}"
rescue Octokit::Error => e
  puts "PR作成中にエラーが発生しました: #{e.message}"
  puts "エラー詳細: #{e.errors.inspect}" if e.respond_to?(:errors)
rescue => e
  puts "予期しないエラーが発生しました: #{e.message}"
end
