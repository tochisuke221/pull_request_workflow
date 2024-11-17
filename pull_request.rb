require 'octokit'
require 'dotenv/load'
require 'io/console'

# 定数
OWNER = 'tochisuke221'.freeze
REPO = 'pull_request_workflow'.freeze

# ラベルに対応する絵文字
LABEL_EMOJI = {
  '新機能' => '🎉',
  '改善' => '✨',
  'バグ修正' => '🐛',
  '内部変更' => '🧹',
  'その他' => '🔧'
}.freeze

# GitHubクライアントの初期化
client = Octokit::Client.new(access_token: '')

# ユーザー入力ヘルパー
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

# 入力情報収集
head = prompt('PRのheadブランチを入力してください')
base = prompt('PRのbaseブランチを入力してください')
task_id = prompt('NotionのタスクIDを入力してください (省略可能)')
label = select_option('ラベルを選択してください', LABEL_EMOJI.keys)
title = prompt('PRのタイトルを入力してください')
type = select_option('PRの種類を選択してください (draftまたはready)', %w[draft ready])

# PRタイトルの生成
pr_title = "#{task_id.empty? ? '' : "[#{task_id}] "}#{LABEL_EMOJI[label]} #{title}"

# ユーザー確認
puts 'PR情報を確認してください:'
puts "Baseブランチ: #{base}"
puts "Headブランチ: #{head}"
puts "タイトル: #{pr_title}"
puts "ラベル: #{label}"
puts "種類: #{type}"
puts 'この内容で作成しますか? (y/n)'
confirmation = $stdin.getch
exit unless confirmation.downcase == 'y'

# プルリクエストの作成!
begin
  # template = File.read('../.github/pull_request_template.md')
  pr = client.create_pull_request(
    "#{OWNER}/#{REPO}",
    base,
    head,
    pr_title,
    # template,
    # draft: type == 'draft'
  )

  # ラベルの追加
  client.add_labels_to_an_issue("#{OWNER}/#{REPO}", pr[:number], [label])

  # 自分をアサイン
  client.add_assignees("#{OWNER}/#{REPO}", pr[:number], [client.user[:login]])

  puts "PRが作成されました: #{pr[:html_url]}"
rescue Octokit::Error => e
  puts "PR作成中にエラーが発生しました: #{e.message}"
end
