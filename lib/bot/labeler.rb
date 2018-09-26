require 'octokit'
require 'active_support/all'

module Bot
  class Labeler

    def initialize(repo)
      @repo = repo
      @flag_prs_by_these_authors = [
        "gengjiawen",
        "anp",
        "ide",
        "shergin",
        "brentvatne",
        "charpeni",
        "dlowder-salesforce",
        "grabbou",
        "kelset",
	"empyrical",
	"lelandrichardson",
        "skevy",
        "rozele",
        "satya164",
        "janicduplessis",
        "matthargett",
        "hramos",
        "dryganets",
        "psivaram",
        "rigdern"
      ]
      @label_core_team = "Core Team"
      @label_android = ":large_blue_diamond:Android"
      @label_ios = ":large_blue_diamond:iOS"
      @label_tvos = ":large_blue_diamond:tvOS"

      @label_components = ":large_orange_diamond:Components"
      @label_textinput = ":large_orange_diamond:TextInput"
      @label_webview = ":large_orange_diamond:WebView"

      @label_lists = ":large_orange_diamond:Lists"

      @label_apis = ":large_orange_diamond:APIs"
      @label_animated = ":large_orange_diamond:Animated"
      @label_asyncstorage = ":large_orange_diamond:AsyncStorage"
      @label_panresponder = ":large_orange_diamond:PanResponder"
      @label_networking = ":globe_with_meridians:Networking"

      @label_bundler = "📦Bundler"
      @label_cli = ":computer:CLI"
      @label_regression = ":warning:Regression"
      @label_ci_test_failure = ":x:CI Test Failure"

      @components = [
        "activityindicator",
        "button",
        "datepickerios",
        "drawerlayoutandroid",
        "flatlist",
        "image",
        "inputaccessoryview",
        "keyboardavoidingview",
        "listview",
        "maskedviewios",
        "modal",
        "navigatorios",
        "picker",
        "pickerios",
        "progressbarandroid",
        "progressviewios",
        "refreshcontrol",
        "safeareaview",
        "scrollview",
        "sectionlist",
        "segmentedcontrolios",
        "slider",
        "snapshotviewios",
        "statusbar",
        "switch",
        "tabbarios",
        "text",
        "textinput",
        "toolbarandroid",
        "touchablehighlight",
        "touchablenativefeedback",
        "touchableopacity",
        "touchablewithoutfeedback",
        "view",
        "viewpagerandroid",
        "virtualizedlist",
        "webview"
      ]

      @apis = [
        "accessibilityinfo",
        "actionsheetios",
        "alert",
        "alertios",
        "animated",
        "appregistry",
        "appstate",
        "asyncstorage",
        "backandroid",
        "backhandler",
        "cameraroll",
        "clipboard",
        "datepickerandroid",
        "dimensions",
        "easing",
        "geolocation",
        "imageeditor",
        "imagepickerios",
        "imagestore",
        "interactionmanager",
        "keyboard",
        "layoutanimation",
        "linking",
        "listviewdatasource",
        "netinfo",
        "panresponder",
        "permissionsandroid",
        "pixelratio",
        "pushnotificationios",
        "settings",
        "share",
        "statusbarios",
        "stylesheet",
        "systrace",
        "timepickerandroid",
        "toastandroid",
        "transforms",
        "vibration",
        "vibrationios"
      ]
    end

    def perform
      candidates.each do |candidate|
        issues = Octokit.search_issues(candidate[:search])
        puts "#{@repo}: [LABELER] Found #{issues.items.count} recently created issues for candidate #{candidate[:action]}..."
        issues.items.each do |issue|
          puts "#{@repo}: [LABELER] Processing #{issue.html_url}: #{issue.title}"
          label_based_on_title(issue)
          label_based_on_envinfo(issue)
          label_based_on_author(issue)
        end
      end
    end

    def candidates
      [
        {
          :search => "repo:#{@repo} is:open created:>=#{1.day.ago.to_date.to_s}",
          :action => "label"
        }
      ]
    end

    def label_based_on_author(issue)
      labels = []
      labels.push @label_core_team if @flag_prs_by_these_authors.include? issue.user.login

      add_labels(issue, labels)
    end

    def label_based_on_title(issue)
      issue_title = issue.title.downcase

      labels = []

      labels.push @label_android if issue_title =~ /android/
      labels.push @label_ios if issue_title =~ /ios/
      labels.push @label_tvos if issue_title =~ /tvos/

      labels.push @label_cli if issue_title =~ /react-native-cli/
      labels.push @label_cli if issue_title =~ /react-native upgrade/
      labels.push @label_cli if issue_title =~ /react-native link/
      labels.push @label_cli if issue_title =~ /local-cli/

      labels.push @label_regression if issue_title =~ /regression/
      labels.push @label_ci_test_failure if issue_title =~ /\[CI\] Test failure - ([D][0-9]{5,})/

      @components.each do |component|
        labels.push @label_components if issue_title =~ /#{component.downcase}/
      end
      labels.push @label_lists if issue_title =~ /sectionlist/
      labels.push @label_lists if issue_title =~ /flatlist/
      labels.push @label_lists if issue_title =~ /virtualizedlist/
      labels.push @label_textinput if issue_title =~ /textinput/
      labels.push @label_webview if issue_title =~ /webview/

      @apis.each do |api|
        labels.push @label_apis if issue_title =~ /#{api.downcase}/
      end
      labels.push @label_animated if issue_title =~ /animated/
      labels.push @label_asyncstorage if issue_title =~ /asyncstorage/
      labels.push @label_panresponder if issue_title =~ /panresponder/

      labels.push @label_networking if issue_title =~ /xhr/
      labels.push @label_networking if issue_title =~ /netinfo/
      labels.push @label_networking if issue_title =~ /fetch/
      labels.push @label_networking if issue_title =~ /okhttp/
      labels.push @label_networking if issue_title =~ /http/

      labels.push @label_bundler if issue_title =~ /bundle/
      labels.push @label_bundler if issue_title =~ /bundling/
      labels.push @label_bundler if issue_title =~ /packager/
      labels.push @label_bundler if issue_title =~ /unable to resolve module/

      add_labels(issue, labels)
    end

    def label_based_on_envinfo(issue)
      issue_body = strip_comments issue.body
      regex = /OS:\s?(?<OS>macOS|Windows|Linux)/

      envinfo = regex.match(issue_body)

      new_labels = []

      if envinfo
        case envinfo["OS"]
          # when "Windows"
          #   puts "Skipping Windows"
          #   # label = ":small_blue_diamond:Windows"
          #   # new_labels.push label
          when "Linux"
            label = ":small_blue_diamond:Linux"
            new_labels.push label
          # when "macOS"
          #   puts "Skipping macOS"
          #   # label = ":small_blue_diamond:macOS"
          #   # new_labels.push label
        end
      end

      add_labels(issue, new_labels)
    end

    def strip_comments(text)
      return "" unless text
      regex = /(?=<!--)([\s\S]*?-->)/m
      text.gsub(regex, "")
    end

    def add_labels(issue, labels)
      new_labels = []

      labels.uniq.each do |label|
        if label
          new_labels.push label unless issue_contains_label(issue, label)
        end
      end

      if new_labels.count > 0
        puts "#{@repo}: [LABELS] 📍 #{issue.html_url} --> Adding #{new_labels}"
        Octokit.add_labels_to_an_issue(@repo, issue.number, new_labels)
      end
    end

    def issue_contains_label(issue, label)
      existing_labels = []

      issue.labels.each do |issue_label|
        existing_labels.push issue_label.name if issue_label.name
      end

      existing_labels.include? label
    end
  end
end
