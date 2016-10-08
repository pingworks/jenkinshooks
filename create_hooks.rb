#!/usr/bin/env ruby

require "rubygems"
require "yaml"
require "net/http"
require "uri"
require "erubis"
require "logger"
require "fileutils"

conf_debug = ENV['HOOKS_DEBUG'] || 0
conf_log = ENV['HOOKS_LOG'] || "./jenkinshooks.log"
conf_hooks_config = ENV['HOOKS_CONFIG_URL'] || './hooks_config.yml'
conf_hooks_tpl = ENV['HOOKS_TPL_URL'] || "./post-receive.erb"
conf_gitlab_repo_base = ENV['HOOKS_GITLAB_REPOS_PATH'] || "/tmp"

logger = Logger.new(conf_log)

logger.level = Logger::WARN
logger.level = Logger::DEBUG unless conf_debug == 0

logger.debug("------ create_hooks.rb started ------")
logger.debug("conf_debug: #{conf_debug}")
logger.debug("conf_hooks_config: #{conf_hooks_config}")
logger.debug("conf_hooks_tpl: #{conf_hooks_tpl}")
logger.debug("conf_gitlab_repo_base: #{conf_gitlab_repo_base}")

# -------------------- download config & template --------------------
config_and_template = {}
{ config: conf_hooks_config, template: conf_hooks_tpl }.each do |k, u|
  if u =~ /^http/
    logger.debug("downloading #{k} from #{u}...")
    uri = URI.parse(u)

    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)

    if response.code == "200"
      logger.debug("download successful.")
      config_and_template[k] = response.body
      logger.debug("#{k} is now #{config_and_template[k]}")
    else
      logger.error("#{k}: Could not download #{u}!")
      puts "ERROR: Could not download #{u}!"
      exit 1
    end
  else
    logger.debug("reading #{k} from file #{u}...")
    config_and_template[k] = File.read(u)
    logger.debug("reading from file successful.")
    logger.debug("#{k} is now #{config_and_template[k]}")
  end
end

# -------------------- delete hooks that are not longer configured ------------------
hooks_config = YAML.load(config_and_template[:config])

begin
  Dir.foreach(conf_gitlab_repo_base) do |rdir|
    next if rdir == '.' || rdir == '..'
    Dir.glob("#{conf_gitlab_repo_base}/#{rdir}/*.git") do |r|
      logger.debug("checking for superfluous hooks in #{conf_gitlab_repo_base}/#{rdir}/#{r}")
      if File.exist("#{conf_gitlab_repo_base}/#{rdir}/#{r}/custom_hooks/post-receive")
        logger.debug("hook found in #{conf_gitlab_repo_base}/#{rdir}/#{r}/custom_hooks/post-receive")
        hook_is_configured = false
        hooks_config['hooks'].each do |hook|
          if "#{conf_gitlab_repo_base}/#{hook['repo']}.git" == "#{conf_gitlab_repo_base}/#{rdir}/#{r}"
            logger.debug("hook OK - is still in config")
            hook_is_configured = true
          end
        end
        if hook_is_configured == false
          logger.debug("hook is not longer in config - DELETING it...")
          FileUtils.rm("#{conf_gitlab_repo_base}/#{hook['repo']}.git/custom_hooks/post-receive")
        end
      end
    end
  end
rescue => err
  logger.fatal("Caught exception - exiting.")
  logger.fatal(err)
end

# -------------------- write hooks --------------------
begin
  hooks_config = YAML.load(config_and_template[:config])
  hooks_config['hooks'].each do |hook|
    next unless File.directory?("#{conf_gitlab_repo_base}/#{hook['repo']}.git")
    logger.debug("#{hook['repo']} found at #{conf_gitlab_repo_base}/#{hook['repo']}.git")

    unless File.exist?("#{conf_gitlab_repo_base}/#{hook['repo']}.git/custom_hooks")
      Dir.mkdir("#{conf_gitlab_repo_base}/#{hook['repo']}.git/custom_hooks")
      FileUtils.chmod 0755, "#{conf_gitlab_repo_base}/#{hook['repo']}.git/custom_hooks"
      FileUtils.chown "git", "git", "#{conf_gitlab_repo_base}/#{hook['repo']}.git/custom_hooks"
    end

    logger.info("writing new post-recieve hook into #{conf_gitlab_repo_base}/#{hook['repo']}.git/custom_hooks/post-receive")
    File.write("#{conf_gitlab_repo_base}/#{hook['repo']}.git/custom_hooks/post-receive",
               Erubis::Eruby.new(config_and_template[:template]).result(hook: hook, defaults: hooks_config['defaults']))
    FileUtils.chmod 0755, "#{conf_gitlab_repo_base}/#{hook['repo']}.git/custom_hooks/post-receive"
    FileUtils.chown "git", "git", "#{conf_gitlab_repo_base}/#{hook['repo']}.git/custom_hooks/post-receive"
  end
rescue => err
  logger.fatal("Caught exception - exiting.")
  logger.fatal(err)
end
