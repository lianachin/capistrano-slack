require 'capistrano'
require 'capistrano/log_with_awesome'
require 'json'
require 'net/http'
require 'active_support/all'

module Capistrano
  module Slack
    HEX_COLORS = {
          :yellow  => '#FFCC00',
          :red   => '#BB0000',
          :green => '#009933',
        }

    def post_to_channel(color, message)
      if use_color?
        slack_connect(attachment_payload(color, message))
      else
        slack_connect(regular_payload(message))
      end
    end

    def slack_webhook_url
      fetch(:slack_webhook_url)
    end

    def slack_connect(payload)
      begin
        uri = URI.parse(slack_webhook_url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        request = Net::HTTP::Post.new(uri.request_uri)
        request.set_form_data(:payload => payload)
        http.request(request)
      rescue SocketError => e
         puts "#{e.message} or slack may be down"
      end
    end

    def regular_payload(announcement)
      {
        'channel' => fetch(:slack_room),
        'username' => fetch(:slack_username, ''),
        'text' => announcement,
        'icon_emoji' => fetch(:slack_emoji, ''),
        'parse' => fetch(:slack_parse, ''),
        'mrkdwn'     => true
      }.to_json
    end

    def attachment_payload(color, announcement)
      {
        'channel' => fetch(:slack_room),
        'username' => fetch(:slack_username, ''),
        'icon_emoji' => fetch(:slack_emoji, ''),
        'parse' => fetch(:slack_parse, ''),
        'attachments' => [{
          'fallback'  => announcement,
          'text'      => announcement,
          'color'     => HEX_COLORS[color],
          'mrkdwn_in' => %w{text}
        }]
      }.to_json
    end

    def use_color?
      fetch(:slack_color, true)
    end

    def slack_defaults
      if fetch(:slack_deploy_defaults, true) == true
        before 'deploy', 'slack:starting'
        before 'deploy:migrations', 'slack:starting'
        after 'deploy', 'slack:finished'
        after 'deploy:migrations', 'slack:finished'
      end
    end

    def github_revision_id
      name = "#{real_revision}"
      name
    end

    def github_commit_link
      "<https://github.com/RUNDSP/run_portal/commit/#{github_revision_id}|#{github_revision_id[0..7]}>"
    end

    def self.extended(configuration)
      configuration.load do

        set :deployer do
          ENV['GIT_AUTHOR_NAME'] || `git config user.name`.chomp
        end

        namespace :slack do
          task :starting do
            post_to_channel(:yellow, "#{fetch(:deployer)} is deploying #{fetch(:application)}/revision #{github_commit_link} to #{fetch(:stage, 'production')}")
          end

          task :finished do
            post_to_channel(:green, "#{fetch(:deployer)} finished deploying #{fetch(:application)}/revision #{github_commit_link} to #{fetch(:stage)}")
          end

          task :failed do
            post_to_channel(:red, "FAILED: #{fetch(:deployer)}'s deployment of #{fetch(:application)}/revision #{github_commit_link} to #{fetch(:stage)} failed")
          end

          task :cancelled do
            post_to_channel(:red, "#{fetch(:deployer)} cancelled deployment of #{fetch(:application)}/revision #{github_commit_link} to #{fetch(:stage)}")
          end
        end
      end
    end
  end
end

if Capistrano::Configuration.instance
  Capistrano::Configuration.instance.extend(Capistrano::Slack)
end
