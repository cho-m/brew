# typed: true
# frozen_string_literal: true

module Homebrew
  module Livecheck
    module Strategy
      # The {GithubApi} strategy fetches content at a GitHub API URL, parses
      # it as JSON, and provides the parsed data to a `strategy` block. It
      # behaves like the {Json} strategy but performs credential handling to
      # authenticate to the GitHub API.
      #
      # {GitHubAPI} should only be used when the strategy is necessary or
      # appropriate (e.g. the formula/cask is throttled and the GitHub
      # repository has too many tags that the {Git}, {GithubLatest}, and
      # {GithubReleases} strategies aren't sufficient or ideal to identify
      # the newest throttled version).
      #
      # This strategy is not applied automatically and it is necessary to use
      # `strategy :github_api` in a `livecheck` block (in conjunction with a
      # `strategy` block) to use it.
      #
      # @api public
      class GithubApi
        NICE_NAME = "GitHub API"

        # A priority of zero causes livecheck to skip the strategy. We do this
        # for {GithubApi} so we can selectively apply it only when a strategy
        # block is provided in a `livecheck` block.
        PRIORITY = 0

        # The `Regexp` used to determine if the strategy applies to the URL.
        URL_MATCH_REGEX = %r{^#{Regexp.escape(GitHub::API_URL)}/}i

        # Whether the strategy can be applied to the provided URL.
        #
        # @param url the URL to match against
        sig { params(url: String).returns(T::Boolean) }
        def self.match?(url)
          URL_MATCH_REGEX.match?(url)
        end

        # Identifies versions from JSON response using a `strategy` block.
        # If a regex is provided, it will be passed as the second argument to
        # the `strategy` block.
        #
        # @param content the parsed JSON to check
        # @param regex a regex used for matching versions in the content
        # @param block a block to match the content
        sig {
          params(
            content: T.untyped,
            regex:   T.nilable(Regexp),
            block:   T.nilable(Proc),
          ).returns(T::Array[String])
        }
        def self.versions_from_content(content, regex = nil, &block)
          return [] if content.blank? || block.blank?

          block_return_value = if regex.present?
            yield(content, regex)
          elsif block.arity == 2
            raise "Two arguments found in `strategy` block but no regex provided."
          else
            yield(content)
          end
          Strategy.handle_block_return(block_return_value)
        end

        # Checks the JSON response at the GitHub API URL for versions, using
        # the provided `strategy` block to extract version information.
        #
        # @param url the URL of the content to check
        # @param regex a regex used for matching versions
        sig {
          params(
            url:     String,
            regex:   T.nilable(Regexp),
            _unused: T.untyped,
            block:   T.nilable(Proc),
          ).returns(T::Hash[Symbol, T.untyped])
        }
        def self.find_versions(url:, regex: nil, **_unused, &block)
          raise ArgumentError, "#{Utils.demodulize(T.must(name))} requires a `strategy` block" if block.blank?

          match_data = { matches: {}, regex:, url: }
          return match_data if url.blank?

          content = GitHub::API.open_rest(url)
          versions_from_content(content, regex, &block).each do |match_text|
            match_data[:matches][match_text] = Version.new(match_text)
          end

          match_data
        end
      end
    end
  end
end
