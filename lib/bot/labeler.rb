require 'octokit'
require 'active_support/all'

module Bot
  class Labeler

    def initialize(repo)
      @repo = repo

      @label_needs_environment_info = "Needs: Environment Info"
      @label_type_bug_report = "Type: Bug Report"
      @label_type_bug_fix = "Type: Bug Fix🐛"
      @label_bug = "Bug"
      @label_needs_triage = "Needs: Triage :mag:"
      @label_impact_bug = "Impact: Bug"
      @label_android = "Platform: Android"
      @label_ios = "Platform: iOS"
      @label_tvos = "Platform: tvOS"

      @label_networking = "🌐Networking"

      @label_bundler = "📦Bundler"
      @label_cli = "💻CLI"
      @label_regression = "Impact: Regression"
      @label_ci_test_failure = "❌CI Test Failure"
      @label_discussion = "Type: Discussion"

      @components = [
        "ActivityIndicator",
        "Button",
        "DatePickerIOS",
        "DrawerLayoutAndroid",
        "FlatList",
        "Image",
        "ImageBackground",
        "InputAccessoryView",
        "KeyboardAvoidingView",
        "ListView",
        "MaskedViewIOS",
        "Modal",
        "NavigatorIOS",
        "Picker",
        "PickerIOS",
        "ProgressBarAndroid",
        "ProgressViewIOS",
        "RefreshControl",
        "SafeAreaView",
        "ScrollView",
        "SectionList",
        "SegmentedControlIOS",
        "Slider",
        "SnapshotViewIOS",
        "StatusBar",
        "Switch",
        "TabBarIOS",
        "TextInput",
        "ToolbarAndroid",
        "TouchableHighlight",
        "TouchableNativeFeedback",
        "TouchableOpacity",
        "TouchableWithoutFeedback",
        "ViewPagerAndroid",
        "VirtualizedList",
        "WebView"
      ]

      @apis = [
        "AccessibilityInfo",
        "ActionSheetIOS",
        "Alert",
        "AlertIOS",
        "Animated",
        "AppRegistry",
        "AppState",
        "AsyncStorage",
        "BackAndroid",
        "BackHandler",
        "CameraRoll",
        "Clipboard",
        "DatePickerAndroid",
        "Dimensions",
        "Easing",
        "Geolocation",
        "ImageEditor",
        "ImagePickerIOS",
        "ImageStore",
        "InteractionManager",
        "Keyboard",
        "LayoutAnimation",
        "Linking",
        "ListViewDataSource",
        "NetInfo",
        "PanResponder",
        "PermissionsAndroid",
        "PixelRatio",
        "PushNotificationIOS",
        "Settings",
        "Share",
        "StatusBarIOS",
        "StyleSheet",
        "Systrace",
        "TimePickerAndroid",
        "ToastAndroid",
        "Transforms",
        "Vibration",
        "VibrationIOS"
      ]

      @topics = {
        "Flow": "Flow",
        "Flow-Strict": "Flow",
        "xhr": @label_networking,
        "netinfo": @label_networking,
        "fetch": @label_networking,
        "okhttp": @label_networking,
        "http": @label_networking,
        "bundle": @label_bundler,
        "bundling": @label_bundler,
        "packager": @label_bundler,
        "unable to resolve module": @label_bundler,
        "android": @label_android,
        "ios": @label_ios,
        "tvos": @label_tvos,
        "react-native-cli": @label_cli,
        "react-native upgrade": @label_cli,
        "react-native link": @label_cli,
        "local-cli": @label_cli,
        "regression": @label_regression
      }
    end

    def perform
      candidates.each do |candidate|
        issues = Octokit.search_issues(candidate[:search], { :per_page => 100 })
        issues.items.each do |issue|
          process(issue, candidate)
        end
      end
    end

    def candidates
      [
        {
          :search => "repo:#{@repo} label:\"#{@label_needs_triage}\" created:>=#{1.hour.ago.to_date.to_s}",
          :action => "label"
        }
      ]
    end

    def process(issue, candidate)
      if candidate[:action] == 'label'
        label_based_on_title(issue)
        label_based_on_envinfo(issue)
      end
      if candidate[:action] == 'backfill'
        backfill_labels(issue)
      end
    end

    def backfill_labels(issue)
      # add_labels!(issue, [@label_bug])
    end

    def label_based_on_title(issue)
      issue_title = issue.title.downcase

      labels = []


      labels.push @label_ci_test_failure if issue_title =~ /\[CI\] Test failure - ([D][0-9]{5,})/

      @components.each do |component|
        labels.push "Component: #{component}" if issue_title =~ /#{component.downcase}/
      end


      @apis.each do |api|
        labels.push "API: #{api}" if issue_title =~ /#{api.downcase}/
      end

      @topics.each do |topic, label|
        labels.push label if issue_title =~ /#{topic.downcase}/
      end

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
          #   # label = "Platform: Windows"
          #   # new_labels.push label
          when "Linux"
            label = "Platform: Linux"
            new_labels.push label
          # when "macOS"
          #   puts "Skipping macOS"
          #   # label = "Platform: macOS"
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
        unless ENV['READ_ONLY'].present?
          Octokit.add_labels_to_an_issue(@repo, issue.number, new_labels)
        end
        puts "#{@repo}: [LABELS] 📍 #{issue.html_url} --> Adding #{new_labels}"
      end
    end

    def add_labels!(issue, new_labels)
      unless ENV['READ_ONLY'].present?
        Octokit.add_labels_to_an_issue(@repo, issue.number, new_labels)
      end
      puts "#{@repo}: [LABELS] 📍 #{issue.html_url} --> Adding #{new_labels}"
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
